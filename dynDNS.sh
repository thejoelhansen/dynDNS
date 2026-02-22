#!/usr/bin/env bash
set -euo pipefail

# Get present directory 
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Import config
CONF_FILE="$SCRIPT_DIR/conf"
. "$CONF_FILE"

DATE_NOW="$(date)"
IP_URL="https://ifconfig.me"

# Get current public IP
CURRENT_IP="$(curl -s "$IP_URL")"

# Build arrays from numbered conf variables
DNS_ARRAY=()
PROVIDER_ARRAY=()
GC_PROJECT_ARRAY=()
GC_ZONE_ARRAY=()
AWS_ZONE_ARRAY=()

# Load service account if key exists
if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    gcloud auth activate-service-account \
        --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
fi

COUNT=1
while true; do
    DNS_VAR="DNS_$COUNT"
    PROVIDER_VAR="CLOUD_PROVIDER_$COUNT"
    PROJECT_VAR="PROJECT_$COUNT"
    ZONE_VAR="ZONE_$COUNT"

    HOST="${!DNS_VAR:-}"
    PROVIDER="${!PROVIDER_VAR:-}"
    GC_PROJECT="${!PROJECT_VAR:-}"
    GC_ZONE="${!ZONE_VAR:-}"
    AWS_ZONE="${!ZONE_VAR:-}"

    # Stop if no more DNS entries
    [[ -z "$HOST" ]] && break

    DNS_ARRAY+=("$HOST")
    PROVIDER_ARRAY+=("$PROVIDER")
    GC_PROJECT_ARRAY+=("$GC_PROJECT")
    GC_ZONE_ARRAY+=("$GC_ZONE")
    AWS_ZONE_ARRAY+=("$AWS_ZONE")

    ((COUNT++))
done

# Timestamp
echo "$DATE_NOW"

# Iterate through arrays
for i in "${!DNS_ARRAY[@]}"; do
    HOST="${DNS_ARRAY[i]}"
    PROVIDER="${PROVIDER_ARRAY[i]}"
    GC_PROJECT="${GC_PROJECT_ARRAY[i]}"
    GC_ZONE="${GC_ZONE_ARRAY[i]}"
    HOSTED_ZONE_ID="${AWS_ZONE_ARRAY[i]}"

    # Get current DNS A record
    CURRENT_DNS="$(dig +short "$HOST" A | head -n1)"

    echo "Host = $HOST"
    echo "Host = $HOST @ $CURRENT_IP"

    if [[ "$CURRENT_IP" == "$CURRENT_DNS" ]]; then
        echo "Silence is golden." 
        continue
    fi

    echo "IP mismatch (DNS: $CURRENT_DNS) - updating..."

    ### Google Cloud
    if [[ "$PROVIDER" == "gc" ]]; then
        gcloud dns record-sets update "$HOST" \
            --type="A" \
            --zone="$GC_ZONE" \
            --project="$GC_PROJECT" \
            --rrdatas="$CURRENT_IP" \
            --ttl=60

        echo "Updated via Google Cloud DNS."

    ### AWS Route 53
    elif [[ "$PROVIDER" == "aws" ]]; then
        if [[ -z "$HOSTED_ZONE_ID" ]]; then
            echo "Missing hosted zone ID for $HOST. Skipping AWS update."
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
            --change-batch "$CHANGE_BATCH"

        echo "Updated via AWS Route 53."

    else
        echo "Unknown provider: $PROVIDER"
    fi
done

exit 0
