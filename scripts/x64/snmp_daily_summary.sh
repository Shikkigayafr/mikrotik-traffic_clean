#!/bin/bash

DATA_DIR="/home/ecm_admin/snmp_data"
REPORT_DIR="/home/ecm_admin/snmp_reports"
mkdir -p "$REPORT_DIR"

YESTERDAY=$(date -d "yesterday" +%Y%m%d)
DAILY_FILE="$DATA_DIR/daily_$YESTERDAY.txt"
MONTHLY_FILE="$REPORT_DIR/traffic_$(date +%Y%m).csv"

if [ -f "$DAILY_FILE" ]; then
    read -r sum_wan_ecm sum_l2tp_ecm sum_clean_ecm sum_wan_sm sum_l2tp_sm sum_clean_sm < "$DAILY_FILE"
    
    # Переводим байты в ГБ (1 ГБ = 1073741824 байт)
    wan_ecm_gb=$(echo "scale=3; $sum_wan_ecm / 1073741824" | bc)
    l2tp_ecm_gb=$(echo "scale=3; $sum_l2tp_ecm / 1073741824" | bc)
    clean_ecm_gb=$(echo "scale=3; $sum_clean_ecm / 1073741824" | bc)
    wan_sm_gb=$(echo "scale=3; $sum_wan_sm / 1073741824" | bc)
    l2tp_sm_gb=$(echo "scale=3; $sum_l2tp_sm / 1073741824" | bc)
    clean_sm_gb=$(echo "scale=3; $sum_clean_sm / 1073741824" | bc)
    
    # Если файла нет — создаём с заголовком
    if [ ! -f "$MONTHLY_FILE" ]; then
        echo "date;wan_ecm_gb;l2tp_ecm_gb;clean_ecm_gb;wan_sm_gb;l2tp_sm_gb;clean_sm_gb" > "$MONTHLY_FILE"
    fi
    
    echo "$YESTERDAY;$wan_ecm_gb;$l2tp_ecm_gb;$clean_ecm_gb;$wan_sm_gb;$l2tp_sm_gb;$clean_sm_gb" >> "$MONTHLY_FILE"
    
    # Удаляем обработанный дневной файл
    rm -f "$DAILY_FILE"
fi
