sudo tee /usr/local/bin/cfddns << 'EOF'
#!/usr/bin/env bash

CONFIG_DIR="/etc/cfddns"
CONFIG_FILE="$CONFIG_DIR/cfddns.conf"
VERSION_FILE="$CONFIG_DIR/VERSION.txt"
CORE_SCRIPT="/usr/local/bin/cfddns.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

load_config() { if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; fi; }
get_version() { if [ -f "$VERSION_FILE" ]; then cat "$VERSION_FILE"; else echo "2026.Live"; fi; }

update_cron() {
    load_config
    (sudo crontab -l 2>/dev/null | grep -v "$CORE_SCRIPT"; \
     if [ "$CRON_ACTIVE" == "1" ]; then echo "*/${UPDATE_INTERVAL:-5} * * * * $CORE_SCRIPT"; echo "@reboot $CORE_SCRIPT"; fi) | sudo crontab -
}

quick_setup_wizard() {
    echo -e "\n${CYAN}=== ⚡ Quick Auto-Setup Wizard ===${NC}"
    echo -e "${RED}⚠️ هشدار: این ویزارد تنظیمات قبلی شما را پاک و بازنویسی می‌کند.${NC}"
    read -r -p "آیا می‌خواهید ادامه دهید؟ (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi
    
    read -r -p "1. Enter your Cloudflare API Token: " API_TOKEN
    read -r -p "2. Enter your Full Domain Name (e.g. sub.domain.com): " DOMAIN
    if [ -z "$API_TOKEN" ] || [ -z "$DOMAIN" ]; then echo -e "${RED}اطلاعات ناقص است.${NC}"; sleep 2; return; fi

    echo -e "${YELLOW}🔍 در حال جستجو در کلودفلر...${NC}"
    BASE_DOMAIN=$(echo "$DOMAIN" | awk -F. '{if (NF>2) print $(NF-1)"."$NF; else print $0}')
    
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN" -H "Authorization: Bearer $API_TOKEN" | jq -r '.result[0].id' 2>/dev/null)
    if [ "$ZONE_ID" == "null" ] || [ -z "$ZONE_ID" ]; then echo -e "${RED}❌ شناسه دامنه پیدا نشد.${NC}"; sleep 3; return; fi
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$DOMAIN" -H "Authorization: Bearer $API_TOKEN" | jq -r '.result[0].id' 2>/dev/null)
    
    if [ "$RECORD_ID" == "null" ] || [ -z "$RECORD_ID" ]; then echo -e "${RED}❌ رکورد پیدا نشد.${NC}"; sleep 3; return; fi

    echo "CF_API_KEY=\"$API_TOKEN\"" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "CF_ZONE_ID=\"$ZONE_ID\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_RECORD_ID=\"$RECORD_ID\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_RECORD_NAME=\"$DOMAIN\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "CF_PROXY_STATUS=\"false\"" | sudo tee -a "$CONFIG_FILE" > /dev/null
    if ! grep -q "UPDATE_INTERVAL" "$CONFIG_FILE"; then echo "UPDATE_INTERVAL=5" | sudo tee -a "$CONFIG_FILE" > /dev/null; fi
    if ! grep -q "CRON_ACTIVE" "$CONFIG_FILE"; then echo "CRON_ACTIVE=1" | sudo tee -a "$CONFIG_FILE" > /dev/null; fi
    update_cron
    echo -e "\n${GREEN}🎉 راه‌اندازی با موفقیت تمام شد!${NC}"
    sleep 2
}

view_settings() {
    load_config
    echo -e "\n${BLUE}=========================================${NC}"
    echo -e "${YELLOW} تنظیمات فعلی شما (Current Settings) ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e " 1) API Token: ${CF_API_KEY:-${RED}NOT SET${NC}}"
    echo -e " 2) Zone ID:   ${CF_ZONE_ID:-${RED}NOT SET${NC}}"
    echo -e " 3) Record ID: ${CF_RECORD_ID:-${RED}NOT SET${NC}}"
    echo -e " 4) Domain:    ${CF_RECORD_NAME:-${RED}NOT SET${NC}}"
    echo -e " 5) Interval:  ${UPDATE_INTERVAL:-5} min"
    echo -e "${BLUE}=========================================${NC}"
    read -r -p "شماره موردی که می‌خواهید ویرایش کنید را بزنید (یا Enter برای خروج): " choice
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
    echo -e "${YELLOW}در حال بررسی آپدیت از گیت‌هاب...${NC}"
    sudo curl -s "https://raw.githubusercontent.com/nimabbz/cfddns/main/cfddns.sh" -o "/usr/local/bin/cfddns.sh"
    sudo curl -s "https://raw.githubusercontent.com/nimabbz/cfddns/main/cfddns-cli.sh" -o "/usr/local/bin/cfddns"
    sudo chmod +x /usr/local/bin/cfddns.sh /usr/local/bin/cfddns
    echo -e "${GREEN}آپدیت کامل شد! لطفاً اسکریپت را دوباره باز کنید.${NC}"
    exit 0
}

show_menu() {
    load_config
    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}  Cloudflare DDNS Manager - v$(get_version)  ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    
    if [ -n "$CF_ZONE_ID" ] && [ -n "$CF_API_KEY" ] && [ -n "$CF_RECORD_NAME" ]; then
        SERVER_IP=$(curl -s --max-time 3 https://api.ipify.org)
        CF_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" -H "Authorization: Bearer $CF_API_KEY" --max-time 3 | jq -r '.result.content' 2>/dev/null)
        
        echo -e " 🌐 Domain:     ${CYAN}$CF_RECORD_NAME${NC}"
        echo -e " 🖥️  Server IP:  $SERVER_IP"
        echo -e " ☁️  CF IP:      ${CF_IP:-${RED}Not Found${NC}}"
        if [ "$SERVER_IP" == "$CF_IP" ] && [ -n "$SERVER_IP" ]; then echo -e " ⚡ Status:     ${GREEN}SYNCED ✅${NC}"; else echo -e " ⚡ Status:     ${RED}OUT OF SYNC ❌${NC}"; fi
    else
        echo -e " ⚡ Status:     ${RED}NOT CONFIGURED YET${NC}"
    fi
    echo -e "${BLUE}=========================================${NC}"
    echo -e " ${CYAN}0) ⚡ Quick Auto-Setup Wizard (ویزارد خودکار)${NC}"
    echo -e " ${YELLOW}1) ${NC}View / Edit Current Settings (نمایش تنظیمات)"
    echo -e " ${YELLOW}2) ${NC}Run Check Manually (تست دستی)"
    echo -e " ${YELLOW}3) ${NC}View Logs (مشاهده لاگ‌ها)"
    echo -e " ${YELLOW}4) ${NC}Update from GitHub (آپدیت برنامه)"
    echo -e " ${RED}5) ${NC}Uninstall Script (حذف برنامه)"
    echo -e " ${YELLOW}6) ${NC}Exit"
    echo -e "${BLUE}=========================================${NC}"
}

while true; do
    show_menu
    read -r -p "Select an option: " OPTION
    case $OPTION in
        0) quick_setup_wizard ;;
        1) view_settings ;;
        2) echo -e "${YELLOW}درحال بررسی...${NC}"; $CORE_SCRIPT "MANUAL"; sleep 2 ;;
        3) echo -e "${YELLOW}--- Last Logs ---${NC}"; sudo tail -n 15 /var/log/cfddns.log; read -r -p "Press Enter to return..." ;;
        4) check_update ;;
        5) read -r -p "Are you sure? (y/n): " c; if [[ "$c" == "y" ]]; then sudo crontab -l 2>/dev/null | grep -v 'cfddns' | sudo crontab -; sudo rm -rf /usr/local/bin/cfddns* /etc/cfddns /var/log/cfddns.log; echo "Deleted!"; exit 0; fi ;;
        6) clear; break ;;
    esac
done
EOF
sudo chmod +x /usr/local/bin/cfddns