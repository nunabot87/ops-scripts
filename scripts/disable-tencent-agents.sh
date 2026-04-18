#!/bin/bash
# Disable Tencent Cloud agents (save ~162 MB RAM)
# Usage: sudo bash disable-tencent-agents.sh

echo "🛑 Disabling Tencent Cloud agents..."

for svc in YDEyes YDLive barad_agent tat_agent stargate; do
    systemctl stop "$svc" 2>/dev/null
    systemctl disable "$svc" 2>/dev/null
    echo "$svc: $(systemctl is-active $svc 2>/dev/null || echo 'inactive') / $(systemctl is-enabled $svc 2>/dev/null || echo 'disabled')"
done

# Kill any lingering processes
ps aux | grep -E 'qcloud|YunJing|barad|YDLive|YDService|stargate' | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null

echo ""
echo "✅ All Tencent agents stopped & disabled (~162 MB freed)"
echo "📋 To re-enable: sudo bash /root/ops-scripts/scripts/enable-tencent-agents.sh"
