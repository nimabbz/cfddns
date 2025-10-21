#!/usr/bin/env bash

CONFIG_DIR="/etc/cfddns"
CONFIG_FILE="$CONFIG_DIR/cfddns.conf"
VERSION_FILE="$CONFIG_DIR/VERSION.txt"
CORE_SCRIPT="/usr/local/bin/cfddns.sh"
CLI_SCRIPT="/usr/local/bin/cfddns"

# --- ANSI Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to source the config file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        dos2unix -q "$CONFIG_FILE" 2>/dev/null
        source "$CONFIG_FILE"
    fi
}

# Function to get the current version
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "00000000.0000"
    fi
}

# Function to update cron job based on config settings
update_cron() {
    load_config
    (sudo crontab -l 2>/dev/null | grep -v "$CORE_SCRIPT"; \
     if [ "$CRON_ACTIVE" == "1" ]; then \
        echo "*/$UPDATE_INTERVAL * * * * $CORE_SCRIPT"; \
        echo "@reboot $CORE_SCRIPT"; \
     fi) | sudo crontab -
    
    if [ "$CRON_ACTIVE" == "1" ]; then
        echo -e "✅ Cron job updated to run every ${GREEN}$UPDATE_INTERVAL${NC} minutes."
    else
        echo -e "❌ Cron job deactivated."
    fi
}

# Function to disable the cron job setting in config
disable_cron() {
    sudo sed -i "s|CRON_ACTIVE=1|CRON_ACTIVE=0|" "$CONFIG_FILE"
    update_cron
}

# Function to view log file
view_log() {
    echo -e "${YELLOW}--- Last 20 lines of Log File ---${NC}"
    sudo tail -n 20 /var/log/cfddns.log || echo -e "${YELLOW}Log file not found or empty.${NC}"
}

# Function to check for update and apply it
check_and_update() {
    local LOCAL_VERSION=$(get_current_version)
    echo -e "${YELLOW}Checking for updates on GitHub...${NC}"

    local REPO="https://raw.githubusercontent.com/nimabbz/cfddns/main"
    local LATEST_VERSION=$(curl -s "$REPO/VERSION.txt")
    
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${RED}ERROR: Could not fetch latest version from GitHub. Check network connection.${NC}"
        return
    fi
    
    echo -e "Local Version: ${YELLOW}$LOCAL_VERSION${NC}"
    echo -e "Latest Version: ${GREEN}$LATEST_VERSION${NC}"
    
    # Simple string comparison (for YYYYMMDD.HHMM format, this is sufficient)
    if [[ "$LOCAL_VERSION" < "$LATEST_VERSION" ]]; then
        echo -e "${GREEN}Update available! Applying changes...${NC}"
        
        # Applying updates: Re-run the core part of the installer for scripts
        sudo curl -s "$REPO/cfddns.sh" -o "$CORE_SCRIPT"
        sudo curl -s "$REPO/cfddns-cli.sh" -o "$CLI_SCRIPT"
        sudo curl -s "$REPO/VERSION.txt" -o "$VERSION_FILE" # Update version file
        
        # Clean and set permissions
        sudo dos2unix -q "$CORE_SCRIPT" "$CLI_SCRIPT"
        sudo chmod +x "$CORE_SCRIPT"
        sudo chmod +x "$CLI_SCRIPT"
        
        echo -e "${GREEN}Update complete! New version: $(get_current_version). Please restart cfddns.${NC}"
    elif [[ "$LOCAL_VERSION" == "$LATEST_VERSION" ]]; then
        echo -e "${GREEN}You are running the latest version: $LOCAL_VERSION${NC}"
    else
        echo -e "${YELLOW}Local version is newer than GitHub's. Potential issue or custom build.${NC}"
    fi
}

# Function to uninstall the script
uninstall_script() {
    echo -e "${RED}=====================================${NC}"
    echo -e "${RED} WARNING: This will permanently remove cfddns.${NC}"
    echo -e "${RED}=====================================${NC}"
    read -r -p "Are you sure you want to uninstall? (yes/no): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
        return
    fi

    echo "Removing cron job..."
    sudo crontab -l 2>/dev/null | grep -v 'cfddns' | sudo crontab -

    echo "Removing application files..."
    sudo rm -f /usr/local/bin/cfddns
    sudo rm -f /usr/local/bin/cfddns.sh

    echo "Removing config and log files..."
    sudo rm -rf /etc/cfddns
    sudo rm -f /var/log/cfddns.log

    echo -e "${GREEN}cfddns has been successfully uninstalled!${NC}"
    exit 0
}

# Function to display the main menu
# Function to display the main menu
show_menu() {
    load_config
    local CURRENT_VERSION=$(get_current_version) 
    
    if [ "$CRON_ACTIVE" == "1" ]; then
        STATUS_TEXT="${GREEN}ACTIVE${NC}"
    else
        STATUS_TEXT="${RED}INACTIVE${NC}"
    fi
    
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e "${YELLOW} Cloudflare Dynamic DNS Manager (cfddns) - v$CURRENT_VERSION${NC}" 
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e " ${GREEN}➔${NC} Current Domain:  ${CF_RECORD_NAME:-${RED}NOT SET${NC}}"
    echo -e " ${GREEN}➔${NC} Update Interval: ${UPDATE_INTERVAL:-5} minutes"
    echo -e " ${GREEN}➔${NC} Cron Status:     $STATUS_TEXT"
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e " ${YELLOW}1) ${NC}Run Check Manually (Test)"
    echo -e " ${YELLOW}2) ${NC}View Log File (${BLUE}/var/log/cfddns.log${NC})"
    echo -e " ${YELLOW}3) ${NC}Change Settings (API/ID/Interval/Toggle Cron/Proxy)"
    echo -e " ${YELLOW}4) ${NC}Check/Run Update (From GitHub)" # آپدیت
    echo -e " ${RED}5) ${NC}Uninstall Script (Permanently Remove)${NC}" # شیفت
    echo -e " ${YELLOW}6) ${NC}Exit" # شیفت
    echo -e "${BLUE}-------------------------------------${NC}"
}


# Function to handle settings changes
change_settings() {
    
    # Function to loop settings menu (Internal loop is required for easy multiple changes)
    settings_loop() {
        load_config
        
        # Determine current proxy status display
        PROXY_DISPLAY="${YELLOW}KEEP EXISTING${NC}"
        if [ "$CF_PROXY_STATUS" == "true" ]; then
            PROXY_DISPLAY="${GREEN}Proxied (True)${NC}"
        elif [ "$CF_PROXY_STATUS" == "false" ]; then
            PROXY_DISPLAY="${RED}DNS Only (False)${NC}"
        fi
        
        echo -e "\n${BLUE}-------------------------------------${NC}"
        echo -e "${YELLOW} Current Settings:${NC}"
        echo -e "${BLUE}-------------------------------------${NC}"
        echo -e " 1) CF Email: ${CF_EMAIL:-${RED}NOT SET${NC}}"
        echo -e " 2) CF API Key/Token: ${CF_API_KEY:-${RED}NOT SET${NC}}"
        echo -e " 3) CF Zone ID (Domain ID): ${CF_ZONE_ID:-${RED}NOT SET${NC}}"
        echo -e " 4) CF Record ID (A Record ID): ${CF_RECORD_ID:-${RED}NOT SET${NC}}"
        echo -e " 5) CF Record Name (Full Domain): ${CF_RECORD_NAME:-${RED}NOT SET${NC}}"
        echo -e " 6) Update Interval: ${UPDATE_INTERVAL:-5} min"
        echo -e " 7) Toggle Cron (${CRON_ACTIVE:-0})"
        echo -e " 8) Set Proxy Status (Current: $PROXY_DISPLAY)"
        echo -e " 9) Back to Main Menu"
        echo -e "${BLUE}-------------------------------------${NC}"

        read -r -p "Select setting to change (1-9): " choice

        # Function to confirm editing
        confirm_edit() {
            local setting_name=$1
            read -r -p "$(echo -e "${RED}Do you want to edit $setting_name? (yes/no): ${NC}")" confirmation
            if [[ "$confirmation" != "yes" ]]; then
                echo -e "${YELLOW}Edit cancelled.${NC}"
                return 1
            fi
            return 0
        }

        # Function to safely update the config file by replacing or appending
        update_config_key() {
            local key=$1
            local value=$2
            # Use sed to replace the existing line or append if not found
            if sudo grep -q "^$key=" "$CONFIG_FILE"; then
                sudo sed -i "s|^$key=.*|$key=\"$value\"|" "$CONFIG_FILE"
            else
                echo "$key=\"$value\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
            fi
        }

        case $choice in
            1)
                if confirm_edit "CF Email"; then
                    echo -e "${YELLOW}Hint: The email linked to your Cloudflare account.${NC}"
                    read -r -p "Enter new CF Email (e.g., user@domain.com): " new_value
                    update_config_key "CF_EMAIL" "$new_value"
                    echo -e "${GREEN}Email updated.${NC}"
                fi
                ;;
            2)
                if confirm_edit "CF API Key/Token"; then
                    echo -e "${YELLOW}Hint: Use an API Token (preferable) with Zone.DNS Edit permissions.${NC}"
                    read -r -p "Enter new CF API Key/Token (e.g., 6717d793...): " new_value
                    update_config_key "CF_API_KEY" "$new_value"
                    echo -e "${GREEN}API Key updated.${NC}"
                fi
                ;;
            3)
                if confirm_edit "CF Zone ID"; then
                    echo -e "${YELLOW}Hint: Found on your domain's Cloudflare dashboard summary page.${NC}"
                    read -r -p "Enter new CF Zone ID (e.g., 3f2c997f...): " new_value
                    update_config_key "CF_ZONE_ID" "$new_value"
                    echo -e "${GREEN}Zone ID updated.${NC}"
                fi
                ;;
            4)
                if confirm_edit "CF Record ID"; then
                    echo -e "${YELLOW}Hint: The unique ID of the specific A/AAAA record you want to update (e.g., your dynamic subdomain).${NC}"
                    read -r -p "Enter new CF Record ID (e.g., 5f59b24f...): " new_value
                    update_config_key "CF_RECORD_ID" "$new_value"
                    echo -e "${GREEN}Record ID updated.${NC}"
                fi
                ;;
            5)
                if confirm_edit "CF Record Name"; then
                    echo -e "${YELLOW}Hint: The full domain name of the record (e.g., ddns.example.com).${NC}"
                    read -r -p "Enter new CF Record Name (Domain) (e.g., sub.yourdomain.com): " new_value
                    update_config_key "CF_RECORD_NAME" "$new_value"
                    echo -e "${GREEN}Record Name updated.${NC}"
                fi
                ;;
            6)
                if confirm_edit "Update Interval"; then
                    read -r -p "Enter new Update Interval (minutes, e.g. 5): " new_value
                    if [[ "$new_value" =~ ^[0-9]+$ ]]; then
                        sudo sed -i "s|UPDATE_INTERVAL=.*|UPDATE_INTERVAL=$new_value|" "$CONFIG_FILE"
                        update_cron
                        echo -e "${GREEN}Interval updated and Cron Job rescheduled.${NC}"
                    else
                        echo -e "${RED}Invalid input. Please enter a number.${NC}"
                    fi
                fi
                ;;
            7)
                if [ "$CRON_ACTIVE" == "1" ]; then
                    disable_cron
                    echo -e "${YELLOW}Cron Job Disabled.${NC}"
                else
                    sudo sed -i "s|CRON_ACTIVE=0|CRON_ACTIVE=1|" "$CONFIG_FILE"
                    update_cron
                    echo -e "${GREEN}Cron Job Enabled.${NC}"
                fi
                ;;
            8) # Set Proxy Status
                echo -e "\n${RED}⚠️ WARNING: Changing Proxy Status ⚠️${NC}"
                echo "Changing the proxy status may disconnect your server if services are not correctly configured."
                echo "If access is lost, manually restore the Gray Cloud (DNS Only) setting on Cloudflare."

                read -r -p "Enter new Proxy Status (true/false/keep): " new_value
                
                # Validation and update
                case "$new_value" in
                    "true"|"false")
                        # Remove existing and set new value
                        sudo sed -i '/^CF_PROXY_STATUS=/d' "$CONFIG_FILE"
                        echo "CF_PROXY_STATUS=\"$new_value\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
                        echo -e "${GREEN}Proxy Status set to $new_value. Changes will apply on the next check.${NC}"
                        ;;
                    "keep")
                        # Remove the variable to make the core script KEEP the current setting
                        sudo sed -i '/^CF_PROXY_STATUS=/d' "$CONFIG_FILE"
                        echo -e "${YELLOW}Proxy Status set to KEEP EXISTING. The script will not modify the proxy setting.${NC}"
                        ;;
                    *)
                        echo -e "${RED}Invalid input. Please enter 'true', 'false', or 'keep'.${NC}"
                        ;;
                esac
                ;;
            9)
                return
                ;;
            *)
                echo -e "${RED}Invalid selection, please try again.${NC}"
                ;;
        esac
        settings_loop
    }

    settings_loop
}

# --- Command Handler ---
case "$1" in
    "update-cron")
        update_cron
        ;;
    "disable-cron")
        disable_cron
        ;;
    "update-ip") 
        $CORE_SCRIPT "MANUAL"
        ;;
    *) # Default behavior: Show menu, execute command, and loop back
        # The main interactive menu loop
        while true; do
            show_menu
            read -r -p "Select an option: " OPTION
            case $OPTION in
                1) $CORE_SCRIPT "MANUAL" ;;
                2) view_log ;;
                3) change_settings ;;
                4) check_and_update ;; 
                5) uninstall_script ;; 
                6) echo -e "${YELLOW}Exiting.${NC}"; break ;; 
                *) echo -e "${RED}Invalid selection, please try again.${NC}" ;;
            esac
            echo ""
        done
        ;;
esac