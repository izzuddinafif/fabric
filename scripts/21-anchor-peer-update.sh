#!/bin/bash
# Script 21: Update Anchor Peers

set -e # Exit on error

echo "🚀 Updating Anchor Peers..."

# Define Organization Details
ORG_NAMES=("Org1" "Org2")
ORG_DOMAINS=("org1.fabriczakat.local" "org2.fabriczakat.local")
ORG_IPS=("10.104.0.2" "10.104.0.4")

# Channel details
CHANNEL_NAME="zakatchannel"

# Orderer details (as seen from within the CLI containers)
ORDERER_ADDRESS="orderer.fabriczakat.local:7050"
ORDERER_CA_CERT="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem" # Path inside CLI container

# Log file on the Orderer machine
LOG_DIR="$HOME/fabric/logs"
LOG_FILE="$LOG_DIR/21-anchor-peer-update.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Anchor Peer Update Script (21)"

# Loop through each organization to update its anchor peer
for i in ${!ORG_NAMES[@]}; do
    ORG_NAME=${ORG_NAMES[$i]}
    ORG_DOMAIN=${ORG_DOMAINS[$i]}
    ORG_IP=${ORG_IPS[$i]}
    ORG_MSP_ID="${ORG_NAME}MSP" # e.g., Org1MSP
    CLI_CONTAINER="cli.${ORG_DOMAIN}"
    ANCHOR_TX_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${ORG_MSP_ID}anchors.tx" # Path inside CLI container

    log "----------------------------------------"
    log "Updating anchor peer for $ORG_NAME on channel '$CHANNEL_NAME'..."
    log "----------------------------------------"

    # Command to execute inside the Org's CLI container
    # Environment variables like CORE_PEER_LOCALMSPID, CORE_PEER_MSPCONFIGPATH are set in the container
    UPDATE_CMD="peer channel update -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local -c $CHANNEL_NAME -f $ANCHOR_TX_FILE --tls --cafile $ORDERER_CA_CERT"

    log "Executing on $CLI_CONTAINER@$ORG_IP: $UPDATE_CMD"

    # Execute the update command via SSH + docker exec
    ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c '$UPDATE_CMD'" >> $LOG_FILE 2>&1

    if [ $? -ne 0 ]; then
        log "⛔ Error: Failed to update anchor peer for $ORG_NAME."
        log "   Check the logs ($LOG_FILE) and the container logs on $ORG_IP: docker logs $CLI_CONTAINER"
        # Consider adding verification step here if possible (e.g., fetching config block and checking)
        exit 1
    fi

    log "✅ Anchor peer for $ORG_NAME updated successfully on channel '$CHANNEL_NAME'."
    sleep 2 # Small delay before processing next org

done

log "🎉 All anchor peers updated successfully!"
log "----------------------------------------"

exit 0
