#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/chaincode-utils.sh"

echo "📝 Committing Chaincode Definition..."

# Define paths and variables
LOCAL_FABRIC_DIR="$HOME/fabric"
CHAINCODE_NAME="mycc"
CHANNEL_NAME="zakatchannel"
SEQUENCE="1"

# Setup logging
LOG_DIR="$LOCAL_FABRIC_DIR/logs"
LOG_FILE="$LOG_DIR/26-commit-chaincode.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

log_msg "$LOG_FILE" "Starting Chaincode Definition Commitment Process (26)"

# We'll use the first organization to commit the chaincode
FIRST_ORG_DOMAIN="${ORG_DOMAINS[0]}"
FIRST_ORG_IP="${ORG_IPS[0]}"

# Commit the chaincode definition
log_msg "$LOG_FILE" "📝 Committing chaincode definition using $FIRST_ORG_DOMAIN..."
if ! commit_chaincode \
    "$FIRST_ORG_IP" \
    "$FIRST_ORG_DOMAIN" \
    "$CHANNEL_NAME" \
    "$SEQUENCE" \
    "$LOG_FILE"; then
    log_msg "$LOG_FILE" "⛔ Failed to commit chaincode definition"
    exit 1
fi

log_msg "$LOG_FILE" "✅ Chaincode definition committed successfully."

# Verify the committed chaincode on each organization
for i in "${!ORG_DOMAINS[@]}"; do
    ORG_DOMAIN="${ORG_DOMAINS[$i]}"
    ORG_IP="${ORG_IPS[$i]}"
    
    log_msg "$LOG_FILE" "🔍 Querying committed chaincode from $ORG_DOMAIN..."
    
    if ! query_committed \
        "$ORG_IP" \
        "$ORG_DOMAIN" \
        "$CHANNEL_NAME" \
        "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⚠️ Failed to query committed chaincode from $ORG_DOMAIN"
        # Don't exit, as the commitment might still be successful
    fi
    
    echo "-----------------------------------------------------"
done

log_msg "$LOG_FILE" "🎉 Chaincode definition commitment process completed!"
log_msg "$LOG_FILE" "Next steps:"
log_msg "$LOG_FILE" "1. Initialize chaincode"
log_msg "$LOG_FILE" "2. Test chaincode functions"
log_msg "$LOG_FILE" "3. Monitor chaincode operations"
log_msg "$LOG_FILE" "----------------------------------------"

exit 0
