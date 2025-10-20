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

# Function to display the main menu
show_menu() {
    load_config
    echo "-------------------------------------"
    echo " Cloudflare Dynamic DNS Manager (cfddns)"
    echo "-------------------------------------"
    echo "Current Domain: $CF_RECORD_NAME"
    echo "Update Interval: $UPDATE_INTERVAL minutes"
    echo "Cron Status: $([ "$CRON_ACTIVE" == "1" ] && echo "ACTIVE" || echo "INACTIVE")"
    echo "-------------------------------------"
    echo "1) Run Check Manually (Test)"
    echo "2) View Log File (/var/log/cfddns.log)"
    echo "3) Change Settings (Domain/API/Interval/Toggle Cron)"
    echo "4) Exit"
    echo "-------------------------------------"
}

# Function to handle settings changes (simplified for demonstration)
change_settings() {
    echo "--- Change Settings ---"
    # In a real script, you'd use 'read' to prompt the user and sed to edit $CONFIG_FILE
    echo "For full control, please edit $CONFIG_FILE directly as root."
    echo "You can change API keys, RECORD_NAME, UPDATE_INTERVAL, and CRON_ACTIVE."
    echo "After editing, run 'cfddns update-cron' to apply changes."
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
            case "$OPTION" in
                1)
                    echo "Running manual check..."
                    $CORE_SCRIPT
                    ;;
                2)
                    sudo tail -n 20 /var/log/cfddns.log || echo "Log file not found or empty."
                    ;;
                3)
                    change_settings
                    ;;
                4)
                    echo "Exiting."
                    exit 0
                    ;;
                *)
                    echo "Invalid option."
                    ;;
            esac
            echo ""
        done
        ;;
esac