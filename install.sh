#!/usr/bin/env bash

# --- Installer Script for Cloudflare DDNS (cfddns) ---

REPO="https://raw.githubusercontent.com/nimabbz/cfddns/main"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/cfddns"
CONFIG_FILE="$CONFIG_DIR/cfddns.conf"
CORE_SCRIPT="$INSTALL_DIR/cfddns.sh"
CLI_SCRIPT="$INSTALL_DIR/cfddns"
VERSION_FILE="$CONFIG_DIR/VERSION.txt" # اضافه شده

# ANSI Color Codes (for cleaner terminal output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${YELLOW}--- Cloudflare DDNS Installer (cfddns) ---${NC}"

# 1. Check for 'jq' dependency
if ! command -v jq &> /dev/null; then
    echo -e "⚠️ ${RED}'jq'${NC} is not installed. Installing it now..."
    sudo apt update -y
    sudo apt install -y jq dos2unix
fi

# 2. Download Core Scripts
echo "Downloading core scripts and version file..."
sudo mkdir -p "$CONFIG_DIR"
sudo curl -s "$REPO/cfddns.sh" -o "$CORE_SCRIPT"
sudo curl -s "$REPO/cfddns-cli.sh" -o "$CLI_SCRIPT"
sudo curl -s "$REPO/VERSION.txt" -o "$VERSION_FILE" # دانلود فایل ورژن

# 3. Clean and Set Permissions
echo "Setting permissions..."
sudo dos2unix -q "$CORE_SCRIPT" "$CLI_SCRIPT"
sudo chmod +x "$CORE_SCRIPT"
sudo chmod +x "$CLI_SCRIPT"
# Create initial log file if not exists
sudo touch /var/log/cfddns.log
sudo chmod 664 /var/log/cfddns.log

# 4. Create Initial Config File from template
echo "Creating initial configuration file in ${BLUE}$CONFIG_FILE${NC}..."

# Download the template
sudo curl -s "$REPO/cfddns.conf.example" -o "$CONFIG_FILE"

# Set secure permissions for the config file
sudo chmod 600 "$CONFIG_FILE"

# 5. Final Instructions
echo -e "\n${GREEN}--- Installation Complete! ---${NC}"
echo "The configuration file has been saved to ${BLUE}$CONFIG_FILE${NC}."
echo "You MUST now enter your Cloudflare API details, Zone ID, and Record ID."
echo -e "\n🔥 ${YELLOW}To start the configuration menu, run: cfddns${NC}"