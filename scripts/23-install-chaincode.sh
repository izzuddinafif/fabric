#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/chaincode-utils.sh"

echo "📥 Installing Chaincode on Peers..."

# Define paths and variables
LOCAL_FABRIC_DIR="$HOME/fabric"
CHAINCODE_NAME="mycc"
CHAINCODE_VERSION="1.0"
CHAINCODE_LABEL="${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
PACKAGE_NAME="${CHAINCODE_NAME}.tar.gz"

# Setup logging
LOG_DIR="$LOCAL_FABRIC_DIR/logs"
LOG_FILE="$LOG_DIR/23-install-chaincode.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

log_msg "$LOG_FILE" "Starting Chaincode Installation Process (23)"

# Install chaincode on each organization's peer
for i in "${!ORG_DOMAINS[@]}"; do
    ORG_DOMAIN="${ORG_DOMAINS[$i]}"
    ORG_IP="${ORG_IPS[$i]}"
    
    log_msg "$LOG_FILE" "📥 Installing chaincode for $ORG_DOMAIN..."
    
    # Verify package exists before installation
    if ! ssh_exec "$ORG_IP" "docker exec cli.$ORG_DOMAIN test -f $PACKAGE_NAME"; then
        log_msg "$LOG_FILE" "⛔ Chaincode package not found for $ORG_DOMAIN"
        exit 1
    fi
    
    # Install the chaincode
    if ! install_chaincode \
        "$ORG_IP" \
        "$ORG_DOMAIN" \
        "$PACKAGE_NAME" \
        "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to install chaincode on $ORG_DOMAIN"
        exit 1
    fi
    
    # Get and save package ID
    PACKAGE_ID=$(get_package_id "$ORG_IP" "$ORG_DOMAIN" "$CHAINCODE_LABEL" "$LOG_FILE")
    if [ -z "$PACKAGE_ID" ]; then
        log_msg "$LOG_FILE" "⛔ Failed to get package ID for $ORG_DOMAIN"
        exit 1
    fi
    log_msg "$LOG_FILE" "📋 Package ID for $ORG_DOMAIN: $PACKAGE_ID"
    
    log_msg "$LOG_FILE" "✅ Chaincode installed successfully on $ORG_DOMAIN."
    echo "-----------------------------------------------------"
done

log_msg "$LOG_FILE" "🎉 Chaincode installation completed successfully!"
log_msg "$LOG_FILE" "Next steps:"
log_msg "$LOG_FILE" "1. Approve chaincode definition for organizations (script 24)"
log_msg "$LOG_FILE" "2. Check commit readiness"
log_msg "$LOG_FILE" "3. Commit chaincode to channel"
log_msg "$LOG_FILE" "----------------------------------------"

exit 0
