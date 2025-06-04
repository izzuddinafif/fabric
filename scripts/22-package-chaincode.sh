#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/chaincode-utils.sh"

echo "📦 Packaging Chaincode..."

# Define paths and variables
LOCAL_FABRIC_DIR="$HOME/fabric"
CHAINCODE_NAME="mycc"
CHAINCODE_VERSION="1.0"
CHAINCODE_LABEL="${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
PACKAGE_NAME="${CHAINCODE_NAME}.tar.gz"

# Setup logging
LOG_DIR="$LOCAL_FABRIC_DIR/logs"
LOG_FILE="$LOG_DIR/22-package-chaincode.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

log_msg "$LOG_FILE" "Starting Chaincode Packaging Process (22)"

# Verify chaincode source exists
CHAINCODE_PATH="/etc/hyperledger/fabric/chaincode/zakat/"
for IP in "${ORG_IPS[@]}"; do
    if ! ssh_exec "$IP" "[ -d $CHAINCODE_PATH ]"; then
        log_msg "$LOG_FILE" "⛔ Chaincode directory not found at $CHAINCODE_PATH on $IP"
        exit 1
    fi
done
log_msg "$LOG_FILE" "✅ Chaincode source verified on all peers."

# Package chaincode on each organization's CLI container
for i in "${!ORG_DOMAINS[@]}"; do
    ORG_DOMAIN="${ORG_DOMAINS[$i]}"
    ORG_IP="${ORG_IPS[$i]}"
    
    log_msg "$LOG_FILE" "📦 Packaging chaincode for $ORG_DOMAIN..."
    
    # Package the chaincode
    if ! package_chaincode \
        "$ORG_IP" \
        "$ORG_DOMAIN" \
        "$PACKAGE_NAME" \
        "$CHAINCODE_PATH" \
        "$CHAINCODE_LABEL" \
        "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to package chaincode for $ORG_DOMAIN"
        exit 1
    fi
    
    # Verify package exists
    if ! ssh_exec "$ORG_IP" "docker exec cli.$ORG_DOMAIN test -f $PACKAGE_NAME"; then
        log_msg "$LOG_FILE" "⛔ Chaincode package not found after packaging for $ORG_DOMAIN"
        exit 1
    fi
    
    log_msg "$LOG_FILE" "✅ Chaincode packaged successfully for $ORG_DOMAIN."
    echo "-----------------------------------------------------"
done

log_msg "$LOG_FILE" "🎉 Chaincode packaging completed successfully!"
log_msg "$LOG_FILE" "Next steps:"
log_msg "$LOG_FILE" "1. Install chaincode package on peers (script 23)"
log_msg "$LOG_FILE" "2. Approve chaincode definition for organizations"
log_msg "$LOG_FILE" "3. Commit chaincode to channel"
log_msg "$LOG_FILE" "----------------------------------------"

exit 0
