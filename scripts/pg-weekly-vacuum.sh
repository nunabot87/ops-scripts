#!/bin/bash
# Weekly VACUUM ANALYZE for stock_monitoring database
# Runs every Sunday at 04:00 WIB via cron

set -euo pipefail

source /root/stock-monitoring/.env

LOGFILE="/var/log/pg-weekly-vacuum.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Starting weekly VACUUM ANALYZE..." >> "$LOGFILE"

# Run VACUUM ANALYZE on all tables
PGPASSWORD="$DB_PASSWORD" vacuumdb \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --analyze \
    --verbose \
    2>> "$LOGFILE"

EXIT_CODE=$?
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$TIMESTAMP] VACUUM ANALYZE completed successfully" >> "$LOGFILE"
else
    echo "[$TIMESTAMP] VACUUM ANALYZE failed with exit code $EXIT_CODE" >> "$LOGFILE"
fi

# Keep log file under 1MB
tail -500 "$LOGFILE" > "${LOGFILE}.tmp" && mv "${LOGFILE}.tmp" "$LOGFILE"

exit $EXIT_CODE
