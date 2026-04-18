# Ops Scripts - Stock Monitoring Server
Server maintenance, health check, and optimization scripts.

## Scripts
- `server-health-check.sh` — RAM/Disk/Load/API monitoring with Telegram alerts
- `pg-weekly-vacuum.sh` — Weekly PostgreSQL VACUUM ANALYZE

## Configs
- `etc/logrotate.d/postgresql` — PostgreSQL log rotation
- `etc/systemd/stock-monitoring.service` — Systemd service with auto-restart
- `etc/sysctl.d/99-stock-server-tuning.conf` — Kernel tuning (swappiness, dirty pages)
