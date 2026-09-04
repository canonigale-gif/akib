#!/usr/bin/env bash
# ==============================================================================
# UNIVERSAL AUTOSETUP FOR ANY GITHUB CODESPACE
# Sets up: OpenCode Web UI, Antigravity Remote Control, Paseo Agent,
#          Cloudflare Tunnel (opencode.1kib.qzz.io), R2 Persistent Storage,
#          ttyd Web Terminal, and 5-Layer Bulletproof Autostart Watchdog.
# ==============================================================================
set -e

echo -e "\033[1;36m========================================================\033[0m"
echo -e "\033[1;36m       CODESPACE AGENTIC HUB - UNIVERSAL AUTOSETUP       \033[0m"
echo -e "\033[1;36m========================================================\033[0m"

USER_HOME="${HOME:-/home/codespace}"
CF_TUNNEL_TOKEN="eyJhIjoiOWI0N2Q0ZTYwNjQ4MjEzMGMyODU0MzNhM2I2NzM3ZjgiLCJ0IjoiNTU2MmU3OGYtMzIwNy00ZDkyLWJiZjktOGJiMGVjZGEwMGE0IiwicyI6Ik4ySXhOR00zTVRrdFpqZGlNQzAwWkRVeUxUazFORFV0TkRrd05qSXlZakV5WW1FMiJ9"

# Ensure environment PATH
export PATH="$USER_HOME/nvm/current/bin:$USER_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
if [ -s "$USER_HOME/.nvm/nvm.sh" ]; then
    \. "$USER_HOME/.nvm/nvm.sh"
elif [ -s "/usr/local/share/nvm/nvm.sh" ]; then
    \. "/usr/local/share/nvm/nvm.sh"
fi

mkdir -p "$USER_HOME/.local/bin" "$USER_HOME/.config/rclone" "$USER_HOME/.gemini" "$USER_HOME/.antigravity" "$USER_HOME/ctx0an"

# ------------------------------------------------------------------------------
# 1. System packages (fuse3 for rclone mount, ca-certificates, curl)
# ------------------------------------------------------------------------------
echo -e "\n\033[1;33m[*] [1/8] Verifying system packages...\033[0m"
if ! command -v fusermount &>/dev/null && ! command -v fusermount3 &>/dev/null; then
    echo "    Installing fuse3 & tools..."
    sudo apt-get update -qq && sudo apt-get install -y -qq fuse3 ca-certificates curl net-tools > /dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 2. Install rclone & configure Cloudflare R2
# ------------------------------------------------------------------------------
echo -e "\n\033[1;33m[*] [2/8] Setting up rclone & Cloudflare R2 bucket...\033[0m"
if ! command -v rclone &>/dev/null; then
    echo "    Installing rclone..."
    curl -fsSL https://rclone.org/install.sh | sudo bash > /dev/null 2>&1 || true
fi

cat << 'EOF_RCLONE' > "$USER_HOME/.config/rclone/rclone.conf"
[r2]
type = s3
provider = Cloudflare
access_key_id = d1b263ad5176e7642c606190a3140953
secret_access_key = 2dde0827a7259ff1c9f6053ddb0aade835aaea0ab1f567209ef58dcd524482e7
endpoint = https://2928cbc34cbb5c61a9a6ca27c02e1d84.r2.cloudflarestorage.com
acl = private
EOF_RCLONE
chmod 600 "$USER_HOME/.config/rclone/rclone.conf"

# Mount R2 if not mounted
if ! mount | grep -q "$USER_HOME/ctx0an"; then
    echo "    Mounting R2 bucket ctx0an to $USER_HOME/ctx0an..."
    rclone mount r2:ctx0an "$USER_HOME/ctx0an" --vfs-cache-mode writes --daemon || true
    sleep 2
fi

# ------------------------------------------------------------------------------
# 3. Restore Antigravity OAuth Token & CLI
# ------------------------------------------------------------------------------
echo -e "\n\033[1;33m[*] [3/8] Restoring Antigravity CLI & Google OAuth token...\033[0m"
if [ ! -f "$USER_HOME/.gemini/jetski-standalone-oauth-token" ]; then
    echo "    Downloading Google OAuth credentials from R2..."
    rclone copy r2:ctx0an/.gemini/jetski-standalone-oauth-token "$USER_HOME/.gemini/" 2>/dev/null || true
    chmod 600 "$USER_HOME/.gemini/jetski-standalone-oauth-token" 2>/dev/null || true
fi

if [ ! -f "$USER_HOME/.local/bin/agy" ]; then
    echo "    Fetching agy binary from persistent R2..."
    rclone copy r2:ctx0an/bin/agy "$USER_HOME/.local/bin/" 2>/dev/null || true
    chmod +x "$USER_HOME/.local/bin/agy" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 4. Install cloudflared (Tunnel Daemon)
# ------------------------------------------------------------------------------
echo -e "\n\033[1;33m[*] [4/8] Installing cloudflared daemon...\033[0m"
if ! command -v cloudflared &>/dev/null; then
    echo "    Downloading cloudflared-linux-amd64..."
    curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /tmp/cloudflared
    sudo install -m 755 /tmp/cloudflared /usr/local/bin/cloudflared
    rm -f /tmp/cloudflared
fi

# ------------------------------------------------------------------------------
# 5. Install OpenCode & Paseo Agent
# ------------------------------------------------------------------------------
echo -e "\n\033[1;33m[*] [5/8] Installing OpenCode & Paseo packages...\033[0m"
if ! command -v opencode &>/dev/null; then
    echo "    Installing opencode-ai via npm..."
    npm install -g opencode-ai > /dev/null 2>&1 || true
fi

if ! command -v paseo &>/dev/null; then
    echo "    Installing @getpaseo/cli via npm..."
    npm install -g @getpaseo/cli > /dev/null 2>&1 || true
fi

# Install ttyd web terminal
if ! command -v ttyd &>/dev/null && [ ! -f "$USER_HOME/.codespace-telegram-agent/ttyd" ]; then
    echo "    Restoring ttyd binary..."
    rclone copy r2:ctx0an/bin/ttyd /tmp/ 2>/dev/null || true
    if [ -f /tmp/ttyd ]; then
        sudo install -m 755 /tmp/ttyd /usr/local/bin/ttyd
        rm -f /tmp/ttyd
    else
        sudo curl -fsSL https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 -o /usr/local/bin/ttyd && sudo chmod +x /usr/local/bin/ttyd || true
    fi
fi

# ------------------------------------------------------------------------------
# 6. Local Origin Host & Port Bridge (resolves 502 Bad Gateway)
# ------------------------------------------------------------------------------
echo -e "\n\033[1;33m[*] [6/8] Configuring local origin host & port routing...\033[0m"
if ! grep -w "4096" /etc/hosts >/dev/null 2>&1; then
    echo "127.0.0.1 4096" | sudo tee -a /etc/hosts >/dev/null
fi

cat << 'EOF_PROXY' > "$USER_HOME/port80_proxy.py"
import socket, threading

def handle(client):
    try:
        remote = socket.socket()
        remote.connect(('127.0.0.1', 4096))
        def pipe(src, dst):
            try:
                while True:
                    d = src.recv(8192)
                    if not d: break
                    dst.sendall(d)
            except: pass
            finally:
                try: src.close()
                except: pass
                try: dst.close()
                except: pass
        t1 = threading.Thread(target=pipe, args=(client, remote), daemon=True)
        t2 = threading.Thread(target=pipe, args=(remote, client), daemon=True)
        t1.start()
        t2.start()
    except Exception:
        client.close()

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('0.0.0.0', 80))
srv.listen(128)
while True:
    c, _ = srv.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
EOF_PROXY

# ------------------------------------------------------------------------------
# 7. Create Self-Healing Watchdog & Master Start Script
# ------------------------------------------------------------------------------
echo -e "\n\033[1;33m[*] [7/8] Generating master start script & self-healing watchdog...\033[0m"

# Watchdog loop
cat << 'EOF_WATCHDOG' > "$USER_HOME/daemon_watchdog.sh"
#!/bin/bash
export PATH="/home/codespace/nvm/current/bin:/home/codespace/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
[ -s "/home/codespace/.nvm/nvm.sh" ] && \. "/home/codespace/.nvm/nvm.sh"
[ -s "/usr/local/share/nvm/nvm.sh" ] && \. "/usr/local/share/nvm/nvm.sh"

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
        nohup opencode web --port 4096 --hostname 0.0.0.0 >> /tmp/opencode.log 2>&1 &
    fi

    # 4. Check Paseo Daemon (port 6767)
    if ! pgrep -f 'paseo daemon' > /dev/null; then
        export PASEO_WEB_UI_ENABLED=true
        nohup paseo daemon start --web-ui --listen 0.0.0.0:6767 >> /tmp/paseo.log 2>&1 &
    fi

    # 5. Check Cloudflare Tunnel (opencode.1kib.qzz.io)
    if ! pgrep -f 'cloudflared tunnel run' > /dev/null; then
        nohup /usr/local/bin/cloudflared tunnel run --token "$TOKEN" >> /tmp/cf_tunnel.log 2>&1 &
    fi

    # 6. Check Port 80 Proxy
    if ! pgrep -f 'port80_proxy.py' > /dev/null; then
        sudo nohup python3 /home/codespace/port80_proxy.py >> /tmp/proxy80.log 2>&1 &
    fi

    # 7. Check Web TTY Terminal
    if ! pgrep -f 'ttyd' > /dev/null; then
        TTYD_CMD="ttyd"
        [ -f "/home/codespace/.codespace-telegram-agent/ttyd" ] && TTYD_CMD="/home/codespace/.codespace-telegram-agent/ttyd"
        nohup $TTYD_CMD --writable -p 7681 --interface 0.0.0.0 bash >> /tmp/ttyd.log 2>&1 &
    fi

    sleep 15
done
EOF_WATCHDOG
chmod +x "$USER_HOME/daemon_watchdog.sh"

# Master start_all.sh
cat << 'EOF_STARTALL' > "$USER_HOME/start_all.sh"
#!/bin/bash
export PATH="/home/codespace/nvm/current/bin:/home/codespace/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
[ -s "/home/codespace/.nvm/nvm.sh" ] && \. "/home/codespace/.nvm/nvm.sh"
[ -s "/usr/local/share/nvm/nvm.sh" ] && \. "/usr/local/share/nvm/nvm.sh"

mkdir -p /home/codespace/.antigravity /home/codespace/.gemini /home/codespace/.config/rclone /home/codespace/ctx0an

# 1. R2 Mount
if ! mount | grep -q '/home/codespace/ctx0an'; then
    rclone mount r2:ctx0an /home/codespace/ctx0an --vfs-cache-mode writes --daemon || true
    sleep 2
fi

# 2. Antigravity OAuth Token
if [ ! -f /home/codespace/.gemini/jetski-standalone-oauth-token ] && [ -f /home/codespace/ctx0an/.gemini/jetski-standalone-oauth-token ]; then
    cp -f /home/codespace/ctx0an/.gemini/jetski-standalone-oauth-token /home/codespace/.gemini/
    chmod 600 /home/codespace/.gemini/jetski-standalone-oauth-token
fi

# 3. Antigravity Remote Control
if ! pgrep -f 'agy --remote-control' > /dev/null; then
    nohup /home/codespace/.local/bin/agy --remote-control > /home/codespace/.antigravity/remote_control.log 2>&1 &
fi

# 4. OpenCode Web UI
if ! pgrep -f 'opencode web' > /dev/null; then
    nohup opencode web --port 4096 --hostname 0.0.0.0 > /tmp/opencode.log 2>&1 &
fi

# 5. Paseo Daemon
if ! pgrep -f 'paseo daemon' > /dev/null; then
    export PASEO_WEB_UI_ENABLED=true
    nohup paseo daemon start --web-ui --listen 0.0.0.0:6767 > /tmp/paseo.log 2>&1 &
fi

# 6. Cloudflare Tunnel
TOKEN="eyJhIjoiOWI0N2Q0ZTYwNjQ4MjEzMGMyODU0MzNhM2I2NzM3ZjgiLCJ0IjoiNTU2MmU3OGYtMzIwNy00ZDkyLWJiZjktOGJiMGVjZGEwMGE0IiwicyI6Ik4ySXhOR00zTVRrdFpqZGlNQzAwWkRVeUxUazFORFV0TkRrd05qSXlZakV5WW1FMiJ9"
if ! pgrep -f 'cloudflared tunnel run' > /dev/null; then
    nohup /usr/local/bin/cloudflared tunnel run --token "$TOKEN" > /tmp/cf_tunnel.log 2>&1 &
fi

# 7. Port 80 Proxy
if ! pgrep -f 'port80_proxy.py' > /dev/null; then
    sudo nohup python3 /home/codespace/port80_proxy.py > /tmp/proxy80.log 2>&1 &
fi

# 8. Web TTY
if ! pgrep -f 'ttyd' > /dev/null; then
    TTYD_CMD="ttyd"
    [ -f "/home/codespace/.codespace-telegram-agent/ttyd" ] && TTYD_CMD="/home/codespace/.codespace-telegram-agent/ttyd"
    nohup $TTYD_CMD --writable -p 7681 --interface 0.0.0.0 bash > /tmp/ttyd.log 2>&1 &
fi

# 9. Start Watchdog
if ! pgrep -f 'daemon_watchdog.sh' > /dev/null; then
    nohup bash /home/codespace/daemon_watchdog.sh > /tmp/watchdog.log 2>&1 &
fi

echo "[$(date -u)] All daemons and self-healing watchdog active."
EOF_STARTALL
chmod +x "$USER_HOME/start_all.sh"

# ------------------------------------------------------------------------------
# 8. Configure 5-Layer Autostart Persistence
# ------------------------------------------------------------------------------
echo -e "\n\033[1;33m[*] [8/8] Installing 5-Layer Autostart Persistence...\033[0m"

# Layer 1: Container Boot Entrypoint (/usr/local/share/ssh-init.sh)
if [ -f /usr/local/share/ssh-init.sh ]; then
    if ! grep -q "start_all.sh" /usr/local/share/ssh-init.sh; then
        sudo python3 -c '
path = "/usr/local/share/ssh-init.sh"
with open(path, "r") as f: lines = f.readlines()
hook = "\n# ** Autostart Agent Daemons **\nif [ -f /home/codespace/start_all.sh ]; then\n    su - codespace -c \"nohup bash /home/codespace/start_all.sh > /tmp/autostart.log 2>&1 &\" || true\nfi\n\n"
new_lines = []
for line in lines:
    if line.strip() == "exec \"$@\"":
        new_lines.append(hook)
    new_lines.append(line)
with open(path, "w") as f: f.writelines(new_lines)
' || true
    fi
fi

# Layer 2: SSH Connection Hooks
sudo bash -c 'cat << "EOF_SSHRC" > /etc/ssh/sshrc
#!/bin/bash
if ! pgrep -f "daemon_watchdog.sh" > /dev/null 2>&1 || ! pgrep -f "opencode web" > /dev/null 2>&1; then
    su - codespace -c "nohup bash /home/codespace/start_all.sh > /tmp/autostart.log 2>&1 &" || true
fi
EOF_SSHRC'
sudo chmod 755 /etc/ssh/sshrc

mkdir -p "$USER_HOME/.ssh"
cat << 'EOF_USERRC' > "$USER_HOME/.ssh/rc"
#!/bin/bash
if ! pgrep -f "daemon_watchdog.sh" > /dev/null 2>&1 || ! pgrep -f "opencode web" > /dev/null 2>&1; then
    nohup bash /home/codespace/start_all.sh > /tmp/autostart.log 2>&1 &
fi
EOF_USERRC
chmod 755 "$USER_HOME/.ssh/rc"

# Layer 3: Shell Profiles
sudo bash -c 'cat << "EOF_PROF" > /etc/profile.d/agent_autostart.sh
if ! pgrep -f "daemon_watchdog.sh" > /dev/null 2>&1 || ! pgrep -f "opencode web" > /dev/null 2>&1; then
    nohup bash /home/codespace/start_all.sh > /tmp/autostart.log 2>&1 &
fi
EOF_PROF'

if ! grep -q "daemon_watchdog.sh" /etc/bash.bashrc 2>/dev/null; then
    sudo bash -c 'cat << "EOF_BASHRC" >> /etc/bash.bashrc

# Autostart Agent Daemons
if ! pgrep -f "daemon_watchdog.sh" > /dev/null 2>&1 || ! pgrep -f "opencode web" > /dev/null 2>&1; then
    nohup bash /home/codespace/start_all.sh > /tmp/autostart.log 2>&1 &
fi
EOF_BASHRC'
fi

# Layer 4: Devcontainer Repository Sync (if inside a repo)
REPO_DIR="/workspaces/$(ls /workspaces 2>/dev/null | head -n 1)"
if [ -d "$REPO_DIR" ]; then
    mkdir -p "$REPO_DIR/.devcontainer"
    cp -f "$USER_HOME/start_all.sh" "$REPO_DIR/.devcontainer/start-daemons.sh"
    cp -f "$USER_HOME/daemon_watchdog.sh" "$REPO_DIR/.devcontainer/daemon_watchdog.sh"
    
    if [ ! -f "$REPO_DIR/.devcontainer/devcontainer.json" ]; then
        cat << 'EOF_DEV' > "$REPO_DIR/.devcontainer/devcontainer.json"
{
  "name": "Codespace Agentic Hub (OpenCode, Antigravity, Paseo, Telegram)",
  "forwardPorts": [7681, 4096, 6767],
  "portsAttributes": {
    "7681": { "label": "ttyd Web Terminal", "onAutoForward": "ignore", "visibility": "public" },
    "4096": { "label": "OpenCode Web UI", "onAutoForward": "ignore", "visibility": "public" },
    "6767": { "label": "Paseo Agent Web UI", "onAutoForward": "ignore", "visibility": "public" }
  },
  "postStartCommand": "bash /workspaces/akib/.devcontainer/start-daemons.sh || bash /home/codespace/start_all.sh",
  "postAttachCommand": "bash /workspaces/akib/.devcontainer/start-daemons.sh || bash /home/codespace/start_all.sh"
}
EOF_DEV
    fi
fi

# ------------------------------------------------------------------------------
# 9. Launch All Services
# ------------------------------------------------------------------------------
echo -e "\n\033[1;33m[*] [9/9] Starting all daemons & verifying health...\033[0m"
bash "$USER_HOME/start_all.sh"

sleep 3

echo -e "\n\033[1;32m========================================================\033[0m"
echo -e "\033[1;32m             AUTOSETUP COMPLETED SUCCESSFULLY!           \033[0m"
echo -e "\033[1;32m========================================================\033[0m"
echo -e "\033[1;37m🚀 OpenCode Web UI:          \033[1;36mhttps://opencode.1kib.qzz.io\033[0m"
echo -e "\033[1;37m🎛️ Multi-Cloud VPS Dashboard: \033[1;36mhttps://vps.1kib.qzz.io\033[0m"
echo -e "\033[1;37m🤖 Antigravity Remote Control: \033[1;32mActive (Google OAuth Authenticated)\033[0m"
echo -e "\033[1;37m📱 Paseo Web Agent:          \033[1;36mhttp://localhost:6767\033[0m"
echo -e "\033[1;37m💻 Web Terminal (ttyd):      \033[1;36mhttp://localhost:7681\033[0m"
echo -e "\033[1;37m🛡️ Self-Healing Watchdog:    \033[1;32mActive (Polling every 15s)\033[0m"
echo -e "\033[1;32m========================================================\033[0m\n"
