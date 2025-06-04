#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/channel-utils.sh"

echo "🔗 Creating and Joining Channel..."

# Define paths
LOCAL_FABRIC_DIR="$HOME/fabric"
CHANNEL_ARTIFACTS_DIR="$LOCAL_FABRIC_DIR/channel-artifacts"
CHANNEL_NAME="zakatchannel"

# Setup logging
LOG_DIR="$LOCAL_FABRIC_DIR/logs"
LOG_FILE="$LOG_DIR/20-channel-create-join.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

log_msg "$LOG_FILE" "Starting Channel Creation and Join Process (20)"

# Verify channel transaction file exists
CHANNEL_TX="$CHANNEL_ARTIFACTS_DIR/${CHANNEL_NAME}.tx"
if [ ! -f "$CHANNEL_TX" ]; then
    log_msg "$LOG_FILE" "⛔ Channel transaction file not found: $CHANNEL_TX"
    exit 1
fi
log_msg "$LOG_FILE" "✅ Channel transaction file verified."

# Create channel using the first organization
FIRST_ORG_DOMAIN="${ORG_DOMAINS[0]}"
FIRST_ORG_IP="${ORG_IPS[0]}"

log_msg "$LOG_FILE" "📝 Creating channel using ${FIRST_ORG_DOMAIN}..."
if ! create_channel \
    "$FIRST_ORG_IP" \
    "$FIRST_ORG_DOMAIN" \
    "$CHANNEL_NAME" \
    "/etc/hyperledger/fabric/channel-artifacts/${CHANNEL_NAME}.tx" \
    "$LOG_FILE"; then
    log_msg "$LOG_FILE" "⛔ Channel creation failed"
    exit 1
fi
log_msg "$LOG_FILE" "✅ Channel created successfully."

# Have each organization join the channel
for i in ${!ORG_DOMAINS[@]}; do
    ORG_DOMAIN="${ORG_DOMAINS[$i]}"
    ORG_IP="${ORG_IPS[$i]}"
    
    log_msg "$LOG_FILE" "📝 Having $ORG_DOMAIN join the channel..."
    if ! join_channel "$ORG_IP" "$ORG_DOMAIN" "$CHANNEL_NAME" "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to join channel for $ORG_DOMAIN"
        exit 1
    fi
    log_msg "$LOG_FILE" "✅ $ORG_DOMAIN joined the channel successfully."

    # Verify channel list for each organization
    if ! list_channels "$ORG_IP" "$ORG_DOMAIN" "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to list channels for $ORG_DOMAIN"
        exit 1
    fi
    
    # Get channel information to verify everything is correct
    if ! get_channel_info "$ORG_IP" "$ORG_DOMAIN" "$CHANNEL_NAME" "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to get channel info for $ORG_DOMAIN"
        exit 1
    fi
done

log_msg "$LOG_FILE" "🎉 Channel creation and joining completed successfully!"
log_msg "$LOG_FILE" "Next steps:"
log_msg "$LOG_FILE" "1. Update anchor peers for each organization (script 21)"
log_msg "$LOG_FILE" "2. Deploy chaincode on the channel"
log_msg "$LOG_FILE" "----------------------------------------"

exit 0
