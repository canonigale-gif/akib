#!/bin/bash
mkdir -p /home/codespace/.antigravity

# 1. Mount R2 if not mounted
if ! mount | grep -q '/home/codespace/ctx0an'; then
    rclone mount r2:ctx0an /home/codespace/ctx0an --vfs-cache-mode writes --daemon || true
fi

# 2. Start Antigravity Remote Control
if ! pgrep -f 'agy --remote-control' > /dev/null; then
    nohup /home/codespace/.local/bin/agy --remote-control > /home/codespace/.antigravity/remote_control.log 2>&1 &
fi

# 3. Start OpenCode Web UI
if ! pgrep -f 'opencode web' > /dev/null; then
    nohup opencode web --port 4096 --hostname 0.0.0.0 > /tmp/opencode.log 2>&1 &
fi

# 4. Start Paseo Daemon
if ! pgrep -f 'paseo daemon' > /dev/null; then
    export PASEO_WEB_UI_ENABLED=true
    nohup paseo daemon start --web-ui --listen 0.0.0.0:6767 > /tmp/paseo.log 2>&1 &
fi

echo 'ALL_SERVICES_ONLINE'
ps aux | grep -E 'agy|opencode|paseo|rclone' | grep -v grep
