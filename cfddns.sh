#!/usr/bin/env bash

# This script checks the server's current public IP against the Cloudflare DNS record
# and updates the record if a difference is found.

# --- Configuration Loading ---
CONFIG_FILE="/etc/cfddns/cfddns.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - CRITICAL ERROR: Config file missing at $CONFIG_FILE. Exiting." >> "/var/log/cfddns.log"
    exit 1
fi

LOG_FILE="/var/log/cfddns.log"
TTL="120"
PROXY="true"
EXEC_MODE=${1:-CRON} # Default mode is CRON, can be set to MANUAL

# --- Dependency Check ---
if ! command -v jq &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: 'jq' is not installed. Cannot parse Cloudflare API response." >> "$LOG_FILE"
    exit 1
fi

# --- Function to get the server's current public IP ---
get_current_ip() {
    curl -s https://api.ipify.org
}

# --- Function to get the current IP from Cloudflare DNS record ---
get_cf_ip() {
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" \
         -H "X-Auth-Email: $CF_EMAIL" \
         -H "Authorization: Bearer $CF_API_KEY" | \
         jq -r '.result.content'
}

# --- Function to update the IP on Cloudflare ---
update_cf_ip() {
    local NEW_IP=$1
    local PAYLOAD
    
    PAYLOAD=$(cat <<EOF
{
  "type": "A",
  "name": "$CF_RECORD_NAME",
  "content": "$NEW_IP",
  "ttl": $TTL,
  "proxied": $PROXY
}
EOF
)
    local UPDATE_RESULT
    UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" \
         -H "X-Auth-Email: $CF_EMAIL" \
         -H "Authorization: Bearer $CF_API_KEY" \
         -H "Content-Type: application/json" \
         --data "$PAYLOAD")

    if echo "$UPDATE_RESULT" | grep -q '"success":true'; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS [$EXEC_MODE]: Cloudflare DNS updated to $NEW_IP." >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED [$EXEC_MODE]: Cloudflare API update failed. Response: $UPDATE_RESULT" >> "$LOG_FILE"
    fi
}

# ----------------- Main Logic -----------------
CURRENT_IP=$(get_current_ip)
CF_IP=$(get_cf_ip)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Log manual check for visibility, even if IP is unchanged
if [ "$EXEC_MODE" == "MANUAL" ]; then
    echo "$TIMESTAMP - INFO [$EXEC_MODE]: Manual check started." >> "$LOG_FILE"
fi

# Check for basic IP retrieval failure
if [ -z "$CURRENT_IP" ]; then
    echo "$TIMESTAMP - ERROR [$EXEC_MODE]: Failed to get current server IP." >> "$LOG_FILE"
    exit 1
fi

# Compare IPs
if [ "$CURRENT_IP" != "$CF_IP" ]; then
    # Log the change
    echo "$TIMESTAMP - IP CHANGE DETECTED! [$EXEC_MODE]" >> "$LOG_FILE"
    echo "$TIMESTAMP - Old IP (CF): $CF_IP" >> "$LOG_FILE"
    echo "$TIMESTAMP - New IP (Server): $CURRENT_IP" >> "$LOG_FILE"
    
    # Update Cloudflare
    update_cf_ip "$CURRENT_IP"
elif [ "$EXEC_MODE" == "MANUAL" ]; then
    echo "$TIMESTAMP - INFO [$EXEC_MODE]: IP $CURRENT_IP is unchanged (No update needed)." >> "$LOG_FILE"
else
    # CRON mode, no change: exit silently
    exit 0
fi