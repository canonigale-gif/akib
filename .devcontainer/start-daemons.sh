#!/bin/bash
export PATH="/home/codespace/nvm/current/bin:/home/codespace/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
[ -s "/home/codespace/.nvm/nvm.sh" ] && \. "/home/codespace/.nvm/nvm.sh"

mkdir -p /home/codespace/.antigravity /home/codespace/.gemini /home/codespace/.config/rclone /home/codespace/ctx0an

# 0. Ensure rclone config exists
if [ ! -f /home/codespace/.config/rclone/rclone.conf ]; then
    cat << 'EOF_RCLONE' > /home/codespace/.config/rclone/rclone.conf
[r2]
type = s3
provider = Cloudflare
access_key_id = d1b263ad5176e7642c606190a3140953
secret_access_key = 2dde0827a7259ff1c9f6053ddb0aade835aaea0ab1f567209ef58dcd524482e7
endpoint = https://2928cbc34cbb5c61a9a6ca27c02e1d84.r2.cloudflarestorage.com
acl = private
EOF_RCLONE
    chmod 600 /home/codespace/.config/rclone/rclone.conf
fi

# 1. Mount R2 bucket if not mounted
if ! mount | grep -q '/home/codespace/ctx0an'; then
    rclone mount r2:ctx0an /home/codespace/ctx0an --vfs-cache-mode writes --daemon || true
    sleep 2
fi

# 2. Restore Antigravity OAuth token from R2 if needed
if [ ! -f /home/codespace/.gemini/jetski-standalone-oauth-token ] && [ -f /home/codespace/ctx0an/.gemini/jetski-standalone-oauth-token ]; then
    cp -f /home/codespace/ctx0an/.gemini/jetski-standalone-oauth-token /home/codespace/.gemini/
    chmod 600 /home/codespace/.gemini/jetski-standalone-oauth-token
elif [ -f /home/codespace/.gemini/jetski-standalone-oauth-token ] && [ -d /home/codespace/ctx0an ]; then
    mkdir -p /home/codespace/ctx0an/.gemini
    cp -f /home/codespace/.gemini/jetski-standalone-oauth-token /home/codespace/ctx0an/.gemini/ 2>/dev/null || true
fi

# 3. Start Antigravity Remote Control Daemon
if ! pgrep -f 'agy --remote-control' > /dev/null; then
    nohup /home/codespace/.local/bin/agy --remote-control > /home/codespace/.antigravity/remote_control.log 2>&1 &
fi

# 4. Start OpenCode Web UI (port 4096)
if ! pgrep -f 'opencode web' > /dev/null; then
    nohup /home/codespace/nvm/current/bin/opencode web --port 4096 --hostname 0.0.0.0 > /tmp/opencode.log 2>&1 &
fi

# 5. Start Paseo Daemon (port 6767)
if ! pgrep -f 'paseo daemon' > /dev/null; then
    export PASEO_WEB_UI_ENABLED=true
    nohup /home/codespace/nvm/current/bin/paseo daemon start --web-ui --listen 0.0.0.0:6767 > /tmp/paseo.log 2>&1 &
fi

# 6. Start Cloudflare Named Tunnel for OpenCode (opencode.1kib.qzz.io)
TOKEN="eyJhIjoiOWI0N2Q0ZTYwNjQ4MjEzMGMyODU0MzNhM2I2NzM3ZjgiLCJ0IjoiNTU2MmU3OGYtMzIwNy00ZDkyLWJiZjktOGJiMGVjZGEwMGE0IiwicyI6Ik4ySXhOR00zTVRrdFpqZGlNQzAwWkRVeUxUazFORFV0TkRrd05qSXlZakV5WW1FMiJ9"
if ! pgrep -f 'cloudflared tunnel run' > /dev/null; then
    nohup /usr/local/bin/cloudflared tunnel run --token "$TOKEN" > /tmp/cf_tunnel.log 2>&1 &
fi

# 7. Start Telegram Agent & Web TTY if present
if [ -f "/home/codespace/.codespace-telegram-agent/start.sh" ]; then
    nohup bash /home/codespace/.codespace-telegram-agent/start.sh > /dev/null 2>&1 &
fi

# 8. Start Watchdog loop if not already running
if ! pgrep -f 'daemon_watchdog.sh' > /dev/null; then
    nohup bash /home/codespace/daemon_watchdog.sh > /tmp/watchdog.log 2>&1 &
fi

echo "[$(date -u)] All daemons and watchdog started successfully."
