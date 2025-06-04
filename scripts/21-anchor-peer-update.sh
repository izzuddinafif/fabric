#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/channel-utils.sh"

echo "⚓ Updating Anchor Peers..."

# Define paths
LOCAL_FABRIC_DIR="$HOME/fabric"
CHANNEL_ARTIFACTS_DIR="$LOCAL_FABRIC_DIR/channel-artifacts"
CHANNEL_NAME="zakatchannel"

# Setup logging
LOG_DIR="$LOCAL_FABRIC_DIR/logs"
LOG_FILE="$LOG_DIR/21-anchor-peer-update.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

log_msg "$LOG_FILE" "Starting Anchor Peer Update Process (21)"

# Process each organization
for i in ${!ORG_NAMES[@]}; do
    ORG_NAME=${ORG_NAMES[$i]}
    ORG_DOMAIN=${ORG_DOMAINS[$i]}
    ORG_IP=${ORG_IPS[$i]}
    
    # Verify anchor peer update transaction file exists
    ANCHOR_TX="$CHANNEL_ARTIFACTS_DIR/${ORG_NAME}MSPanchors.tx"
    if [ ! -f "$ANCHOR_TX" ]; then
        log_msg "$LOG_FILE" "⛔ Anchor peer update transaction file not found for $ORG_NAME: $ANCHOR_TX"
        exit 1
    fi

    log_msg "$LOG_FILE" "📝 Updating anchor peers for $ORG_NAME..."
    if ! update_anchor_peers \
        "$ORG_IP" \
        "$ORG_DOMAIN" \
        "$CHANNEL_NAME" \
        "/etc/hyperledger/fabric/channel-artifacts/${ORG_NAME}MSPanchors.tx" \
        "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to update anchor peers for $ORG_NAME"
        exit 1
    fi
    
    log_msg "$LOG_FILE" "✅ Anchor peers updated for $ORG_NAME."
    echo "-----------------------------------------------------"
done

log_msg "$LOG_FILE" "🎉 All anchor peer updates completed successfully!"
log_msg "$LOG_FILE" "Next steps:"
log_msg "$LOG_FILE" "1. Package chaincode (script 22)"
log_msg "$LOG_FILE" "2. Install and approve chaincode on all peers"
log_msg "$LOG_FILE" "----------------------------------------"

exit 0
