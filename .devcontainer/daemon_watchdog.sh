#!/bin/bash
export PATH="/home/codespace/nvm/current/bin:/home/codespace/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
[ -s "/home/codespace/.nvm/nvm.sh" ] && \. "/home/codespace/.nvm/nvm.sh"

TOKEN="eyJhIjoiOWI0N2Q0ZTYwNjQ4MjEzMGMyODU0MzNhM2I2NzM3ZjgiLCJ0IjoiNTU2MmU3OGYtMzIwNy00ZDkyLWJiZjktOGJiMGVjZGEwMGE0IiwicyI6Ik4ySXhOR00zTVRrdFpqZGlNQzAwWkRVeUxUazFORFV0TkRrd05qSXlZakV5WW1FMiJ9"

while true; do
    # 1. Check R2 mount
    if ! mount | grep -q '/home/codespace/ctx0an'; then
        mkdir -p /home/codespace/ctx0an
        rclone mount r2:ctx0an /home/codespace/ctx0an --vfs-cache-mode writes --daemon || true
        sleep 2
    fi

    # 2. Check Antigravity Remote Control
    if ! pgrep -f 'agy --remote-control' > /dev/null; then
        if [ ! -f /home/codespace/.gemini/jetski-standalone-oauth-token ] && [ -f /home/codespace/ctx0an/.gemini/jetski-standalone-oauth-token ]; then
            mkdir -p /home/codespace/.gemini
            cp -f /home/codespace/ctx0an/.gemini/jetski-standalone-oauth-token /home/codespace/.gemini/
            chmod 600 /home/codespace/.gemini/jetski-standalone-oauth-token
        fi
        nohup /home/codespace/.local/bin/agy --remote-control >> /home/codespace/.antigravity/remote_control.log 2>&1 &
    fi

    # 3. Check OpenCode Web UI (port 4096)
    if ! pgrep -f 'opencode web' > /dev/null; then
        nohup /home/codespace/nvm/current/bin/opencode web --port 4096 --hostname 0.0.0.0 >> /tmp/opencode.log 2>&1 &
    fi

    # 4. Check Paseo Daemon (port 6767)
    if ! pgrep -f 'paseo daemon' > /dev/null; then
        export PASEO_WEB_UI_ENABLED=true
        nohup /home/codespace/nvm/current/bin/paseo daemon start --web-ui --listen 0.0.0.0:6767 >> /tmp/paseo.log 2>&1 &
    fi

    # 5. Check Cloudflare Tunnel (opencode.1kib.qzz.io)
    if ! pgrep -f 'cloudflared tunnel run' > /dev/null; then
        nohup /usr/local/bin/cloudflared tunnel run --token "$TOKEN" >> /tmp/cf_tunnel.log 2>&1 &
    fi

    # 6. Check Telegram Agent & Web TTY
    if [ -f "/home/codespace/.codespace-telegram-agent/start.sh" ]; then
        if ! pgrep -f 'node.*agent.js' > /dev/null || ! pgrep -f 'ttyd' > /dev/null; then
            nohup bash /home/codespace/.codespace-telegram-agent/start.sh > /dev/null 2>&1 &
        fi
    fi

    sleep 15
done
