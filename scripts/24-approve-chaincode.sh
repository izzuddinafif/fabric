#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/chaincode-utils.sh"

echo "👍 Approving Chaincode for Organizations..."

# Define paths and variables
LOCAL_FABRIC_DIR="$HOME/fabric"
CHAINCODE_NAME="mycc"
CHAINCODE_VERSION="1.0"
CHAINCODE_LABEL="${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
CHANNEL_NAME="zakatchannel"
SEQUENCE="1"

# Setup logging
LOG_DIR="$LOCAL_FABRIC_DIR/logs"
LOG_FILE="$LOG_DIR/24-approve-chaincode.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

log_msg "$LOG_FILE" "Starting Chaincode Approval Process (24)"

# Approve chaincode for each organization
for i in "${!ORG_DOMAINS[@]}"; do
    ORG_DOMAIN="${ORG_DOMAINS[$i]}"
    ORG_IP="${ORG_IPS[$i]}"
    
    log_msg "$LOG_FILE" "👍 Processing chaincode approval for $ORG_DOMAIN..."
    
    # Get package ID
    PACKAGE_ID=$(get_package_id "$ORG_IP" "$ORG_DOMAIN" "$CHAINCODE_LABEL" "$LOG_FILE")
    if [ -z "$PACKAGE_ID" ]; then
        log_msg "$LOG_FILE" "⛔ Failed to get package ID for $ORG_DOMAIN"
        exit 1
    fi
    log_msg "$LOG_FILE" "📋 Using package ID: $PACKAGE_ID"
    
    # Approve chaincode definition
    if ! approve_chaincode \
        "$ORG_IP" \
        "$ORG_DOMAIN" \
        "$CHANNEL_NAME" \
        "$PACKAGE_ID" \
        "$SEQUENCE" \
        "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to approve chaincode for $ORG_DOMAIN"
        exit 1
    fi
    
    log_msg "$LOG_FILE" "✅ Chaincode approved successfully for $ORG_DOMAIN."
    echo "-----------------------------------------------------"
done

log_msg "$LOG_FILE" "🎉 Chaincode approval completed for all organizations!"
log_msg "$LOG_FILE" "Next steps:"
log_msg "$LOG_FILE" "1. Check commit readiness (script 25)"
log_msg "$LOG_FILE" "2. Commit chaincode definition"
log_msg "$LOG_FILE" "3. Invoke chaincode functions"
log_msg "$LOG_FILE" "----------------------------------------"

exit 0
