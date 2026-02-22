#!/usr/bin/env bash
set -euo pipefail

# Get present directory 
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Import config
CONF_FILE="$SCRIPT_DIR/conf"
. "$CONF_FILE"

# Local logging for debugging
LOG_FILE="$SCRIPT_DIR"/log

DATE_NOW="$(date)"
IP_URL="https://ifconfig.me"

# Get current public IP
CURRENT_IP="$(curl -s "$IP_URL")"

# Determine how many DNS# entries exist in conf
MAX_DNS_COUNT="$(grep -E '^DNS_[0-9]+' "$CONF_FILE" | wc -l)"

# Add newline separator in log
echo -e "\n$DATE_NOW" >> "$LOG_FILE"

# Iterate through DNS_1, DNS_2, ...
for ((COUNT=1; COUNT<=MAX_DNS_COUNT; COUNT++)); do

    DNS_VAR="DNS_$COUNT"
    PROVIDER_VAR="CLOUD_PROVIDER_$COUNT"

    HOST="${!DNS_VAR:-}"
    PROVIDER="${!PROVIDER_VAR:-}"

    # Skip if not defined
    if [[ -z "$HOST" || -z "$PROVIDER" ]]; then
        continue
    fi

    # Get current DNS A record
    CURRENT_DNS="$(dig +short "$HOST" A | head -n1)"

    echo "Host = $HOST"
    echo "Host = $HOST @ $CURRENT_IP" >> "$LOG_FILE"

    if [[ "$CURRENT_IP" == "$CURRENT_DNS" ]]; then
        echo "IP matches DNS. No update needed." >> "$LOG_FILE"
        continue
    fi

    echo "IP mismatch (DNS: $CURRENT_DNS) - updating..." >> "$LOG_FILE"

    ### Google Cloud
    # -------------- 
    if [[ "$PROVIDER" == "gc" ]]; then

        GC_PROJECT_VAR="PROJECT_$COUNT"
        GC_ZONE_VAR="ZONE_$COUNT"

        GC_PROJECT="${!GC_PROJECT_VAR}"
        GC_ZONE="${!GC_ZONE_VAR}"

        gcloud dns record-sets update "$HOST" \
            --type="A" \
            --zone="$GC_ZONE" \
            --project="$GC_PROJECT" \
            --rrdatas="$CURRENT_IP" \
            --ttl=60 >> "$LOG_FILE" 2>&1

        echo "Updated via Google Cloud DNS." >> "$LOG_FILE"

    ### AWS Route 53
    # -------------- 
    elif [[ "$PROVIDER" == "aws" ]]; then

        AWS_ZONE_VAR="ZONE_$COUNT"
        HOSTED_ZONE_ID="${!AWS_ZONE_VAR:-}"

        if [[ -z "$HOSTED_ZONE_ID" ]]; then
            echo "Missing hosted zone ID for $HOST. Skipping AWS update." >> "$LOG_FILE"
            continue
        fi

        CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "$HOST",
      "Type": "A",
      "TTL": 60,
      "ResourceRecords": [{"Value": "$CURRENT_IP"}]
    }
  }]
}
EOF
)

        aws route53 change-resource-record-sets \
            --hosted-zone-id "$HOSTED_ZONE_ID" \
            --change-batch "$CHANGE_BATCH" >> "$LOG_FILE" 2>&1

        echo "Updated via AWS Route 53." >> "$LOG_FILE"

    else
        echo "Unknown provider: $PROVIDER" >> "$LOG_FILE"
    fi

done

exit 0
