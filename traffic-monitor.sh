#!/usr/bin/env bash
#
# traffic-monitor.sh
# Shows how much traffic (download + upload) has been used since first run
# Put it in /usr/local/bin/ or ~/bin/ and make it executable:
#   chmod +x traffic-monitor.sh
#

# ================= CONFIG =================
INTERFACE="eth0"          # ← CHANGE THIS to your real interface
                          # Common names: eth0, enp3s0, ens3, enp1s0, etc.
                          # Find yours with: ip link show or ifconfig -a

STATE_FILE="/var/tmp/traffic-monitor-start-${INTERFACE}.state"
# You can also use ~/.traffic-monitor.state if you don't have /var/tmp

# ================= FUNCTIONS =================

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
    local mode=$1
    if [[ -r "/sys/class/net/$INTERFACE/statistics/${mode}_bytes" ]]; then
        cat "/sys/class/net/$INTERFACE/statistics/${mode}_bytes"
    else
        # fallback using /proc/net/dev
        awk -v iface="$INTERFACE:" '
            $1 == iface { if ("'$mode'" == "rx") print $2; else print $10 }
        ' /proc/net/dev
    fi
}

# ================= MAIN =================

if [[ ! -d "/sys/class/net/$INTERFACE" ]]; then
    echo "Error: Interface '$INTERFACE' not found."
    echo "Available interfaces:"
    ip link show | grep -E '^[0-9]+:' | awk '{print "  " $2}' | sed 's/:$//'
    exit 1
fi

rx_now=$(get_bytes rx)
tx_now=$(get_bytes tx)

total_now=$(( rx_now + tx_now ))

if [[ ! -f "$STATE_FILE" ]]; then
    echo "First run → saving baseline..."
    echo "$rx_now"  > "$STATE_FILE"
    echo "$tx_now" >> "$STATE_FILE"
    echo "$total_now" >> "$STATE_FILE"
    echo "Baseline saved. Run the script again later to see usage."
    exit 0
fi

read rx_start tx_start total_start < "$STATE_FILE"

rx_used=$(( rx_now - rx_start ))
tx_used=$(( tx_now - tx_start ))
total_used=$(( total_now - total_start ))

cat << EOF
Traffic usage since first run ($(date -r "$STATE_FILE" '+%Y-%m-%d %H:%M:%S')):

Interface ......: $INTERFACE
Downloaded .....: $(human $rx_used)    ($rx_used bytes)
Uploaded .......: $(human $tx_used)    ($tx_used bytes)
Total traffic ..: $(human $total_used)    ($total_used bytes)

Current total (since boot):
  RX: $(human $rx_now)
  TX: $(human $tx_now)
  ∑ : $(human $total_now)

EOF

# Optional: show remaining until 500 GB
LIMIT=$((500 * 1073741824))           # 500 GiB
remaining=$(( LIMIT - total_used ))

if (( remaining > 0 )); then
    echo "Remaining until 500 GiB limit: $(human $remaining)"
    echo "You have used $(bc <<< "scale=1; $total_used * 100 / $LIMIT")% of your limit"
else
    echo "→ You have EXCEEDED the 500 GiB limit by $(human $((-remaining))) !"
fi
