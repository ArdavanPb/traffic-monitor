#!/usr/bin/env bash
#
# traffic-monitor-v2.sh
# Enhanced version with automatic interface detection and web UI support
#

# ================= CONFIG =================
LOG_DIR="$HOME/.traffic-monitor/logs"
STATE_DIR="$HOME/.traffic-monitor/state"
WEB_PORT=8080
WEB_USER="admin"
WEB_PASS="admin123"  # Change this in production!

# ================= FUNCTIONS =================

detect_primary_interface() {
    # Try to detect the primary network interface (not loopback, not docker/bridge)
    local interfaces=()
    
    # Get all interfaces excluding loopback, docker, bridge, and virtual interfaces
    for iface in /sys/class/net/*; do
        local ifname=$(basename "$iface")
        
        # Skip loopback
        if [[ "$ifname" == "lo" ]]; then
            continue
        fi
        
        # Skip docker and bridge interfaces
        if [[ "$ifname" == docker* ]] || [[ "$ifname" == br-* ]] || [[ "$ifname" == br[0-9]* ]] || [[ "$ifname" == veth* ]] || [[ "$ifname" == virbr* ]]; then
            continue
        fi
        
        # Check if interface is up and has carrier
        if [[ -f "$iface/operstate" ]] && [[ $(cat "$iface/operstate") == "up" ]]; then
            interfaces+=("$ifname")
        fi
    done
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        # Fallback: any non-virtual interface
        for iface in /sys/class/net/*; do
            local ifname=$(basename "$iface")
            if [[ "$ifname" != "lo" ]] && [[ ! "$ifname" =~ ^(docker|br-|veth|virbr) ]]; then
                interfaces+=("$ifname")
            fi
        done
    fi
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        echo "eth0"  # Ultimate fallback
    else
        echo "${interfaces[0]}"
    fi
}

human() {
    local bytes=$1
    if (( bytes >= 1099511627776 )); then
        printf "%.2f TiB" "$(bc <<< "scale=2; $bytes / 1099511627776")"
    elif (( bytes >= 1073741824 )); then
        printf "%.2f GiB" "$(bc <<< "scale=2; $bytes / 1073741824")"
    elif (( bytes >= 1048576 )); then
        printf "%.2f MiB" "$(bc <<< "scale=2; $bytes / 1048576")"
    else
        printf "%'d KiB" $((bytes / 1024))
    fi
}

get_bytes() {
    local iface=$1
    local mode=$2
    if [[ -r "/sys/class/net/$iface/statistics/${mode}_bytes" ]]; then
        cat "/sys/class/net/$iface/statistics/${mode}_bytes"
    else
        # fallback using /proc/net/dev
        awk -v iface="$iface:" '
            $1 == iface { if ("'$mode'" == "rx") print $2; else print $10 }
        ' /proc/net/dev
    fi
}

get_all_interfaces_stats() {
    local stats=""
    for iface in /sys/class/net/*; do
        local ifname=$(basename "$iface")
        if [[ "$ifname" == "lo" ]]; then
            continue
        fi
        
        local rx_bytes=$(get_bytes "$ifname" "rx" 2>/dev/null || echo "0")
        local tx_bytes=$(get_bytes "$ifname" "tx" 2>/dev/null || echo "0")
        local total=$((rx_bytes + tx_bytes))
        
        stats+="$ifname:$rx_bytes:$tx_bytes:$total\n"
    done
    echo -e "$stats"
}

log_traffic() {
    local iface=$1
    local rx=$2
    local tx=$3
    local total=$4
    
    mkdir -p "$LOG_DIR"
    local log_file="$LOG_DIR/traffic-$(date +%Y-%m-%d).log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $iface RX:$(human $rx) TX:$(human $tx) TOTAL:$(human $total)" >> "$log_file"
}

# ================= MAIN LOGIC =================

# Auto-detect primary interface
INTERFACE=$(detect_primary_interface)
echo "Detected primary interface: $INTERFACE"

# Create necessary directories
mkdir -p "$STATE_DIR" "$LOG_DIR"

STATE_FILE="$STATE_DIR/traffic-$INTERFACE.state"

if [[ ! -d "/sys/class/net/$INTERFACE" ]]; then
    echo "Error: Interface '$INTERFACE' not found."
    echo "Available interfaces:"
    ip link show | grep -E '^[0-9]+:' | awk '{print "  " $2}' | sed 's/:$//'
    exit 1
fi

# Get current stats
rx_now=$(get_bytes "$INTERFACE" rx)
tx_now=$(get_bytes "$INTERFACE" tx)
total_now=$(( rx_now + tx_now ))

# Initialize or read state
if [[ ! -f "$STATE_FILE" ]]; then
    echo "First run → saving baseline for $INTERFACE..."
    echo "$rx_now"  > "$STATE_FILE"
    echo "$tx_now" >> "$STATE_FILE"
    echo "$total_now" >> "$STATE_FILE"
    echo "$(date +%s)" >> "$STATE_FILE"  # Timestamp
    echo "Baseline saved. Run the script again later to see usage."
    
    # Log initial state
    log_traffic "$INTERFACE" "$rx_now" "$tx_now" "$total_now"
    exit 0
fi

read rx_start tx_start total_start timestamp < "$STATE_FILE"

# Calculate usage
rx_used=$(( rx_now - rx_start ))
tx_used=$(( tx_now - tx_start ))
total_used=$(( total_now - total_start ))

# Calculate time elapsed
current_time=$(date +%s)
time_elapsed=$(( current_time - timestamp ))
hours=$(( time_elapsed / 3600 ))
minutes=$(( (time_elapsed % 3600) / 60 ))

# Log current traffic
log_traffic "$INTERFACE" "$rx_now" "$tx_now" "$total_now"

# Display results
cat << EOF
=============================================
TRAFFIC MONITOR v2.0
=============================================

Primary Interface: $INTERFACE
Monitoring since: $(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')
Time elapsed: ${hours}h ${minutes}m

--- USAGE SINCE FIRST RUN ---
Downloaded .....: $(human $rx_used)    ($rx_used bytes)
Uploaded .......: $(human $tx_used)    ($tx_used bytes)
Total traffic ..: $(human $total_used)    ($total_used bytes)

--- CURRENT STATS (since boot) ---
RX: $(human $rx_now)
TX: $(human $tx_now)
∑ : $(human $total_now)

--- RATES ---
Avg. download rate: $(human $((rx_used / (time_elapsed > 0 ? time_elapsed : 1))))/s
Avg. upload rate..: $(human $((tx_used / (time_elapsed > 0 ? time_elapsed : 1))))/s

EOF

# Check all interfaces
echo "=== ALL INTERFACES ==="
get_all_interfaces_stats | while IFS=: read -r iface rx tx total; do
    if [[ -n "$iface" ]]; then
        echo "$iface: RX:$(human $rx) TX:$(human $tx) TOTAL:$(human $total)"
    fi
done

echo ""
echo "Log file: $LOG_DIR/traffic-$(date +%Y-%m-%d).log"
echo "State file: $STATE_FILE"
echo "Web UI: http://localhost:$WEB_PORT (user: $WEB_USER)"
echo ""
echo "Run './start-web.sh' to launch the web interface"
echo "============================================="