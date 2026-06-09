#!/bin/bash
set -e

GIT_REPO="https://github.com/S1nuxoff/SMP-Minecraft.git"
MC_DIR="/opt/minecraft"
RCON_PASS="rcon_smp_2026"
RCON_PORT=25575
TELEGRAM_TOKEN="8947827056:AAHPxSFRl2XnH3r-ZXyT4PtCnQAa54laIFQ"
TELEGRAM_CHAT_ID="0"  # Fill this after getting chat_id from bot

echo "=== Minecraft SMP Server Setup ==="

# Java 21
echo "[1/7] Installing Java 21..."
apt-get update -y -q
apt-get install -y -q openjdk-21-jre-headless git wget curl python3 python3-pip

pip3 install nbtlib -q --break-system-packages

# Minecraft user
echo "[2/7] Creating minecraft user..."
useradd -r -m -U -d "$MC_DIR" -s /bin/false minecraft 2>/dev/null || true
mkdir -p "$MC_DIR/plugins"
mkdir -p "$MC_DIR/logs"

# Copy configs (uploaded via scp by deploy.sh)
echo "[3/7] Copying configs..."
MC_CONFIG="/tmp/mc-setup"
cp "$MC_CONFIG/server.properties" "$MC_DIR/"
cp "$MC_CONFIG/eula.txt" "$MC_DIR/"
cp "$MC_CONFIG/start.sh" "$MC_DIR/"
cp "$MC_CONFIG/fix_gamerules.py" "$MC_DIR/"
chmod +x "$MC_DIR/start.sh"
cp -r "$MC_CONFIG/plugins/"* "$MC_DIR/plugins/"

# Paper JAR — get latest stable version dynamically
echo "[4/7] Downloading Paper (latest stable)..."
PAPER_VER=$(curl -s "https://api.papermc.io/v2/projects/paper" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); stable=[v for v in d['versions'] if '-pre' not in v and '-rc' not in v]; print(stable[-1])")
echo "  Version: $PAPER_VER"
PAPER_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$PAPER_VER/builds" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['builds'][-1]['build'])")
PAPER_FILE=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$PAPER_VER/builds/$PAPER_BUILD" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['downloads']['application']['name'])")
wget -q -O "$MC_DIR/paper.jar" \
  "https://api.papermc.io/v2/projects/paper/versions/$PAPER_VER/builds/$PAPER_BUILD/downloads/$PAPER_FILE"

# Plugin JARs
echo "[5/7] Downloading plugins..."
cd "$MC_DIR/plugins"

# AuthMe 6.0.0
wget -q -O AuthMe.jar \
  "https://github.com/AuthMe/AuthMeReloaded/releases/download/6.0.0/AuthMe-6.0.0-paper.jar"

# Multiverse-Core (latest)
MV_URL=$(curl -s "https://api.github.com/repos/Multiverse/Multiverse-Core/releases/latest" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(next(a['browser_download_url'] for a in d['assets'] if a['name'].endswith('.jar')))")
wget -q -O Multiverse-Core.jar "$MV_URL"

# Dynmap (latest)
DYNMAP_URL=$(curl -s "https://api.github.com/repos/webbukkit/dynmap/releases/latest" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(next(a['browser_download_url'] for a in d['assets'] if 'spigot' in a['name'].lower() and a['name'].endswith('.jar')))")
wget -q -O Dynmap.jar "$DYNMAP_URL"

# BreweryX (latest)
BREWERY_URL=$(curl -s "https://api.github.com/repos/BreweryTeam/BreweryX/releases/latest" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(next(a['browser_download_url'] for a in d['assets'] if a['name'].endswith('.jar')))")
wget -q -O BreweryX.jar "$BREWERY_URL"

# PlayerHeads (head drops on kill) - Spigot resource 21632
wget -q -O PlayerHeads.jar \
  "https://github.com/nicholasnge/PlayerHeads/releases/download/5.3.0/PlayerHeads-5.3.0.jar" 2>/dev/null \
  || echo "  WARN: PlayerHeads download failed, install manually"

# TgBridge (Telegram notifications)
TGBRIDGE_URL=$(curl -s "https://api.github.com/repos/kraftwerk28/spigot-tg-bridge/releases/latest" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(next(a['browser_download_url'] for a in d['assets'] if a['name'].endswith('.jar')))" 2>/dev/null || echo "")
if [ -n "$TGBRIDGE_URL" ]; then
  wget -q -O TgBridge.jar "$TGBRIDGE_URL"
else
  echo "  WARN: TgBridge download failed, install manually"
fi

# Write TgBridge config with actual token
mkdir -p "$MC_DIR/plugins/tgbridge"
cat > "$MC_DIR/plugins/tgbridge/config.yml" << EOF
bot-token: "$TELEGRAM_TOKEN"
chat-id: $TELEGRAM_CHAT_ID

server-start-message: "✅ Сервер запущено"
server-stop-message: "🛑 Сервер зупинено"
player-join-message: "➕ **%username%** зайшов на сервер"
player-quit-message: "➖ **%username%** вийшов з сервера"
player-death-message: "💀 %death_message%"
telegram-to-game-chat-format: "§9[TG] §f%username% §7> %message%"
enable-telegram-to-game-chat: true
EOF

# Permissions
echo "[6/7] Setting permissions..."
chown -R minecraft:minecraft "$MC_DIR"

# Systemd service
echo "[7/7] Installing systemd service..."
cp /tmp/mc-setup/minecraft.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable minecraft

# First run — generate world and authlobby
echo ""
echo "=== Starting server for first run... ==="
systemctl start minecraft

echo "Waiting for server to fully start (up to 3 min)..."
timeout 180 bash -c "until grep -q 'Done' $MC_DIR/logs/latest.log 2>/dev/null; do sleep 3; done" \
  && echo "Server started!" || { echo "Timeout — check logs: $MC_DIR/logs/latest.log"; exit 1; }

# mcrcon for RCON commands
cd /tmp
wget -q -O mcrcon.tar.gz \
  "https://github.com/Tiiffi/mcrcon/releases/download/v0.7.2/mcrcon-0.7.2-linux-x86-64.tar.gz"
tar -xzf mcrcon.tar.gz
MCRCON="$(pwd)/mcrcon"
chmod +x "$MCRCON"

run_rcon() {
  "$MCRCON" -H localhost -P $RCON_PORT -p "$RCON_PASS" "$1"
}

echo "Creating authlobby world..."
run_rcon "mv create authlobby FLAT"
sleep 8

echo "Stopping server to apply authlobby gamerules..."
systemctl stop minecraft
sleep 5

echo "Editing authlobby gamerules..."
python3 "$MC_DIR/fix_gamerules.py"

echo "Restarting server..."
systemctl start minecraft

timeout 180 bash -c "until grep -q 'Done' $MC_DIR/logs/latest.log 2>/dev/null; do sleep 3; done" \
  && echo "Server restarted!" || echo "WARN: Check logs"

sleep 3
run_rcon "op S1nuxoff"

echo ""
echo "=== Setup complete! ==="
echo "Server:  164.68.99.209:25565"
echo "Dynmap:  http://164.68.99.209:8123"
echo ""
echo "TODO: Set your Telegram chat-id in /opt/minecraft/plugins/tgbridge/config.yml"
echo "  1. Write /start to your bot"
echo "  2. Open: https://api.telegram.org/bot8947827056:AAHPxSFRl2XnH3r-ZXyT4PtCnQAa54laIFQ/getUpdates"
echo "  3. Find 'id' in 'chat' object and paste it into config.yml"
echo "  4. systemctl restart minecraft"
