#!/usr/bin/env bash

CONFIG_FILE="/etc/cfddns/cfddns.conf"
LOG_FILE="/var/log/cfddns.log"

if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; else exit 1; fi

EXEC_MODE=${1:-CRON}
TTL="120"

get_ip() { curl -s --max-time 10 https://api.ipify.org; }
get_cf_ip() { curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" -H "Authorization: Bearer $CF_API_KEY" | jq -r '.result.content' 2>/dev/null; }

update_ip() {
    local NEW_IP=$1
    local PROXY_STR=""
    if [ "$CF_PROXY_STATUS" == "true" ] || [ "$CF_PROXY_STATUS" == "false" ]; then
        PROXY_STR=",\"proxied\": $CF_PROXY_STATUS"
    else
        PROXY_STR=",\"proxied\": false"
    fi

    local PAYLOAD="{\"type\":\"A\",\"name\":\"$CF_RECORD_NAME\",\"content\":\"$NEW_IP\",\"ttl\":$TTL $PROXY_STR}"
    local RES=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" -H "Authorization: Bearer $CF_API_KEY" -H "Content-Type: application/json" --data "$PAYLOAD")

    if echo "$RES" | grep -q '"success":true'; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ [SUCCESS] IP updated to $NEW_IP ($EXEC_MODE)" >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ [FAILED] API Update Error ($EXEC_MODE)" >> "$LOG_FILE"
    fi
}

CUR_IP=$(get_ip)
CF_IP=$(get_cf_ip)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ "$EXEC_MODE" == "MANUAL" ]; then echo "$TIMESTAMP - 🔍 [INFO] Manual check started..." >> "$LOG_FILE"; fi

if [ -z "$CUR_IP" ]; then
    echo "$TIMESTAMP - ⚠️ [ERROR] Could not fetch server IP." >> "$LOG_FILE"
    exit 1
fi

if [ "$CUR_IP" != "$CF_IP" ]; then
    echo "$TIMESTAMP - 🔄 [INFO] IP Change Detected! Old: ${CF_IP:-None} | New: $CUR_IP" >> "$LOG_FILE"
    update_ip "$CUR_IP"
elif [ "$EXEC_MODE" == "MANUAL" ]; then
    echo "$TIMESTAMP - 🟢 [INFO] Server IP ($CUR_IP) is unchanged. No update needed." >> "$LOG_FILE"
fi