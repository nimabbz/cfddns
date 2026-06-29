sudo tee /usr/local/bin/cfddns.sh << 'EOF'
#!/usr/bin/env bash

CONFIG_DIR="/etc/cfddns"
CONFIG_FILE="$CONFIG_DIR/cfddns.conf"
if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; else exit 1; fi

LOG_FILE="/var/log/cfddns.log"
TTL="120"
EXEC_MODE=${1:-CRON}

get_current_ip() { curl -s --max-time 10 https://api.ipify.org; }
get_cf_ip() {
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" \
         -H "Authorization: Bearer $CF_API_KEY" | jq -r '.result.content' 2>/dev/null
}

update_cf_ip() {
    local NEW_IP=$1
    local PAYLOAD
    local PROXY_SETTING=""
    
    if [ -z "$CF_PROXY_STATUS" ]; then CF_PROXY_STATUS="false"; fi
    if [ "$CF_PROXY_STATUS" == "true" ] || [ "$CF_PROXY_STATUS" == "false" ]; then PROXY_SETTING=",\"proxied\": $CF_PROXY_STATUS"; fi

    PAYLOAD=$(cat <<JSON_EOF
{
  "type": "A",
  "name": "$CF_RECORD_NAME",
  "content": "$NEW_IP",
  "ttl": $TTL
  $PROXY_SETTING
}
JSON_EOF
)
    local UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" \
         -H "Authorization: Bearer $CF_API_KEY" \
         -H "Content-Type: application/json" \
         --data "$PAYLOAD")

    if echo "$UPDATE_RESULT" | grep -q '"success":true'; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS [$EXEC_MODE]: IP updated to $NEW_IP." >> "$LOG_FILE"
    else
        local CF_ERROR_CODE=$(echo "$UPDATE_RESULT" | jq -r '.errors[0].code' 2>/dev/null)
        local HUMAN_ERROR="Unknown API Error."
        case "$CF_ERROR_CODE" in
            7003) HUMAN_ERROR="Invalid Zone ID or Record ID. Please run Quick Setup again." ;;
            10001) HUMAN_ERROR="Authentication failed. Check your API Token." ;;
            81053) HUMAN_ERROR="DNS Record already exists with the same IP." ;;
            *) HUMAN_ERROR="Cloudflare Error Code: $CF_ERROR_CODE" ;;
        esac
        echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED [$EXEC_MODE]: $HUMAN_ERROR" >> "$LOG_FILE"
    fi
}

CURRENT_IP=$(get_current_ip)
CF_IP=$(get_cf_ip)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ "$EXEC_MODE" == "MANUAL" ]; then echo "$TIMESTAMP - INFO [$EXEC_MODE]: Check started." >> "$LOG_FILE"; fi
if [ -z "$CURRENT_IP" ]; then echo "$TIMESTAMP - ERROR [$EXEC_MODE]: Failed to get server IP." >> "$LOG_FILE"; exit 1; fi

if [ "$CURRENT_IP" != "$CF_IP" ]; then
    echo "$TIMESTAMP - IP CHANGE DETECTED! Old: ${CF_IP:-None} | New: $CURRENT_IP" >> "$LOG_FILE"
    update_cf_ip "$CURRENT_IP"
elif [ "$EXEC_MODE" == "MANUAL" ]; then
    echo "$TIMESTAMP - INFO [$EXEC_MODE]: IP $CURRENT_IP is unchanged." >> "$LOG_FILE"
fi
EOF
sudo chmod +x /usr/local/bin/cfddns.sh