sudo tee /usr/local/bin/cfddns << 'EOF'
#!/usr/bin/env bash

CONFIG_DIR="/etc/cfddns"
CONFIG_FILE="$CONFIG_DIR/cfddns.conf"
CORE_SCRIPT="/usr/local/bin/cfddns.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

load_config() { if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; fi; }

update_cron() {
    load_config
    (sudo crontab -l 2>/dev/null | grep -v "$CORE_SCRIPT"; \
     if [ "$CRON_ACTIVE" == "1" ]; then echo "*/${UPDATE_INTERVAL:-5} * * * * $CORE_SCRIPT"; echo "@reboot $CORE_SCRIPT"; fi) | sudo crontab -
}

quick_setup_wizard() {
    echo -e "\n${CYAN}=== ⚡ Quick Auto-Setup Wizard ===${NC}"
    echo -e "This wizard will automatically find your IDs and configure everything."
    
    read -r -p "1. Enter your Cloudflare API Token: " API_TOKEN
    if [ -z "$API_TOKEN" ]; then echo -e "${RED}Token cannot be empty.${NC}"; sleep 2; return; fi
    
    read -r -p "2. Enter your Full Domain Name (e.g. sub.domain.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then echo -e "${RED}Domain cannot be empty.${NC}"; sleep 2; return; fi

    echo -e "${YELLOW}🔍 Searching Cloudflare for your domain...${NC}"
    BASE_DOMAIN=$(echo "$DOMAIN" | awk -F. '{if (NF>2) print $(NF-1)"."$NF; else print $0}')
    
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN" -H "Authorization: Bearer $API_TOKEN" | jq -r '.result[0].id' 2>/dev/null)
    if [ "$ZONE_ID" == "null" ] || [ -z "$ZONE_ID" ]; then echo -e "${RED}❌ Error: Could not find Zone ID. Check your Token.${NC}"; sleep 3; return; fi
    echo -e "${GREEN}✅ Found Zone ID: $ZONE_ID${NC}"

    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$DOMAIN" -H "Authorization: Bearer $API_TOKEN" | jq -r '.result[0].id' 2>/dev/null)
    if [ "$RECORD_ID" == "null" ] || [ -z "$RECORD_ID" ]; then echo -e "${RED}❌ Error: Record ID not found. Ensure the A record exists in Cloudflare!${NC}"; sleep 3; return; fi
    echo -e "${GREEN}✅ Found Record ID: $RECORD_ID${NC}"

    echo "CF_API_KEY=\"$API_TOKEN\"" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "CF_ZONE_ID=\"$ZONE_ID\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_RECORD_ID=\"$RECORD_ID\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_RECORD_NAME=\"$DOMAIN\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_PROXY_STATUS=\"false\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    if ! grep -q "UPDATE_INTERVAL" "$CONFIG_FILE"; then echo "UPDATE_INTERVAL=5" | sudo tee -a "$CONFIG_FILE" > /dev/null; fi
    if ! grep -q "CRON_ACTIVE" "$CONFIG_FILE"; then echo "CRON_ACTIVE=1" | sudo tee -a "$CONFIG_FILE" > /dev/null; fi
    
    update_cron
    echo -e "\n${GREEN}🎉 Setup Complete! Your DDNS is now fully configured and active!${NC}"
    sleep 3
}

show_menu() {
    load_config
    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}  Cloudflare DDNS Manager (Live Status)  ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    
    if [ -n "$CF_ZONE_ID" ] && [ -n "$CF_API_KEY" ] && [ -n "$CF_RECORD_NAME" ]; then
        SERVER_IP=$(curl -s --max-time 3 https://api.ipify.org)
        CF_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" -H "Authorization: Bearer $CF_API_KEY" --max-time 3 | jq -r '.result.content' 2>/dev/null)
        
        echo -e " 🌐 Domain:     ${CYAN}$CF_RECORD_NAME${NC}"
        echo -e " 🖥️  Server IP:  $SERVER_IP"
        echo -e " ☁️  CF IP:      ${CF_IP:-${RED}Not Found${NC}}"
        
        if [ "$SERVER_IP" == "$CF_IP" ] && [ -n "$SERVER_IP" ]; then
            echo -e " ⚡ Status:     ${GREEN}SYNCED ✅${NC}"
        else
            echo -e " ⚡ Status:     ${RED}OUT OF SYNC ❌${NC}"
        fi
    else
        echo -e " ⚡ Status:     ${RED}NOT CONFIGURED YET${NC}"
    fi
    
    if [ "$CRON_ACTIVE" == "1" ]; then CRON_TXT="${GREEN}ACTIVE${NC}"; else CRON_TXT="${RED}INACTIVE${NC}"; fi
    echo -e " ⏱️  Cron Job:   $CRON_TXT (Every ${UPDATE_INTERVAL:-5}m)"
    echo -e "${BLUE}=========================================${NC}"
    echo -e " ${CYAN}0) ⚡ Quick Auto-Setup Wizard (Recommended)${NC}"
    echo -e " ${YELLOW}1) ${NC}Run Check Manually (Test)"
    echo -e " ${YELLOW}2) ${NC}View Human-Readable Logs"
    echo -e " ${RED}3) ${NC}Uninstall Script"
    echo -e " ${YELLOW}4) ${NC}Exit"
    echo -e "${BLUE}=========================================${NC}"
}

while true; do
    show_menu
    read -r -p "Select an option: " OPTION
    case $OPTION in
        0) quick_setup_wizard ;;
        1) echo -e "${YELLOW}Running check...${NC}"; $CORE_SCRIPT "MANUAL"; sleep 2 ;;
        2) echo -e "${YELLOW}--- Last Logs ---${NC}"; sudo tail -n 15 /var/log/cfddns.log; read -r -p "Press Enter to return..." ;;
        3) read -r -p "Are you sure you want to uninstall? (yes/no): " c
           if [[ "$c" == "yes" ]]; then sudo crontab -l 2>/dev/null | grep -v 'cfddns' | sudo crontab -; sudo rm -f /usr/local/bin/cfddns*; sudo rm -rf /etc/cfddns /var/log/cfddns.log; echo -e "${GREEN}Uninstalled!${NC}"; exit 0; fi ;;
        4) clear; break ;;
    esac
done
EOF
sudo chmod +x /usr/local/bin/cfddns