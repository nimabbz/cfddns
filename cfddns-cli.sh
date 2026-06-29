sudo tee /usr/local/bin/cfddns-cli.sh << 'EOF'
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

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        dos2unix -q "$CONFIG_FILE" 2>/dev/null
        source "$CONFIG_FILE"
    fi
}

get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "00000000.0000"
    fi
}

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

disable_cron() {
    sudo sed -i "s|CRON_ACTIVE=1|CRON_ACTIVE=0|" "$CONFIG_FILE"
    update_cron
}

view_log() {
    echo -e "${YELLOW}--- Last 20 lines of Log File ---${NC}"
    sudo tail -n 20 /var/log/cfddns.log || echo -e "${YELLOW}Log file not found or empty.${NC}"
}

check_and_update() {
    local LOCAL_VERSION=$(get_current_version)
    echo -e "${YELLOW}Checking for updates on GitHub...${NC}"
    local REPO="https://raw.githubusercontent.com/nimabbz/cfddns/main"
    local LATEST_VERSION=$(curl -s "$REPO/VERSION.txt")
    
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${RED}ERROR: Could not fetch latest version from GitHub.${NC}"
        return
    fi
    
    echo -e "Local Version: ${YELLOW}$LOCAL_VERSION${NC}"
    echo -e "Latest Version: ${GREEN}$LATEST_VERSION${NC}"
    
    if [[ "$LOCAL_VERSION" < "$LATEST_VERSION" ]]; then
        echo -e "${GREEN}Update available! Applying changes...${NC}"
        sudo curl -s "$REPO/cfddns.sh" -o "$CORE_SCRIPT"
        sudo curl -s "$REPO/cfddns-cli.sh" -o "$CLI_SCRIPT"
        sudo curl -s "$REPO/VERSION.txt" -o "$VERSION_FILE"
        sudo dos2unix -q "$CORE_SCRIPT" "$CLI_SCRIPT"
        sudo chmod +x "$CORE_SCRIPT"
        sudo chmod +x "$CLI_SCRIPT"
        echo -e "${GREEN}Update complete!${NC}"
    elif [[ "$LOCAL_VERSION" == "$LATEST_VERSION" ]]; then
        echo -e "${GREEN}You are running the latest version.${NC}"
    fi
}

uninstall_script() {
    read -r -p "Are you sure you want to uninstall? (yes/no): " confirmation
    if [[ "$confirmation" == "yes" ]]; then
        sudo crontab -l 2>/dev/null | grep -v 'cfddns' | sudo crontab -
        sudo rm -f /usr/local/bin/cfddns /usr/local/bin/cfddns.sh
        sudo rm -rf /etc/cfddns /var/log/cfddns.log
        echo -e "${GREEN}cfddns uninstalled successfully.${NC}"
        exit 0
    fi
}

show_menu() {
    load_config
    local CURRENT_VERSION=$(get_current_version) 
    if [ "$CRON_ACTIVE" == "1" ]; then STATUS_TEXT="${GREEN}ACTIVE${NC}"; else STATUS_TEXT="${RED}INACTIVE${NC}"; fi
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
    echo -e " ${YELLOW}4) ${NC}Check/Run Update (From GitHub)"
    echo -e " ${RED}5) ${NC}Uninstall Script (Permanently Remove)${NC}"
    echo -e " ${YELLOW}6) ${NC}Exit"
    echo -e "${BLUE}-------------------------------------${NC}"
}

change_settings() {
    settings_loop() {
        load_config
        PROXY_DISPLAY="${RED}DNS Only (False) [Default]${NC}"
        if [ "$CF_PROXY_STATUS" == "true" ]; then PROXY_DISPLAY="${GREEN}Proxied (True)${NC}"
        elif [ "$CF_PROXY_STATUS" == "false" ]; then PROXY_DISPLAY="${RED}DNS Only (False)${NC}"; fi
        
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

        confirm_edit() {
            read -r -p "$(echo -e "${RED}Do you want to edit $1? (yes/no): ${NC}")" confirmation
            if [[ "$confirmation" != "yes" ]]; then return 1; fi; return 0
        }

        update_config_key() {
            local key=$1; local value=$2
            if sudo grep -q "^$key=" "$CONFIG_FILE"; then
                sudo sed -i "s|^$key=.*|$key=\"$value\"|" "$CONFIG_FILE"
            else
                echo "$key=\"$value\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
            fi
        }

        case $choice in
            1) if confirm_edit "CF Email"; then read -r -p "Enter new CF Email: " nv; update_config_key "CF_EMAIL" "$nv"; fi ;;
            2) if confirm_edit "CF API Key/Token"; then read -r -p "Enter new CF API Key/Token: " nv; update_config_key "CF_API_KEY" "$nv"; fi ;;
            3) if confirm_edit "CF Zone ID"; then read -r -p "Enter new CF Zone ID: " nv; update_config_key "CF_ZONE_ID" "$nv"; fi ;;
            4) if confirm_edit "CF Record ID"; then
                   echo -e "${YELLOW}Type 'auto' to fetch automatically from Cloudflare, or press Enter to type manually.${NC}"
                   read -r -p "Selection: " mode
                   if [ "$mode" == "auto" ]; then
                       if [ -z "$CF_ZONE_ID" ] || [ -z "$CF_API_KEY" ] || [ -z "$CF_RECORD_NAME" ]; then
                           echo -e "${RED}ERROR: Please set API Key, Zone ID, and Record Name first!${NC}"
                       else
                           echo -e "${YELLOW}Fetching Record ID automatically...${NC}"
                           local FID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$CF_RECORD_NAME" \
                                -H "Authorization: Bearer $CF_API_KEY" \
                                -H "Content-Type: application/json" | jq -r '.result[0].id' 2>/dev/null)
                           if [ "$FID" != "null" ] && [ ! -z "$FID" ]; then
                               update_config_key "CF_RECORD_ID" "$FID"
                               echo -e "${GREEN}Successfully found and updated Record ID: $FID${NC}"
                           else
                               echo -e "${RED}Failed to fetch automatically. Make sure the record exists in Cloudflare.${NC}"
                           fi
                       fi
                   else
                       read -r -p "Enter CF Record ID manually: " nv
                       if [ ! -z "$nv" ]; then update_config_key "CF_RECORD_ID" "$nv"; fi
                   fi
               fi ;;
            5) if confirm_edit "CF Record Name"; then read -r -p "Enter new CF Record Name (Domain): " nv; update_config_key "CF_RECORD_NAME" "$nv"; fi ;;
            6) if confirm_edit "Update Interval"; then read -r -p "Enter new Update Interval (minutes): " nv;
                   if [[ "$nv" =~ ^[0-9]+$ ]]; then sudo sed -i "s|UPDATE_INTERVAL=.*|UPDATE_INTERVAL=$nv|" "$CONFIG_FILE"; update_cron; fi; fi ;;
            7) if [ "$CRON_ACTIVE" == "1" ]; then disable_cron; else sudo sed -i "s|CRON_ACTIVE=0|CRON_ACTIVE=1|" "$CONFIG_FILE"; update_cron; fi ;;
            8) echo -e "\n${RED}⚠️ Changing Proxy Status ⚠️${NC}"
               read -r -p "Enter new Proxy Status (true/false/keep): " nv
               case "$nv" in
                   "true"|"false") sudo sed -i '/^CF_PROXY_STATUS=/d' "$CONFIG_FILE"; echo "CF_PROXY_STATUS=\"$nv\"" | sudo tee -a "$CONFIG_FILE" > /dev/null ;;
                   "keep") sudo sed -i '/^CF_PROXY_STATUS=/d' "$CONFIG_FILE" ;;
               esac ;;
            9) return ;;
        esac
        settings_loop
    }
    settings_loop
}

case "$1" in
    "update-cron") update_cron ;;
    "disable-cron") disable_cron ;;
    "update-ip") $CORE_SCRIPT "MANUAL" ;;
    *) while true; do show_menu; read -r -p "Select an option: " OPTION
          case $OPTION in
              1) $CORE_SCRIPT "MANUAL" ;;
              2) view_log ;;
              3) change_settings ;;
              4) check_and_update ;; 
              5) uninstall_script ;; 
              6) break ;;
          esac
          echo ""
       done ;;
esac
EOF
sudo chmod +x /usr/local/bin/cfddns-cli.sh