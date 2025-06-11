#!/bin/bash
# Script 25: Check Chaincode Commit Readiness

set -e # Exit on error

echo "🧐 Checking Chaincode Commit Readiness..."

# Define Organization Details (Need details for at least one org to run the check)
ORG_NAME="Org1"
ORG_DOMAIN="org1.fabriczakat.local"
ORG_IP="10.104.0.2"
ORG_MSP="Org1MSP"
CLI_CONTAINER="cli.${ORG_DOMAIN}"

# Channel details
CHANNEL_NAME="zakatchannel"

# Chaincode definition details (Must match approved definition)
CHAINCODE_NAME="zakat"
CHAINCODE_VERSION="2.0"
# Endorsement policy (Must match approved definition)
ENDORSEMENT_POLICY="AND('Org1MSP.member', 'Org2MSP.member')"
# Collection config (if any, must match approved definition)
COLLECTION_CONFIG="" # Example: --collections-config /path/to/collections.json
# Init required flag (Must match approved definition)
INIT_REQUIRED="--init-required" # Use "--init-required" or ""

# Orderer details (Not strictly needed for checkcommitreadiness, but TLS cert might be)
ORDERER_ADDRESS="orderer.fabriczakat.local:7050"
ORDERER_CA_CERT="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem" # Path inside CLI container

# Log file on the Orderer machine
LOG_DIR="$HOME/fabric/logs"
LOG_FILE="$LOG_DIR/25-check-commit-readiness.log"
mkdir -p $LOG_DIR
> $LOG_FILE # Clear previous log

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Auto-detect current sequence number by querying current committed sequence
CURRENT_SEQUENCE=$(ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c 'peer lifecycle chaincode querycommitted -C $CHANNEL_NAME -n $CHAINCODE_NAME --output json'" 2>/dev/null | grep -o '"sequence": [0-9]*' | awk '{print $2}' || echo "0")
SEQUENCE=$((CURRENT_SEQUENCE + 1))

log "Starting Chaincode Commit Readiness Check Script (25)"
log "Channel: $CHANNEL_NAME"
log "Chaincode Name: $CHAINCODE_NAME"
log "Version: $CHAINCODE_VERSION"
log "Current sequence: $CURRENT_SEQUENCE, Checking sequence: $SEQUENCE"
log "Policy: $ENDORSEMENT_POLICY"
log "Init Required: ${INIT_REQUIRED:-false}"

# Command string construction - Use the same quoting strategy as the successful approve script
# Escape the double quotes around the policy variable
# checkcommitreadiness connects to the peer, not the orderer directly, but might need orderer TLS cert for discovery/validation?
# Let's include the orderer flags just in case, matching the approve command structure.
CHECK_CMD="peer lifecycle chaincode checkcommitreadiness \
    -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local \
    --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version $CHAINCODE_VERSION \
    --sequence $SEQUENCE $INIT_REQUIRED \
    --signature-policy \\\"$ENDORSEMENT_POLICY\\\" \
    $COLLECTION_CONFIG \
    --tls --cafile $ORDERER_CA_CERT --output json"

# Construct the full command to be executed remotely via bash -c "..."
# Use double quotes around the bash -c argument for SSH
FULL_REMOTE_CMD="docker exec $CLI_CONTAINER bash -c \"$CHECK_CMD\""

log "Executing check on $ORG_NAME ($ORG_IP): $FULL_REMOTE_CMD"

# Execute the check command via SSH + docker exec
ssh fabricadmin@$ORG_IP "$FULL_REMOTE_CMD" >> $LOG_FILE 2>&1

if [ $? -ne 0 ]; then
    log "⛔ Error: Failed to check commit readiness for chaincode '$CHAINCODE_NAME' sequence $SEQUENCE."
    log "   Check the logs ($LOG_FILE) and the container logs on $ORG_IP: docker logs $CLI_CONTAINER"
    # Dump the output from the command to stdout as well for immediate feedback
    ssh fabricadmin@$ORG_IP "$FULL_REMOTE_CMD" || true
    exit 1
fi

log "✅ Commit readiness check successful. Output logged to $LOG_FILE."
log "   Review the log file to see which organizations have approved."

# You can optionally parse the JSON output here to explicitly check approvals
# Example (requires jq):
# APPROVALS=$(ssh fabricadmin@$ORG_IP "$FULL_REMOTE_CMD" 2>/dev/null | jq .approvals) # Ignore stderr for jq parsing
# log "Approvals found: $APPROVALS"
# if [[ $(echo "$APPROVALS" | jq '."Org1MSP"' 2>/dev/null) == "true" && $(echo "$APPROVALS" | jq '."Org2MSP"' 2>/dev/null) == "true" ]]; then
#    log "✅ Both Org1MSP and Org2MSP have approved according to JSON output."
# else
#    log "⚠️ Not all required organizations have approved yet according to JSON output."
# fi

log "----------------------------------------"
exit 0
