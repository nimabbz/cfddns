#!/usr/bin/env bash

CONFIG_FILE="/etc/cfddns/cfddns.conf"
CORE_SCRIPT="/usr/local/bin/cfddns.sh"

# --- ANSI Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to source the config file
load_config() {
    # Ensure config file exists and is clean before sourcing
    if [ -f "$CONFIG_FILE" ]; then
        # Clean potential DOS line endings just in case
        dos2unix -q "$CONFIG_FILE"
        source "$CONFIG_FILE"
    fi
}

# Function to update cron job based on config settings
update_cron() {
    load_config
    # Create or update crontab entry
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
    update_cron # Remove cron lines by calling update_cron
}

# Function to view log file
view_log() {
    echo -e "${YELLOW}--- Last 20 lines of Log File ---${NC}"
    sudo tail -n 20 /var/log/cfddns.log || echo -e "${YELLOW}Log file not found or empty.${NC}"
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
    sudo crontab -l | grep -v 'cfddns' | sudo crontab -

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
show_menu() {
    load_config
    
    # Determine Status Colors
    if [ "$CRON_ACTIVE" == "1" ]; then
        STATUS_TEXT="${GREEN}ACTIVE${NC}"
    else
        STATUS_TEXT="${RED}INACTIVE${NC}"
    fi
    
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e "${YELLOW} Cloudflare Dynamic DNS Manager (cfddns)${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e " ${GREEN}➔${NC} Current Domain:  ${CF_RECORD_NAME:-${RED}NOT SET${NC}}"
    echo -e " ${GREEN}➔${NC} Update Interval: ${UPDATE_INTERVAL:-5} minutes"
    echo -e " ${GREEN}➔${NC} Cron Status:     $STATUS_TEXT"
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e " ${YELLOW}1) ${NC}Run Check Manually (Test)"
    echo -e " ${YELLOW}2) ${NC}View Log File (${BLUE}/var/log/cfddns.log${NC})"
    echo -e " ${YELLOW}3) ${NC}Change Settings (API/ID/Interval/Toggle Cron)"
    echo -e " ${RED}4) ${NC}Uninstall Script (Permanently Remove)${NC}"
    echo -e " ${YELLOW}5) ${NC}Exit"
    echo -e "${BLUE}-------------------------------------${NC}"
}

# Function to handle settings changes
change_settings() {
    load_config
    
    # Function to loop settings menu
    settings_loop() {
        load_config # 🌟 FIX: Reload config after any change
        
        echo -e "\n${BLUE}-------------------------------------${NC}"
        echo -e "${YELLOW} Current Settings:${NC}"
        echo -e "${BLUE}-------------------------------------${NC}"
        echo -e " 1) Cloudflare Email: ${CF_EMAIL:-${RED}NOT SET${NC}}"
        echo -e " 2) API Key/Token: ${CF_API_KEY:-${RED}NOT SET${NC}}"
        echo -e " 3) Zone ID (Domain ID): ${CF_ZONE_ID:-${RED}NOT SET${NC}}"
        echo -e " 4) Record ID (A Record ID): ${CF_RECORD_ID:-${RED}NOT SET${NC}}"
        echo -e " 5) Record Name (Full Domain): ${CF_RECORD_NAME:-${RED}NOT SET${NC}}"
        echo -e " 6) Update Interval: ${UPDATE_INTERVAL:-5} min"
        echo -e " 7) Toggle Cron (${CRON_ACTIVE:-0})"
        echo -e " 8) Back to Main Menu"
        echo -e "${BLUE}-------------------------------------${NC}"

        read -r -p "Select setting to change (1-8): " choice

        case $choice in
            1)
                echo -e "${YELLOW}Tip: This is the email linked to your Cloudflare account.${NC}"
                read -r -p "Enter new CF Email (e.g., user@domain.com): " new_value
                sudo sed -i "s|CF_EMAIL=\".*\"|CF_EMAIL=\"$new_value\"|" "$CONFIG_FILE"
                echo -e "${GREEN}Email updated.${NC}"
                ;;
            2)
                echo -e "${YELLOW}Tip: Use an API Token (preferable) or Global API Key.${NC}"
                echo -e "${YELLOW}Token must have Zone.DNS Edit permissions.${NC}"
                read -r -p "Enter new CF API Key/Token (e.g., 6717d793...): " new_value
                sudo sed -i "s|CF_API_KEY=\".*\"|CF_API_KEY=\"$new_value\"|" "$CONFIG_FILE"
                echo -e "${GREEN}API Key updated.${NC}"
                ;;
            3)
                echo -e "${YELLOW}Tip: Find this on your domain's Cloudflare dashboard summary page.${NC}"
                read -r -p "Enter new CF Zone ID (e.g., 3f2c997f...): " new_value
                sudo sed -i "s|CF_ZONE_ID=\".*\"|CF_ZONE_ID=\"$new_value\"|" "$CONFIG_FILE"
                echo -e "${GREEN}Zone ID updated.${NC}"
                ;;
            4)
                echo -e "${YELLOW}Tip: You need the unique ID of the specific A record you want to update (e.g., your dynamic subdomain).${NC}"
                echo -e "${YELLOW}You can get this ID using the Cloudflare API or by creating a placeholder record.${NC}"
                read -r -p "Enter new CF Record ID (e.g., 5f59b24f...): " new_value
                sudo sed -i "s|CF_RECORD_ID=\".*\"|CF_RECORD_ID=\"$new_value\"|" "$CONFIG_FILE"
                echo -e "${GREEN}Record ID updated.${NC}"
                ;;
            5)
                echo -e "${YELLOW}Tip: The full domain name of the record (e.g., ddns.example.com).${NC}"
                read -r -p "Enter new CF Record Name (Domain) (e.g., sub.yourdomain.com): " new_value
                sudo sed -i "s|CF_RECORD_NAME=\".*\"|CF_RECORD_NAME=\"$new_value\"|" "$CONFIG_FILE"
                echo -e "${GREEN}Record Name updated.${NC}"
                ;;
            6)
                read -r -p "Enter new Update Interval (minutes, e.g. 5): " new_value
                if [[ "$new_value" =~ ^[0-9]+$ ]]; then
                    sudo sed -i "s|UPDATE_INTERVAL=.*|UPDATE_INTERVAL=$new_value|" "$CONFIG_FILE"
                    update_cron # Update cron job immediately
                    echo -e "${GREEN}Interval updated and Cron Job rescheduled.${NC}"
                else
                    echo -e "${RED}Invalid input. Please enter a number.${NC}"
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
            8)
                return # Back to main menu
                ;;
            *)
                echo -e "${RED}Invalid selection, please try again.${NC}"
                ;;
        esac
        settings_loop # Loop back to show settings again
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
    "update-ip") # Command used by option 1 (Run Check Manually)
        $CORE_SCRIPT
        ;;
    *)
        while true; do
            show_menu
            read -r -p "Select an option: " OPTION
            case $OPTION in
                1) $CORE_SCRIPT ;;
                2) view_log ;;
                3) change_settings ;;
                4) uninstall_script ;;
                5) echo -e "${YELLOW}Exiting.${NC}"; exit 0 ;;
                *) echo -e "${RED}Invalid selection, please try again.${NC}" ;;
            esac
            echo ""
        done
        ;;
esac