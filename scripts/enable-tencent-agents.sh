#!/bin/bash
# Re-enable Tencent Cloud agents
# Usage: sudo bash enable-tencent-agents.sh

echo "🚀 Re-enabling Tencent Cloud agents..."

for svc in tat_agent barad_agent YDEyes stargate; do
    systemctl enable "$svc" 2>/dev/null
    systemctl start "$svc" 2>/dev/null
    echo "$svc: $(systemctl is-active $svc) / $(systemctl is-enabled $svc)"
done

echo ""
echo "✅ Tencent agents re-enabled"
