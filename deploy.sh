#!/bin/bash
# Run this locally: bash deploy.sh
# Copies all configs to VPS and runs setup

VPS="root@164.68.99.209"
PASS="Afynjv228"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Deploying to $VPS ==="

# Upload project files to /tmp/mc-setup on VPS
echo "Uploading configs..."
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "$VPS" "rm -rf /tmp/mc-setup && mkdir -p /tmp/mc-setup/plugins"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "$LOCAL_DIR/server.properties" \
  "$LOCAL_DIR/eula.txt" \
  "$LOCAL_DIR/start.sh" \
  "$LOCAL_DIR/fix_gamerules.py" \
  "$VPS":/tmp/mc-setup/

sshpass -p "$PASS" scp -o StrictHostKeyChecking=no -r \
  "$LOCAL_DIR/plugins/"* \
  "$VPS":/tmp/mc-setup/plugins/

# Upload and run setup.sh
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "$LOCAL_DIR/setup.sh" \
  "$VPS":/tmp/setup.sh

echo "Running setup on VPS..."
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -t "$VPS" "chmod +x /tmp/setup.sh && bash /tmp/setup.sh"
