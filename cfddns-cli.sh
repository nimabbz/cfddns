sudo tee /usr/local/bin/cfddns << 'EOF'
#!/usr/bin/env bash

CONFIG_DIR="/etc/cfddns"
CONFIG_FILE="$CONFIG_DIR/cfddns.conf"
VERSION_FILE="$CONFIG_DIR/VERSION.txt"
CORE_SCRIPT="/usr/local/bin/cfddns.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

load_config() { if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; fi; }
get_version() { if [ -f "$VERSION_FILE" ]; then cat "$VERSION_FILE"; else echo "2026.Live"; fi; }

update_cron() {
    load_config
    (sudo crontab -l 2>/dev/null | grep -v "$CORE_SCRIPT"; \
     if [ "$CRON_ACTIVE" == "1" ]; then echo "*/${UPDATE_INTERVAL:-5} * * * * $CORE_SCRIPT"; echo "@reboot $CORE_SCRIPT"; fi) | sudo crontab -
}

quick_setup_wizard() {
    echo -e "\n${CYAN}${BOLD}=== QUICK AUTO-SETUP WIZARD ===${NC}"
    echo -e "${YELLOW}WARNING: This will overwrite your current configuration.${NC}"
    read -r -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi
    
    read -r -p "1. Enter your Cloudflare API Token: " API_TOKEN
    read -r -p "2. Enter your Full Domain Name (e.g., panel.domain.com): " DOMAIN
    if [ -z "$API_TOKEN" ] || [ -z "$DOMAIN" ]; then echo -e "${RED}Information is incomplete. Aborting.${NC}"; sleep 2; return; fi

    echo -e "${YELLOW}Searching Cloudflare...${NC}"
    BASE_DOMAIN=$(echo "$DOMAIN" | awk -F. '{if (NF>2) print $(NF-1)"."$NF; else print $0}')
    
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN" -H "Authorization: Bearer $API_TOKEN" | jq -r '.result[0].id' 2>/dev/null)
    if [ "$ZONE_ID" == "null" ] || [ -z "$ZONE_ID" ]; then echo -e "${RED}Error: Zone ID not found. Check your API Token.${NC}"; sleep 3; return; fi
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$DOMAIN" -H "Authorization: Bearer $API_TOKEN" | jq -r '.result[0].id' 2>/dev/null)
    
    if [ "$RECORD_ID" == "null" ] || [ -z "$RECORD_ID" ]; then echo -e "${RED}Error: Record ID not found. Ensure the record exists in Cloudflare.${NC}"; sleep 3; return; fi

    echo "CF_API_KEY=\"$API_TOKEN\"" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "CF_ZONE_ID=\"$ZONE_ID\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_RECORD_ID=\"$RECORD_ID\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_RECORD_NAME=\"$DOMAIN\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_PROXY_STATUS=\"false\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    if ! grep -q "UPDATE_INTERVAL" "$CONFIG_FILE"; then echo "UPDATE_INTERVAL=5" | sudo tee -a "$CONFIG_FILE" > /dev/null; fi
    if ! grep -q "CRON_ACTIVE" "$CONFIG_FILE"; then echo "CRON_ACTIVE=1" | sudo tee -a "$CONFIG_FILE" > /dev/null; fi
    update_cron
    echo -e "\n${GREEN}Setup completed successfully!${NC}"
    sleep 2
}

view_settings() {
    load_config
    echo -e "\n${CYAN}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│               CURRENT SETTINGS                   │${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────╯${NC}"
    echo -e " 1) API Token: ${CF_API_KEY:-${RED}NOT SET${NC}}"
    echo -e " 2) Zone ID:   ${CF_ZONE_ID:-${RED}NOT SET${NC}}"
    echo -e " 3) Record ID: ${CF_RECORD_ID:-${RED}NOT SET${NC}}"
    echo -e " 4) Domain:    ${CF_RECORD_NAME:-${RED}NOT SET${NC}}"
    echo -e " 5) Interval:  ${UPDATE_INTERVAL:-5} min"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
    read -r -p "Select a number to edit (or press Enter to go back): " choice
    if [ -n "$choice" ]; then
        case $choice in
            1) read -r -p "New Token: " nv; sudo sed -i "s|^CF_API_KEY=.*|CF_API_KEY=\"$nv\"|" "$CONFIG_FILE" ;;
            2) read -r -p "New Zone ID: " nv; sudo sed -i "s|^CF_ZONE_ID=.*|CF_ZONE_ID=\"$nv\"|" "$CONFIG_FILE" ;;
            3) read -r -p "New Record ID: " nv; sudo sed -i "s|^CF_RECORD_ID=.*|CF_RECORD_ID=\"$nv\"|" "$CONFIG_FILE" ;;
            4) read -r -p "New Domain: " nv; sudo sed -i "s|^CF_RECORD_NAME=.*|CF_RECORD_NAME=\"$nv\"|" "$CONFIG_FILE" ;;
            5) read -r -p "New Interval: " nv; sudo sed -i "s|^UPDATE_INTERVAL=.*|UPDATE_INTERVAL=$nv|" "$CONFIG_FILE"; update_cron ;;
        esac
    fi
}

check_update() {
    echo -e "${YELLOW}Checking for updates from GitHub...${NC}"
    sudo curl -s "https://raw.githubusercontent.com/nimabbz/cfddns/main/cfddns.sh" -o "/usr/local/bin/cfddns.sh"
    sudo curl -s "https://raw.githubusercontent.com/nimabbz/cfddns/main/cfddns-cli.sh" -o "/usr/local/bin/cfddns"
    sudo chmod +x /usr/local/bin/cfddns.sh /usr/local/bin/cfddns
    echo -e "${GREEN}Update completed! Please restart the script.${NC}"
    exit 0
}

show_menu() {
    load_config
    clear
    echo -e "${CYAN}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│             CLOUDFLARE DDNS MANAGER              │${NC}"
    echo -e "${CYAN}│                   v$(get_version)                     │${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────╯${NC}"
    
    if [ -n "$CF_ZONE_ID" ] && [ -n "$CF_API_KEY" ] && [ -n "$CF_RECORD_NAME" ]; then
        SERVER_IP=$(curl -s --max-time 3 https://api.ipify.org)
        CF_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" -H "Authorization: Bearer $CF_API_KEY" --max-time 3 | jq -r '.result.content' 2>/dev/null)
        
        echo -e " ${BOLD}Domain:${NC}     $CF_RECORD_NAME"
        echo -e " ${BOLD}Server IP:${NC}  $SERVER_IP"
        echo -e " ${BOLD}CF IP:${NC}      ${CF_IP:-${RED}Not Found${NC}}"
        if [ "$SERVER_IP" == "$CF_IP" ] && [ -n "$SERVER_IP" ]; then 
            echo -e " ${BOLD}Status:${NC}     ${GREEN}[ SYNCED ]${NC}"
        else 
            echo -e " ${BOLD}Status:${NC}     ${RED}[ OUT OF SYNC ]${NC}"
        fi
    else
        echo -e " ${BOLD}Status:${NC}     ${RED}[ NOT CONFIGURED ]${NC}"
    fi
    
    if [ "$CRON_ACTIVE" == "1" ]; then CRON_TXT="${GREEN}ACTIVE${NC}"; else CRON_TXT="${RED}INACTIVE${NC}"; fi
    echo -e " ${BOLD}Cron Job:${NC}   [$CRON_TXT] (Every ${UPDATE_INTERVAL:-5}m)"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}1)${NC} Quick Auto-Setup Wizard"
    echo -e "  ${BOLD}2)${NC} View / Edit Current Settings"
    echo -e "  ${BOLD}3)${NC} Run Check Manually (Test)"
    echo -e "  ${BOLD}4)${NC} View Logs"
    echo -e "  ${BOLD}5)${NC} Update from GitHub"
    echo -e "  ${BOLD}6)${NC} Uninstall Script"
    echo -e "  ${RED}${BOLD}0) Exit${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
}

while true; do
    show_menu
    read -r -p "Select an option: " OPTION
    case $OPTION in
        1) quick_setup_wizard ;;
        2) view_settings ;;
        3) echo -e "${YELLOW}Running check...${NC}"; $CORE_SCRIPT "MANUAL"; sleep 2 ;;
        4) echo -e "${YELLOW}--- Last Logs ---${NC}"; sudo tail -n 15 /var/log/cfddns.log; read -r -p "Press Enter to return..." ;;
        5) check_update ;;
        6) read -r -p "Are you sure you want to uninstall? (y/n): " c; if [[ "$c" == "y" ]]; then sudo crontab -l 2>/dev/null | grep -v 'cfddns' | sudo crontab -; sudo rm -rf /usr/local/bin/cfddns* /etc/cfddns /var/log/cfddns.log; echo "Uninstalled successfully!"; exit 0; fi ;;
        0) clear; break ;;
    esac
done
EOF
sudo chmod +x /usr/local/bin/cfddns