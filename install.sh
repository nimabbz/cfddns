#!/usr/bin/env bash

# --- Installer Script for Cloudflare DDNS (cfddns) ---

REPO="https://raw.githubusercontent.com/nimabbz/cfddns/main"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/cfddns"
CONFIG_FILE="$CONFIG_DIR/cfddns.conf"
CORE_SCRIPT="$INSTALL_DIR/cfddns.sh"
CLI_SCRIPT="$INSTALL_DIR/cfddns" # The main command

echo "--- Cloudflare DDNS Installer ---"

# 1. Check for 'jq' dependency
if ! command -v jq &> /dev/null; then
    echo "⚠️ 'jq' is not installed. Installing it now..."
    sudo apt update && sudo apt install -y jq
fi

# 2. Download Core Scripts
echo "Downloading core scripts..."
sudo mkdir -p "$CONFIG_DIR"
sudo curl -s "$REPO/cfddns.sh" -o "$CORE_SCRIPT"
sudo curl -s "$REPO/cfddns-cli.sh" -o "$CLI_SCRIPT"

# 3. Fix Shebang (ensures compatibility with /usr/bin/bash or /bin/bash)
sudo sed -i '1s|.*|#!/usr/bin/env bash|' "$CORE_SCRIPT"
sudo sed -i '1s|.*|#!/usr/bin/env bash|' "$CLI_SCRIPT"

# 4. Set Permissions
sudo chmod +x "$CORE_SCRIPT"
sudo chmod +x "$CLI_SCRIPT"

# 5. Create Initial Config File (downloading clean template)
echo "Downloading configuration template to $CONFIG_FILE..."
sudo curl -s "$REPO/cfddns.conf.example" -o "$CONFIG_FILE"

# Set secure permissions for the config file
sudo chmod 600 "$CONFIG_FILE"

# Prompt user for initial sensitive data
echo ""
echo "🚨 SECURITY NOTE: Please enter your Cloudflare details now:"
read -r -p "Enter CF Email: " CF_EMAIL_TEMP
read -r -p "Enter CF API Key/Token: " CF_API_KEY_TEMP

# Use 'sed' to replace the empty values in the config file
sudo sed -i "s|CF_EMAIL=\"\"|CF_EMAIL=\"$CF_EMAIL_TEMP\"|" "$CONFIG_FILE"
sudo sed -i "s|CF_API_KEY=\"\"|CF_API_KEY=\"$CF_API_KEY_TEMP\"|" "$CONFIG_FILE"

echo "Email and API Key saved to $CONFIG_FILE. Please add Zone/Record IDs manually."

# 6. Final Instructions
echo "--- Installation Complete! ---"
echo "Configuration has been saved to $CONFIG_FILE"
echo "You must edit this file to remove or replace the default sensitive information."
echo ""
echo "🔥 Next Steps:"
echo "1. Run: sudo nano $CONFIG_FILE (and update the API keys/IDs)"
echo "2. Run: cfddns update-cron (to apply the initial settings)"
echo "3. Run: cfddns (to access the main menu)"