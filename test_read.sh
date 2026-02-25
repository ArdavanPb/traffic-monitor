#!/bin/bash
STATE_FILE="/home/ap/.traffic-monitor/state/traffic-enp3s0.state"
echo "State file contents:"
cat "$STATE_FILE"
echo ""
echo "Reading with read command:"
read rx_start tx_start total_start timestamp < "$STATE_FILE"
echo "rx_start: $rx_start"
echo "tx_start: $tx_start"
echo "total_start: $total_start"
echo "timestamp: $timestamp"
echo ""
echo "Testing date command:"
date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S'
