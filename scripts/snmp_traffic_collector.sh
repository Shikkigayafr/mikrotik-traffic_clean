#!/bin/bash

# ============================================================
# 1. НАСТРОЙКИ (пути к папкам и файлам)
# ============================================================

STATE_DIR="/home/user/snmp_state"
DATA_DIR="/home/user/snmp_data"
LOG_FILE="/home/user/snmp_collector.log"

mkdir -p "$STATE_DIR" "$DATA_DIR"

# ============================================================
# 2. ФУНКЦИИ
# ============================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

get_snmp() {
    snmpget -v2c -c public -Oqv "$1" "$2" 2>/dev/null
}

# ============================================================
# 3. АВТООПРЕДЕЛЕНИЕ ИНДЕКСОВ L2TP-ТУННЕЛЕЙ
# ============================================================

get_tunnel_oid() {
    snmpwalk -v2c -c public "$1" 1.3.6.1.2.1.2.2.1.2 2>/dev/null | \
        grep -i "$2" | head -1 | sed 's/.*\.\([0-9]\+\) = .*/\1/'
}

L2TP_@_OID=$(get_tunnel_oid "IP_ADDRESS_@" "L2TP_@_NAME")
L2TP_@@_OID=$(get_tunnel_oid "IP_ADDRESS_@@" "L2TP_@@_NAME")

if [ -z "$L2TP_@_OID" ] || [ -z "$L2TP_@@_OID" ]; then
    log "ОШИБКА: не удалось определить индексы туннелей"
    exit 1
fi

# ============================================================
# 4. СБОР ДАННЫХ (входящий трафик)
# ============================================================

WAN_@=$(get_snmp "IP_ADDRESS_@" "1.3.6.1.2.1.2.2.1.10.9")
L2TP_@=$(get_snmp "IP_ADDRESS_@" "1.3.6.1.2.1.2.2.1.10.$L2TP_@_OID")
WAN_@@=$(get_snmp "IP_ADDRESS_@@" "1.3.6.1.2.1.2.2.1.10.1")
L2TP_@@=$(get_snmp "IP_ADDRESS_@@" "1.3.6.1.2.1.2.2.1.10.$L2TP_@@_OID")

# ============================================================
# 5. ОБРАБОТКА ДАННЫХ ДЛЯ @
# ============================================================

STATE_@_FILE="$STATE_DIR/@.state"

if [ -f "$STATE_@_FILE" ]; then
    source "$STATE_@_FILE"

    if [ -n "$WAN_@" ] && [ -n "$old_wan_@" ]; then
        if [ "$WAN_@" -ge "$old_wan_@" ]; then
            wan_diff_@=$((WAN_@ - old_wan_@))
        else
            wan_diff_@=$((4294967295 - old_wan_@ + WAN_@))
        fi
    else
        wan_diff_@=0
    fi

    if [ -n "$L2TP_@" ] && [ -n "$old_l2tp_@" ]; then
        if [ "$L2TP_@" -ge "$old_l2tp_@" ]; then
            l2tp_diff_@=$((L2TP_@ - old_l2tp_@))
        else
            l2tp_diff_@=$((4294967295 - old_l2tp_@ + L2TP_@))
        fi
    else
        l2tp_diff_@=0
    fi

    clean_@=$((wan_diff_@ - l2tp_diff_@))
else
    wan_diff_@=0
    l2tp_diff_@=0
    clean_@=0
fi

echo "old_wan_@=$WAN_@" > "$STATE_@_FILE"
echo "old_l2tp_@=$L2TP_@" >> "$STATE_@_FILE"

# ============================================================
# 6. ОБРАБОТКА ДАННЫХ ДЛЯ @@
# ============================================================

STATE_@@_FILE="$STATE_DIR/@@.state"

if [ -f "$STATE_@@_FILE" ]; then
    source "$STATE_@@_FILE"

    if [ -n "$WAN_@@" ] && [ -n "$old_wan_@@" ]; then
        if [ "$WAN_@@" -ge "$old_wan_@@" ]; then
            wan_diff_@@=$((WAN_@@ - old_wan_@@))
        else
            wan_diff_@@=$((4294967295 - old_wan_@@ + WAN_@@))
        fi
    else
        wan_diff_@@=0
    fi

    if [ -n "$L2TP_@@" ] && [ -n "$old_l2tp_@@" ]; then
        if [ "$L2TP_@@" -ge "$old_l2tp_@@" ]; then
            l2tp_diff_@@=$((L2TP_@@ - old_l2tp_@@))
        else
            l2tp_diff_@@=$((4294967295 - old_l2tp_@@ + L2TP_@@))
        fi
    else
        l2tp_diff_@@=0
    fi

    clean_@@=$((wan_diff_@@ - l2tp_diff_@@))
else
    wan_diff_@@=0
    l2tp_diff_@@=0
    clean_@@=0
fi

echo "old_wan_@@=$WAN_@@" > "$STATE_@@_FILE"
echo "old_l2tp_@@=$L2TP_@@" >> "$STATE_@@_FILE"

# ============================================================
# 7. НАКОПЛЕНИЕ ДНЕВНОЙ СУММЫ
# ============================================================

TODAY=$(date +%Y%m%d)
DAILY_FILE="$DATA_DIR/daily_$TODAY.txt"

if [ -f "$DAILY_FILE" ]; then
    read -r sum_wan_@ sum_l2tp_@ sum_clean_@ sum_wan_@@ sum_l2tp_@@ sum_clean_@@ < "$DAILY_FILE"
else
    sum_wan_@=0
    sum_l2tp_@=0
    sum_clean_@=0
    sum_wan_@@=0
    sum_l2tp_@@=0
    sum_clean_@@=0
fi

sum_wan_@=$((sum_wan_@ + wan_diff_@))
sum_l2tp_@=$((sum_l2tp_@ + l2tp_diff_@))
sum_clean_@=$((sum_clean_@ + clean_@))
sum_wan_@@=$((sum_wan_@@ + wan_diff_@@))
sum_l2tp_@@=$((sum_l2tp_@@ + l2tp_diff_@@))
sum_clean_@@=$((sum_clean_@@ + clean_@@))

echo "$sum_wan_@ $sum_l2tp_@ $sum_clean_@ $sum_wan_@@ $sum_l2tp_@@ $sum_clean_@@" > "$DAILY_FILE"

# ============================================================
# 8. ЛОГИРОВАНИЕ
# ============================================================

log "Собрано: @ чистый = $((clean_@ / 1024 / 1024)) МБ, @@ чистый = $((clean_@@ / 1024 / 1024)) МБ"

# ============================================================
# 9. ОТПРАВКА В ZABBIX (через zabbix_sender)
# ============================================================

if command -v zabbix_sender &> /dev/null; then

    if [ -n "$clean_@" ] && [ "$clean_@" -ne 0 ]; then
        CLEAN_@_BPS=$(echo "scale=0; ($clean_@ * 8) / 600" | bc)
        zabbix_sender -z 127.0.0.1 -s "Mikrotik-RB760iGS-@" -k "clean.traffic.@.in" -o "$CLEAN_@_BPS" 2>/dev/null
        log "Zabbix: @ = $CLEAN_@_BPS bps"
    else
        log "Zabbix: @ не отправлено (clean_@ = $clean_@)"
    fi

    if [ -n "$clean_@@" ] && [ "$clean_@@" -ne 0 ]; then
        CLEAN_@@_BPS=$(echo "scale=0; ($clean_@@ * 8) / 600" | bc)
        zabbix_sender -z 127.0.0.1 -s "Mikrotik-RB760iGS-@@" -k "clean.traffic.@@.in" -o "$CLEAN_@@_BPS" 2>/dev/null
        log "Zabbix: @@ = $CLEAN_@@_BPS bps"
    else
        log "Zabbix: @@ не отправлено (clean_@@ = $clean_@@)"
    fi
else
    log "ОШИБКА: zabbix_sender не найден"
fi