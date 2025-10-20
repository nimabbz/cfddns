#!/usr/bin/env bash

# --- Installer Script for Cloudflare DDNS (cfddns) ---

REPO="https://raw.githubusercontent.com/nimabbz/cfddns/main" # Your GitHub username
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/cfddns"
CONFIG_FILE="$CONFIG_DIR/cfddns.conf"
CORE_SCRIPT="$INSTALL_DIR/cfddns.sh"
CLI_SCRIPT="$INSTALL_DIR/cfddns" # The main command

echo -e "\n${YELLOW}--- Cloudflare DDNS Installer (cfddns) ---${NC}"

# 1. Check for 'jq' dependency
if ! command -v jq &> /dev/null; then
    echo -e "⚠️ ${RED}'jq'${NC} is not installed. Installing it now..."
    sudo apt update -y
    sudo apt install -y jq dos2unix # Install dos2unix here too, just in case
fi

# 2. Download Core Scripts
echo "Downloading core scripts..."
sudo mkdir -p "$CONFIG_DIR"
sudo curl -s "$REPO/cfddns.sh" -o "$CORE_SCRIPT"
sudo curl -s "$REPO/cfddns-cli.sh" -o "$CLI_SCRIPT"

# 3. Clean and Set Permissions
echo "Setting permissions..."
sudo dos2unix -q "$CORE_SCRIPT" "$CLI_SCRIPT" # Ensure Unix format
sudo chmod +x "$CORE_SCRIPT"
sudo chmod +x "$CLI_SCRIPT"

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
echo -e "\n🔥 ${YELLOW}NEXT STEPS:${NC}"
echo -e "1. Run: ${GREEN}cfddns${NC} (to access the main menu)"
echo -e "2. Select option ${YELLOW}3 (Change Settings)${NC} to input all required IDs/Keys."
echo -e "3. Activate the Cron Job from the settings menu."