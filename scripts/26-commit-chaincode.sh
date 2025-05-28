#!/bin/bash
    # Script 26: Commit Chaincode Definition

    set -e # Exit on error

    echo "🚢 Committing Chaincode Definition..."

    # Define Organization Details (Commit can be initiated by any org, e.g., Org1)
    ORG_NAME="Org1"
    ORG_DOMAIN="org1.fabriczakat.local"
    ORG_IP="10.104.0.2"
    ORG_MSP="Org1MSP"
    CLI_CONTAINER="cli.${ORG_DOMAIN}"

    # Channel details
    CHANNEL_NAME="zakatchannel"

    # Chaincode definition details (Must match approved definition)
    CHAINCODE_NAME="zakat"
    CHAINCODE_VERSION="1.0"
    SEQUENCE="1" # Sequence number being committed
    # Endorsement policy (Must match approved definition)
    ENDORSEMENT_POLICY="AND('Org1MSP.member', 'Org2MSP.member')"
    # Collection config (if any, must match approved definition)
    COLLECTION_CONFIG="" # Example: --collections-config /path/to/collections.json
    # Init required flag (Must match approved definition)
    INIT_REQUIRED="--init-required" # Use "--init-required" or ""

    # Orderer details (as seen from within the CLI containers)
    ORDERER_ADDRESS="orderer.fabriczakat.local:7050"
    ORDERER_CA_CERT="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem" # Path inside CLI container

    # Peer details for endorsement (Addresses and TLS certs *inside* the CLI container)
    # Need addresses for peers from Org1 and Org2 as required by the policy
    # CORRECTED ADDRESS: Changed peer0. to peer. to match container/service name
    PEER_ADDRESS_ORG1="peer.org1.fabriczakat.local:7051"
    PEER_TLS_ROOTCERT_ORG1="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/peers/peer.org1.fabriczakat.local/tls/ca.crt"
    # CORRECTED ADDRESS: Changed peer0. to peer. to match container/service name
    PEER_ADDRESS_ORG2="peer.org2.fabriczakat.local:7051"
    PEER_TLS_ROOTCERT_ORG2="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/peers/peer.org2.fabriczakat.local/tls/ca.crt"

    # Log file on the Orderer machine
    LOG_DIR="$HOME/fabric/logs"
    LOG_FILE="$LOG_DIR/26-commit-chaincode.log"
    mkdir -p $LOG_DIR
    > $LOG_FILE # Clear previous log

    # Function to log messages
    log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
    }

    log "Starting Chaincode Commit Script (26) - Corrected Peer Addresses"
    log "Channel: $CHANNEL_NAME"
    log "Chaincode Name: $CHAINCODE_NAME"
    log "Version: $CHAINCODE_VERSION"
    log "Sequence: $SEQUENCE"
    log "Policy: $ENDORSEMENT_POLICY"
    log "Init Required: ${INIT_REQUIRED:-false}"
    log "Using Org1 Peer Address: $PEER_ADDRESS_ORG1"
    log "Using Org1 TLS Cert Path: $PEER_TLS_ROOTCERT_ORG1"
    log "Using Org2 Peer Address: $PEER_ADDRESS_ORG2"
    log "Using Org2 TLS Cert Path: $PEER_TLS_ROOTCERT_ORG2"

    # --- Debug: Check if TLS cert files exist inside the container ---
    # Keeping this check for confirmation
    log "🔎 Verifying peer TLS cert paths inside $CLI_CONTAINER..."
    LS_CMD1="ls -l $PEER_TLS_ROOTCERT_ORG1"
    LS_CMD2="ls -l $PEER_TLS_ROOTCERT_ORG2"
    LS_CMD_ORDERER="ls -l $ORDERER_CA_CERT"

    log "   Executing on $ORG_IP: docker exec $CLI_CONTAINER bash -c \"$LS_CMD1\""
    ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c \"$LS_CMD1\"" >> $LOG_FILE 2>&1 || log "   ⚠️ Failed to list $PEER_TLS_ROOTCERT_ORG1"

    log "   Executing on $ORG_IP: docker exec $CLI_CONTAINER bash -c \"$LS_CMD2\""
    ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c \"$LS_CMD2\"" >> $LOG_FILE 2>&1 || log "   ⚠️ Failed to list $PEER_TLS_ROOTCERT_ORG2"

    log "   Executing on $ORG_IP: docker exec $CLI_CONTAINER bash -c \"$LS_CMD_ORDERER\""
    ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c \"$LS_CMD_ORDERER\"" >> $LOG_FILE 2>&1 || log "   ⚠️ Failed to list $ORDERER_CA_CERT"
    log "----------------------------------------"
    # --- End Debug ---

    # Command string construction - Use the same quoting strategy as the successful approve/check scripts
    # Escape the double quotes around the policy variable
    COMMIT_CMD="peer lifecycle chaincode commit \
        -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local \
        --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version $CHAINCODE_VERSION \
        --sequence $SEQUENCE $INIT_REQUIRED \
        --signature-policy \\\"$ENDORSEMENT_POLICY\\\" \
        $COLLECTION_CONFIG \
        --peerAddresses $PEER_ADDRESS_ORG1 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG1 \
        --peerAddresses $PEER_ADDRESS_ORG2 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG2 \
        --tls --cafile $ORDERER_CA_CERT \
        --connTimeout 10s" # Increased connection timeout

    # Construct the full command to be executed remotely via bash -c "..."
    # Use double quotes around the bash -c argument for SSH
    FULL_REMOTE_CMD="docker exec $CLI_CONTAINER bash -c \"$COMMIT_CMD\""

    log "Executing commit from $ORG_NAME ($ORG_IP): $FULL_REMOTE_CMD"

    # Execute the commit command via SSH + docker exec
    ssh fabricadmin@$ORG_IP "$FULL_REMOTE_CMD" >> $LOG_FILE 2>&1

    if [ $? -ne 0 ]; then
        log "⛔ Error: Failed to commit chaincode definition '$CHAINCODE_NAME' sequence $SEQUENCE."
        log "   Review the directory listings and paths used above in the log file."
        log "   Check the logs ($LOG_FILE) and the container logs on $ORG_IP: docker logs $CLI_CONTAINER"
        # Also check orderer logs: ssh fabricadmin@<orderer_ip> "docker logs orderer.fabriczakat.local"
        # Also check peer logs on Org1/Org2: ssh fabricadmin@<peer_ip> "docker logs peer.orgX.fabriczakat.local" # Corrected peer log name
        exit 1
    fi

    log "✅ Chaincode definition committed successfully on channel '$CHANNEL_NAME'."

    # Optional: Verify commit status
    log "🔎 Verifying commit status..."
    QUERY_COMMITTED_CMD="peer lifecycle chaincode querycommitted -C $CHANNEL_NAME -n $CHAINCODE_NAME --output json"
    log "   Executing on $CLI_CONTAINER@$ORG_IP: $QUERY_COMMITTED_CMD"
    # Use single quotes for simple query
    COMMIT_STATUS=$(ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c '$QUERY_COMMITTED_CMD'" 2>&1)
    echo "Commit Status:" >> $LOG_FILE
    echo "$COMMIT_STATUS" >> $LOG_FILE
    # Basic check - look for the sequence number in the JSON output
    if ! echo "$COMMIT_STATUS" | grep -q "\"sequence\": $SEQUENCE"; then
         log "⚠️ Warning: Could not verify commit status for sequence $SEQUENCE via querycommitted. Check logs."
    else
         log "✅ Commit status verified for sequence $SEQUENCE."
    fi

    log "----------------------------------------"
    # If --init-required was used, remind the user to invoke Init
    if [ "$INIT_REQUIRED" == "--init-required" ]; then
        log "🔔 IMPORTANT: Chaincode requires initialization. Run the 'InitLedger' (or equivalent) function next using 'peer chaincode invoke'."
        log "   Example (run from Org1 CLI):"
        log "   peer chaincode invoke -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local --tls --cafile $ORDERER_CA_CERT -C $CHANNEL_NAME -n $CHAINCODE_NAME --isInit -c '{\"function\":\"InitLedger\",\"Args\":[]}' --peerAddresses $PEER_ADDRESS_ORG1 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG1 --peerAddresses $PEER_ADDRESS_ORG2 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG2 --connTimeout 10s"
        log "----------------------------------------"
    fi

    exit 0
