#!/bin/bash
mkdir -p /home/codespace/.antigravity /home/codespace/.gemini

# 1. Mount R2 bucket if not mounted
if ! mount | grep -q '/home/codespace/ctx0an'; then
    rclone mount r2:ctx0an /home/codespace/ctx0an --vfs-cache-mode writes --daemon || true
    sleep 2
fi

# 2. Restore Antigravity OAuth token from R2 if needed
if [ ! -f /home/codespace/.gemini/jetski-standalone-oauth-token ] && [ -f /home/codespace/ctx0an/.gemini/jetski-standalone-oauth-token ]; then
    cp -f /home/codespace/ctx0an/.gemini/jetski-standalone-oauth-token /home/codespace/.gemini/
    chmod 600 /home/codespace/.gemini/jetski-standalone-oauth-token
fi

# 3. Start Antigravity Remote Control Daemon
if ! pgrep -f 'agy --remote-control' > /dev/null; then
    nohup /home/codespace/.local/bin/agy --remote-control > /home/codespace/.antigravity/remote_control.log 2>&1 &
fi

# 4. Start OpenCode Web UI
if ! pgrep -f 'opencode web' > /dev/null; then
    nohup opencode web --port 4096 --hostname 0.0.0.0 > /tmp/opencode.log 2>&1 &
fi

# 5. Start Paseo Daemon
if ! pgrep -f 'paseo daemon' > /dev/null; then
    export PASEO_WEB_UI_ENABLED=true
    nohup paseo daemon start --web-ui --listen 0.0.0.0:6767 > /tmp/paseo.log 2>&1 &
fi

# 6. Start Cloudflare Named Tunnel (opencode.1kib.qzz.io)
TOKEN="eyJhIjoiOWI0N2Q0ZTYwNjQ4MjEzMGMyODU0MzNhM2I2NzM3ZjgiLCJ0IjoiNTU2MmU3OGYtMzIwNy00ZDkyLWJiZjktOGJiMGVjZGEwMGE0IiwicyI6Ik4ySXhOR00zTVRrdFpqZGlNQzAwWkRVeUxUazFORFV0TkRrd05qSXlZakV5WW1FMiJ9"
if ! pgrep -f 'cloudflared tunnel run' > /dev/null; then
    nohup /usr/local/bin/cloudflared tunnel run --token "$TOKEN" > /tmp/cf_tunnel.log 2>&1 &
fi
