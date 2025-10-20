#!/usr/bin/env bash

CONFIG_FILE="/etc/cfddns/cfddns.conf"
CORE_SCRIPT="/usr/local/bin/cfddns.sh"

# Function to source the config file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
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
        echo "✅ Cron job updated to run every $UPDATE_INTERVAL minutes."
    else
        echo "❌ Cron job deactivated."
    fi
}


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
# (بخش میانی تابع show_menu)
        echo -e "${BLUE}-------------------------------------${NC}"
        echo -e " ${YELLOW}1) ${NC}Run Check Manually (Test)"
        echo -e " ${YELLOW}2) ${NC}View Log File (${BLUE}/var/log/cfddns.log${NC})"
        echo -e " ${YELLOW}3) ${NC}Change Settings (API/ID/Interval/Toggle Cron)"
        echo -e " ${RED}4) ${NC}Uninstall Script (Permanently Remove)${NC}" # New Option
        echo -e " ${YELLOW}5) ${NC}Exit"                                     # Moved to 5
        echo -e "${BLUE}-------------------------------------${NC}"
    }

# Function to handle settings changes (simplified for demonstration)
change_settings() {
    load_config

    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e "${YELLOW} Current Settings:${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e " 1) CF Email: ${CF_EMAIL:-NOT SET}"
    echo -e " 2) CF API Key: ${CF_API_KEY:-NOT SET}"
    echo -e " 3) CF Zone ID: ${CF_ZONE_ID:-NOT SET}"
    echo -e " 4) CF Record ID: ${CF_RECORD_ID:-NOT SET}"
    echo -e " 5) CF Record Name: ${CF_RECORD_NAME:-NOT SET}"
    echo -e " 6) Update Interval: ${UPDATE_INTERVAL:-5}"
    echo -e " 7) Toggle Cron (${CRON_ACTIVE:-0})"
    echo -e " 8) Back to Main Menu"
    echo -e "${BLUE}-------------------------------------${NC}"

    read -r -p "Select setting to change (1-8): " choice

    case $choice in
        1)
            read -r -p "Enter new CF Email: " new_value
            sudo sed -i "s|CF_EMAIL=\".*\"|CF_EMAIL=\"$new_value\"|" "$CONFIG_FILE"
            echo -e "${GREEN}Email updated.${NC}"
            ;;
        2)
            read -r -p "Enter new CF API Key/Token: " new_value
            sudo sed -i "s|CF_API_KEY=\".*\"|CF_API_KEY=\"$new_value\"|" "$CONFIG_FILE"
            echo -e "${GREEN}API Key updated.${NC}"
            ;;
        3)
            read -r -p "Enter new CF Zone ID: " new_value
            sudo sed -i "s|CF_ZONE_ID=\".*\"|CF_ZONE_ID=\"$new_value\"|" "$CONFIG_FILE"
            echo -e "${GREEN}Zone ID updated.${NC}"
            ;;
        4)
            read -r -p "Enter new CF Record ID: " new_value
            sudo sed -i "s|CF_RECORD_ID=\".*\"|CF_RECORD_ID=\"$new_value\"|" "$CONFIG_FILE"
            echo -e "${GREEN}Record ID updated.${NC}"
            ;;
        5)
            read -r -p "Enter new CF Record Name (Domain): " new_value
            sudo sed -i "s|CF_RECORD_NAME=\".*\"|CF_RECORD_NAME=\"$new_value\"|" "$CONFIG_FILE"
            echo -e "${GREEN}Record Name updated.${NC}"
            ;;
        6)
            read -r -p "Enter new Update Interval (minutes): " new_value
            if [[ "$new_value" =~ ^[0-9]+$ ]]; then
                sudo sed -i "s|UPDATE_INTERVAL=.*|UPDATE_INTERVAL=$new_value|" "$CONFIG_FILE"
                cfddns update-cron # Update cron job immediately
                echo -e "${GREEN}Interval updated and Cron Job rescheduled.${NC}"
            else
                echo -e "${RED}Invalid input. Please enter a number.${NC}"
            fi
            ;;
        7)
            if [ "$CRON_ACTIVE" == "1" ]; then
                cfddns disable-cron
                echo -e "${YELLOW}Cron Job Disabled.${NC}"
            else
                cfddns update-cron
                echo -e "${GREEN}Cron Job Enabled.${NC}"
            fi
            ;;
        8)
            return
            ;;
        *)
            echo -e "${RED}Invalid selection, please try again.${NC}"
            ;;
    esac

    # Show menu again after change
    change_settings 
}

# --- Command Handler ---
case "$1" in
    "update-cron")
        update_cron
        ;;
    *)
        while true; do
            show_menu
            read -r -p "Select an option: " OPTION
            # (بخش case در انتهای فایل)
			case $REPLY in
				1) cfddns update-ip ;;
				2) view_log ;;
				3) change_settings ;;
				4) uninstall_script ;; # Handle new Uninstall option
				5) exit 0 ;;            # Handle new Exit option
				*) echo -e "${RED}Invalid selection, please try again.${NC}" ;;
			esac
            echo ""
        done
        ;;
esac