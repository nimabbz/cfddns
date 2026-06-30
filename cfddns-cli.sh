#!/usr/bin/env bash

CONFIG_FILE="/etc/cfddns/cfddns.conf"
CORE_SCRIPT="/usr/local/bin/cfddns.sh"
VERSION="2026.Final"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

load_config() { if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; fi; }

update_cron() {
    load_config
    (sudo crontab -l 2>/dev/null | grep -v "$CORE_SCRIPT"; \
     if [ "$CRON_ACTIVE" == "1" ]; then echo "*/${UPDATE_INTERVAL:-5} * * * * $CORE_SCRIPT"; echo "@reboot $CORE_SCRIPT"; fi) | sudo crontab -
}

quick_setup() {
    echo -e "\n${CYAN}${BOLD}🚀 QUICK AUTO-SETUP WIZARD${NC}"
    read -r -p "1. Enter Cloudflare API Token: " API_TOKEN
    read -r -p "2. Enter Full Domain (e.g., g.ghand.shop): " DOMAIN
    if [ -z "$API_TOKEN" ] || [ -z "$DOMAIN" ]; then echo -e "${RED}❌ Missing info!${NC}"; sleep 2; return; fi

    echo -e "${YELLOW}🔍 Searching Cloudflare...${NC}"
    BASE_DOMAIN=$(echo "$DOMAIN" | awk -F. '{if (NF>2) print $(NF-1)"."$NF; else print $0}')
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN" -H "Authorization: Bearer $API_TOKEN" | jq -r '.result[0].id' 2>/dev/null)
    if [ "$ZONE_ID" == "null" ] || [ -z "$ZONE_ID" ]; then echo -e "${RED}❌ Zone ID not found! Check your Token.${NC}"; sleep 3; return; fi
    
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$DOMAIN" -H "Authorization: Bearer $API_TOKEN" | jq -r '.result[0].id' 2>/dev/null)
    if [ "$RECORD_ID" == "null" ] || [ -z "$RECORD_ID" ]; then echo -e "${RED}❌ Record ID not found! Ensure the A record exists.${NC}"; sleep 3; return; fi

    echo "CF_API_KEY=\"$API_TOKEN\"" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "CF_ZONE_ID=\"$ZONE_ID\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_RECORD_ID=\"$RECORD_ID\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_RECORD_NAME=\"$DOMAIN\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_PROXY_STATUS=\"false\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    if ! grep -q "UPDATE_INTERVAL" "$CONFIG_FILE"; then echo "UPDATE_INTERVAL=5" | sudo tee -a "$CONFIG_FILE" > /dev/null; fi
    if ! grep -q "CRON_ACTIVE" "$CONFIG_FILE"; then echo "CRON_ACTIVE=1" | sudo tee -a "$CONFIG_FILE" > /dev/null; fi
    
    update_cron
    echo -e "${GREEN}✅ Setup Complete!${NC}"; sleep 2
}

do_update() {
    echo -e "\n${YELLOW}⬇️ Downloading latest files from GitHub...${NC}"
    sudo curl -s "https://raw.githubusercontent.com/nimabbz/cfddns/main/cfddns.sh" -o "/usr/local/bin/cfddns.sh"
    sudo curl -s "https://raw.githubusercontent.com/nimabbz/cfddns/main/cfddns-cli.sh" -o "/usr/local/bin/cfddns"
    sudo chmod +x /usr/local/bin/cfddns.sh /usr/local/bin/cfddns
    echo -e "${GREEN}✅ Update successful! Please restart cfddns.${NC}"
    exit 0
}

show_menu() {
    load_config
    clear
    echo -e "${CYAN}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}         ☁️ CLOUDFLARE DDNS MANAGER          ${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                   v$VERSION                       ${CYAN}│${NC}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────╯${NC}"

    if [ -n "$CF_ZONE_ID" ] && [ -n "$CF_API_KEY" ]; then
        SERVER_IP=$(curl -s --max-time 3 https://api.ipify.org)
        CF_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" -H "Authorization: Bearer $CF_API_KEY" --max-time 3 | jq -r '.result.content' 2>/dev/null)
        
        echo -e " 🌐 ${BOLD}Domain:${NC}     $CF_RECORD_NAME"
        echo -e " 🖥️  ${BOLD}Server IP:${NC}  $SERVER_IP"
        echo -e " ☁️  ${BOLD}CF IP:${NC}      ${CF_IP:-${RED}Not Found${NC}}"
        if [ "$SERVER_IP" == "$CF_IP" ] && [ -n "$SERVER_IP" ]; then
            echo -e " ⚡ ${BOLD}Status:${NC}     ${GREEN}[ ✅ SYNCED ]${NC}"
        else
            echo -e " ⚡ ${BOLD}Status:${NC}     ${RED}[ ❌ OUT OF SYNC ]${NC}"
        fi
    else
        echo -e " ⚡ ${BOLD}Status:${NC}     ${RED}[ ⚠️ NOT CONFIGURED ]${NC}"
    fi
    
    if [ "$CRON_ACTIVE" == "1" ]; then CR_TXT="${GREEN}ACTIVE${NC}"; else CR_TXT="${RED}INACTIVE${NC}"; fi
    echo -e " ⏱️  ${BOLD}Cron Job:${NC}   [$CR_TXT] (Every ${UPDATE_INTERVAL:-5}m)"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}1)${NC} 🚀 Quick Auto-Setup Wizard"
    echo -e "  ${BOLD}2)${NC} ⚙️  Manual Settings (nano)"
    echo -e "  ${BOLD}3)${NC} 🔍 Run Manual Check"
    echo -e "  ${BOLD}4)${NC} 📄 View Logs"
    echo -e "  ${BOLD}5)${NC} ⬇️  Update from GitHub"
    echo -e "  ${RED}${BOLD}0) 🚪 Exit${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
}

while true; do
    show_menu
    read -r -p "Select an option: " OPTION
    case $OPTION in
        1) quick_setup ;;
        2) sudo nano "$CONFIG_FILE" ;;
        3) echo -e "\n${YELLOW}🔍 Running manual check...${NC}"; sudo bash "$CORE_SCRIPT" "MANUAL"; echo -e "${GREEN}✅ Done! Check logs (Option 4).${NC}"; sleep 2 ;;
        4) echo -e "\n${YELLOW}📄 --- Last 15 Logs ---${NC}"; sudo tail -n 15 /var/log/cfddns.log; echo ""; read -r -p "Press Enter to return..." ;;
        5) do_update ;;
        0) clear; break ;;
    esac
done