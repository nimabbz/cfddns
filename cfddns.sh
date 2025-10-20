#!/usr/bin/env bash

# This script checks the server's current public IP against the Cloudflare DNS record
# and updates the record if a difference is found.

# --- Configuration (Loaded from environment variables) ---
CF_EMAIL="${CF_EMAIL}"
CF_API_KEY="${CF_API_KEY}"
CF_ZONE_ID="${CF_ZONE_ID}"
CF_RECORD_ID="${CF_RECORD_ID}"
CF_RECORD_NAME="${CF_RECORD_NAME}"
LOG_FILE="/var/log/cfddns.log"
TTL="120"
PROXY="true"

# --- Function to get the server's current public IP ---
get_current_ip() {
    # Use ipify for a reliable IPv4 public address
    curl -s https://api.ipify.org
}

# --- Function to get the current IP from Cloudflare DNS record using jq ---
get_cf_ip() {
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: 'jq' is not installed. Cannot parse Cloudflare API response." >> "$LOG_FILE"
        return 1
    fi
    
    # Retrieve DNS record details and extract the IP content
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
    # Send PUT request to update the DNS record
    local UPDATE_RESULT
    UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" \
         -H "X-Auth-Email: $CF_EMAIL" \
         -H "Authorization: Bearer $CF_API_KEY" \
         -H "Content-Type: application/json" \
         --data "$PAYLOAD")

    # Check for success in the API response
    if echo "$UPDATE_RESULT" | grep -q '"success":true'; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: Cloudflare DNS updated to $NEW_IP." >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED: Cloudflare API update failed. Response: $UPDATE_RESULT" >> "$LOG_FILE"
    fi
}

# ----------------- Main Logic -----------------
CURRENT_IP=$(get_current_ip)
CF_IP=$(get_cf_ip)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Check for basic IP retrieval failure
if [ -z "$CURRENT_IP" ]; then
    echo "$TIMESTAMP - ERROR: Failed to get current server IP." >> "$LOG_FILE"
    exit 1
fi

# Compare IPs
if [ "$CURRENT_IP" != "$CF_IP" ]; then
    # Log the change
    echo "$TIMESTAMP - IP CHANGE DETECTED!" >> "$LOG_FILE"
    echo "$TIMESTAMP - Old IP (CF): $CF_IP" >> "$LOG_FILE"
    echo "$TIMESTAMP - New IP (Server): $CURRENT_IP" >> "$LOG_FILE"
    
    # Update Cloudflare
    update_cf_ip "$CURRENT_IP"
else
    # Only log to file if running manually or debugging
    # echo "$TIMESTAMP - INFO: IP $CURRENT_IP is unchanged." >> /dev/null
    exit 0 # Exit quietly for Cron Job
fi