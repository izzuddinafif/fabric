#!/bin/bash
# Script 20: Create Channel & Join Peers

set -e # Exit on error

echo "🚀 Creating Channel and Joining Peers..."

# Define Organization Details (Primary Org for creation, others for joining)
ORG1_NAME="Org1"
ORG1_DOMAIN="org1.fabriczakat.local"
ORG1_IP="10.104.0.2"
ORG1_PEER_PORT="7051"

ORG2_NAME="Org2"
ORG2_DOMAIN="org2.fabriczakat.local"
ORG2_IP="10.104.0.4"
ORG2_PEER_PORT="7051"

# Channel details
CHANNEL_NAME="zakatchannel"
CHANNEL_TX_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.tx" # Path inside CLI container
CHANNEL_BLOCK_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block" # Path inside CLI container

# Orderer details (as seen from within the CLI containers)
ORDERER_ADDRESS="orderer.fabriczakat.local:7050"
ORDERER_CA_CERT="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem" # Path inside CLI container

# Log file on the Orderer machine
LOG_DIR="$HOME/fabric/logs"
LOG_FILE="$LOG_DIR/20-channel-create-join.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Channel Create/Join Script (20)"

# --- Step 1: Create Channel using Org1 CLI ---
log "----------------------------------------"
log "Creating channel '$CHANNEL_NAME' using Org1 CLI..."
log "----------------------------------------"

ORG1_CLI_CONTAINER="cli.${ORG1_DOMAIN}"

# Command to execute inside Org1 CLI container
# Note: Environment variables like CORE_PEER_LOCALMSPID, CORE_PEER_MSPCONFIGPATH, CORE_PEER_ADDRESS, CORE_PEER_TLS_ROOTCERT_FILE
# are already set in the container's environment (from docker-compose).
# We just need to specify the orderer details and channel config.
CREATE_CMD="peer channel create -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local -c $CHANNEL_NAME -f $CHANNEL_TX_FILE --outputBlock $CHANNEL_BLOCK_FILE --tls --cafile $ORDERER_CA_CERT"

log "Executing on $ORG1_CLI_CONTAINER@$ORG1_IP: $CREATE_CMD"

ssh fabricadmin@$ORG1_IP "docker exec $ORG1_CLI_CONTAINER bash -c '$CREATE_CMD'" >> $LOG_FILE 2>&1

# Check if the channel block file was created inside the container
# We check this via SSH + docker exec ls
ssh fabricadmin@$ORG1_IP "docker exec $ORG1_CLI_CONTAINER ls $CHANNEL_BLOCK_FILE" >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "⛔ Error: Channel creation failed. Block file '$CHANNEL_BLOCK_FILE' not found in $ORG1_CLI_CONTAINER."
    log "   Check the logs ($LOG_FILE) and the container logs on $ORG1_IP: docker logs $ORG1_CLI_CONTAINER"
    exit 1
fi
log "✅ Channel '$CHANNEL_NAME' created successfully. Block file generated: $CHANNEL_BLOCK_FILE (inside $ORG1_CLI_CONTAINER)"

# --- Step 2: Join Org1 Peer to the Channel ---
log "----------------------------------------"
log "Joining Org1 Peer to channel '$CHANNEL_NAME'..."
log "----------------------------------------"

JOIN_CMD="peer channel join -b $CHANNEL_BLOCK_FILE"

log "Executing on $ORG1_CLI_CONTAINER@$ORG1_IP: $JOIN_CMD"

ssh fabricadmin@$ORG1_IP "docker exec $ORG1_CLI_CONTAINER bash -c '$JOIN_CMD'" >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "⛔ Error: Org1 Peer failed to join channel '$CHANNEL_NAME'."
    log "   Check the logs ($LOG_FILE) and the container logs on $ORG1_IP: docker logs $ORG1_CLI_CONTAINER and docker logs peer.${ORG1_DOMAIN}"
    exit 1
fi

# Verify join by listing channels the peer has joined
sleep 3 # Give peer time to process join
VERIFY_JOIN_CMD="peer channel list"
log "Verifying Org1 join on $ORG1_CLI_CONTAINER@$ORG1_IP: $VERIFY_JOIN_CMD"
JOIN_OUTPUT=$(ssh fabricadmin@$ORG1_IP "docker exec $ORG1_CLI_CONTAINER bash -c '$VERIFY_JOIN_CMD'")
log "Org1 Peer Channel List Output:"
echo "$JOIN_OUTPUT" >> $LOG_FILE
echo "$JOIN_OUTPUT" # Also print to stdout

if [[ "$JOIN_OUTPUT" != *"$CHANNEL_NAME"* ]]; then
    log "⛔ Error: Org1 Peer verification failed. Channel '$CHANNEL_NAME' not found in list."
    exit 1
fi
log "✅ Org1 Peer joined channel '$CHANNEL_NAME' successfully."


# --- Step 3: Join Org2 Peer to the Channel ---
# Step 18 from the plan: Join Remaining Peers
log "----------------------------------------"
log "Joining Org2 Peer to channel '$CHANNEL_NAME'..."
log "----------------------------------------"

ORG2_CLI_CONTAINER="cli.${ORG2_DOMAIN}"

# We need the genesis block on the Org2 CLI container.
# The channel block was created on Org1's CLI. We need to copy it.
# Option 1: Copy from Org1 CLI -> Org1 Host -> Orderer Host -> Org2 Host -> Org2 CLI (complex)
# Option 2: Use 'peer channel fetch' on Org2 CLI (simpler if connectivity allows)
# Option 3: Copy directly between Org1 Host and Org2 Host (requires SCP between peers)
# Option 4: Copy from Org1 CLI -> Org1 Host -> SCP to Org2 Host -> Copy into Org2 CLI

log "Fetching channel block '$CHANNEL_BLOCK_FILE' on Org2 CLI..."
# Use peer channel fetch 0 to get the genesis block for the channel
FETCH_CMD="peer channel fetch 0 $CHANNEL_BLOCK_FILE -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local -c $CHANNEL_NAME --tls --cafile $ORDERER_CA_CERT"

log "Executing on $ORG2_CLI_CONTAINER@$ORG2_IP: $FETCH_CMD"
ssh fabricadmin@$ORG2_IP "docker exec $ORG2_CLI_CONTAINER bash -c '$FETCH_CMD'" >> $LOG_FILE 2>&1

# Check if the block file was fetched
ssh fabricadmin@$ORG2_IP "docker exec $ORG2_CLI_CONTAINER ls $CHANNEL_BLOCK_FILE" >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "⛔ Error: Failed to fetch channel block '$CHANNEL_BLOCK_FILE' on $ORG2_CLI_CONTAINER."
    log "   Check the logs ($LOG_FILE) and the container logs on $ORG2_IP: docker logs $ORG2_CLI_CONTAINER"
    exit 1
fi
log "✅ Channel block '$CHANNEL_BLOCK_FILE' fetched successfully on $ORG2_CLI_CONTAINER."

# Now join Org2 peer
log "Executing join on $ORG2_CLI_CONTAINER@$ORG2_IP: $JOIN_CMD"
ssh fabricadmin@$ORG2_IP "docker exec $ORG2_CLI_CONTAINER bash -c '$JOIN_CMD'" >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "⛔ Error: Org2 Peer failed to join channel '$CHANNEL_NAME'."
    log "   Check the logs ($LOG_FILE) and the container logs on $ORG2_IP: docker logs $ORG2_CLI_CONTAINER and docker logs peer.${ORG2_DOMAIN}"
    exit 1
fi

# Verify join for Org2
sleep 3
log "Verifying Org2 join on $ORG2_CLI_CONTAINER@$ORG2_IP: $VERIFY_JOIN_CMD"
JOIN_OUTPUT_ORG2=$(ssh fabricadmin@$ORG2_IP "docker exec $ORG2_CLI_CONTAINER bash -c '$VERIFY_JOIN_CMD'")
log "Org2 Peer Channel List Output:"
echo "$JOIN_OUTPUT_ORG2" >> $LOG_FILE
echo "$JOIN_OUTPUT_ORG2"

if [[ "$JOIN_OUTPUT_ORG2" != *"$CHANNEL_NAME"* ]]; then
    log "⛔ Error: Org2 Peer verification failed. Channel '$CHANNEL_NAME' not found in list."
    exit 1
fi
log "✅ Org2 Peer joined channel '$CHANNEL_NAME' successfully."


log "🎉 Channel created and all peers joined successfully!"
log "----------------------------------------"

exit 0
