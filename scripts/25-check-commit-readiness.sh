#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/chaincode-utils.sh"

echo "🔍 Checking Chaincode Commit Readiness..."

# Define paths and variables
LOCAL_FABRIC_DIR="$HOME/fabric"
CHAINCODE_NAME="mycc"
CHANNEL_NAME="zakatchannel"
SEQUENCE="1"

# Setup logging
LOG_DIR="$LOCAL_FABRIC_DIR/logs"
LOG_FILE="$LOG_DIR/25-check-commit-readiness.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

log_msg "$LOG_FILE" "Starting Chaincode Commit Readiness Check (25)"

# We'll check commit readiness from each organization to ensure consistency
for i in "${!ORG_DOMAINS[@]}"; do
    ORG_DOMAIN="${ORG_DOMAINS[$i]}"
    ORG_IP="${ORG_IPS[$i]}"
    
    log_msg "$LOG_FILE" "🔍 Checking commit readiness from $ORG_DOMAIN's perspective..."
    
    # Check commit readiness
    if ! check_commit_readiness \
        "$ORG_IP" \
        "$ORG_DOMAIN" \
        "$CHANNEL_NAME" \
        "$SEQUENCE" \
        "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to check commit readiness for $ORG_DOMAIN"
        exit 1
    fi
    
    log_msg "$LOG_FILE" "✅ Commit readiness check completed for $ORG_DOMAIN."
    echo "-----------------------------------------------------"
done

log_msg "$LOG_FILE" "🎉 Chaincode commit readiness check completed!"
log_msg "$LOG_FILE" "Next steps:"
log_msg "$LOG_FILE" "1. Commit chaincode definition (script 26)"
log_msg "$LOG_FILE" "2. Initialize and test chaincode"
log_msg "$LOG_FILE" "----------------------------------------"

exit 0
