#!/bin/bash
# Server Health Check with Telegram Alert
# Runs every 15 minutes via cron
# Alerts only on state changes (OK → WARNING → OK)

set -euo pipefail

STATE_FILE="/tmp/health-check-state.txt"
source /root/stock-monitoring/.env 2>/dev/null || true

# Telegram config from hermes .env
HERMES_ENV="/root/.hermes/.env"
if [ -f "$HERMES_ENV" ]; then
    BOT_TOKEN=$(grep -E '^TELEGRAM_BOT_TOKEN=' "$HERMES_ENV" | cut -d'=' -f2-)
    CHAT_ID=$(grep -E '^TELEGRAM_HOME_CHANNEL=' "$HERMES_ENV" | cut -d'=' -f2-)
fi

send_alert() {
    local level="$1"
    local message="$2"
    local emoji="✅"
    [ "$level" = "WARNING" ] && emoji="⚠️"
    [ "$level" = "CRITICAL" ] && emoji="🔴"

    if [ -n "${BOT_TOKEN:-}" ] && [ -n "${CHAT_ID:-}" ]; then
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d chat_id="$CHAT_ID" \
            -d parse_mode="Markdown" \
            -d text="${emoji} *Server Health [${level}]*
$(hostname) | $(date '+%Y-%m-%d %H:%M WIB')

${message}" > /dev/null 2>&1
    fi
}

# Collect metrics
RAM_TOTAL=$(free | awk '/Mem:/ {print $2}')
RAM_USED=$(free | awk '/Mem:/ {print $3}')
RAM_PCT=$((RAM_USED * 100 / RAM_TOTAL))
SWAP_USED=$(free | awk '/Swap:/ {print $3}')
DISK_PCT=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')
LOAD_1=$(cat /proc/loadavg | awk '{print $1}')
PG_CONNECTIONS=$(PGPASSWORD="${DB_PASSWORD:-}" psql -h localhost -U "${DB_USER:-stock_app}" -d "${DB_NAME:-stock_monitoring}" -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ' || echo "0")
PG_DEAD_TUPLES=$(PGPASSWORD="${DB_PASSWORD:-}" psql -h localhost -U "${DB_USER:-stock_app}" -d "${DB_NAME:-stock_monitoring}" -t -c "SELECT COALESCE(sum(n_dead_tup),0) FROM pg_stat_user_tables;" 2>/dev/null | tr -d ' ' || echo "0")
STOCK_API_UP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8000/api/stocks 2>/dev/null || echo "000")

# Determine status
STATUS="OK"
ALERTS=""

if [ "$RAM_PCT" -gt 85 ]; then
    STATUS="WARNING"
    ALERTS="${ALERTS}• RAM: ${RAM_PCT}% (tinggi)\n"
elif [ "$RAM_PCT" -gt 95 ]; then
    STATUS="CRITICAL"
    ALERTS="${ALERTS}• RAM: ${RAM_PCT}% (kritis!)\n"
fi

if [ "$DISK_PCT" -gt 80 ]; then
    STATUS="WARNING"
    ALERTS="${ALERTS}• Disk: ${DISK_PCT}% (penuh)\n"
elif [ "$DISK_PCT" -gt 90 ]; then
    STATUS="CRITICAL"
    ALERTS="${ALERTS}• Disk: ${DISK_PCT}% (kritis!)\n"
fi

CPU_COUNT=$(nproc)
LOAD_INT=$(echo "$LOAD_1" | cut -d. -f1)
if [ "$LOAD_INT" -gt $((CPU_COUNT * 3)) ]; then
    STATUS="WARNING"
    ALERTS="${ALERTS}• Load: ${LOAD_1} (tinggi untuk ${CPU_COUNT} CPU)\n"
fi

if [ "$PG_CONNECTIONS" -gt 50 ] 2>/dev/null; then
    STATUS="WARNING"
    ALERTS="${ALERTS}• PostgreSQL: ${PG_CONNECTIONS} koneksi (banyak)\n"
fi

if [ "$PG_DEAD_TUPLES" -gt 100000 ] 2>/dev/null; then
    ALERTS="${ALERTS}• PostgreSQL: ${PG_DEAD_TUPLES} dead tuples (perlu VACUUM)\n"
fi

if [ "$STOCK_API_UP" != "200" ] && [ "$STOCK_API_UP" != "401" ] && [ "$STOCK_API_UP" != "403" ]; then
    STATUS="CRITICAL"
    ALERTS="${ALERTS}• Stock API: DOWN (HTTP ${STOCK_API_UP})\n"
fi

# State change detection
PREV_STATUS="OK"
if [ -f "$STATE_FILE" ]; then
    PREV_STATUS=$(cat "$STATE_FILE")
fi

echo "$STATUS" > "$STATE_FILE"

# Send alert only on state change, or if already in WARNING/CRITICAL (repeat every 6 hours)
if [ "$STATUS" != "$PREV_STATUS" ]; then
    if [ "$STATUS" != "OK" ]; then
        DETAILS="RAM: ${RAM_PCT}% | Disk: ${DISK_PCT}% | Load: ${LOAD_1} | PG Conn: ${PG_CONNECTIONS} | API: ${STOCK_API_UP}"
        send_alert "$STATUS" "Masalah terdeteksi:\n${ALERTS}\nDetail: ${DETAILS}"
    else
        send_alert "OK" "Server kembali normal.\n\nRAM: ${RAM_PCT}% | Disk: ${DISK_PCT}% | Load: ${LOAD_1}"
    fi
fi
