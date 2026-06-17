#!/bin/bash

DATA_DIR="/home/user/snmp_data"
REPORT_DIR="/home/user/snmp_reports"
mkdir -p "$REPORT_DIR"

YESTERDAY=$(date -d "yesterday" +%Y%m%d)
DAILY_FILE="$DATA_DIR/daily_$YESTERDAY.txt"
MONTHLY_FILE="$REPORT_DIR/traffic_$(date +%Y%m).csv"

if [ -f "$DAILY_FILE" ]; then
    read -r sum_wan_@ sum_l2tp_@ sum_clean_@ sum_wan_@@ sum_l2tp_@@ sum_clean_@@ < "$DAILY_FILE"
    
    wan_@_gb=$(echo "scale=3; $sum_wan_@ / 1073741824" | bc)
    l2tp_@_gb=$(echo "scale=3; $sum_l2tp_@ / 1073741824" | bc)
    clean_@_gb=$(echo "scale=3; $sum_clean_@ / 1073741824" | bc)
    wan_@@_gb=$(echo "scale=3; $sum_wan_@@ / 1073741824" | bc)
    l2tp_@@_gb=$(echo "scale=3; $sum_l2tp_@@ / 1073741824" | bc)
    clean_@@_gb=$(echo "scale=3; $sum_clean_@@ / 1073741824" | bc)
    
    if [ ! -f "$MONTHLY_FILE" ]; then
        echo "date;wan_@_gb;l2tp_@_gb;clean_@_gb;wan_@@_gb;l2tp_@@_gb;clean_@@_gb" > "$MONTHLY_FILE"
    fi
    
    echo "$YESTERDAY;$wan_@_gb;$l2tp_@_gb;$clean_@_gb;$wan_@@_gb;$l2tp_@@_gb;$clean_@@_gb" >> "$MONTHLY_FILE"
    
    rm -f "$DAILY_FILE"
fi