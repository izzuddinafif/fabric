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
    CHAINCODE_VERSION="2.1"
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

    # Auto-detect current sequence number by querying current committed sequence
    CURRENT_SEQUENCE=$(ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c 'peer lifecycle chaincode querycommitted -C $CHANNEL_NAME -n $CHAINCODE_NAME --output json'" 2>/dev/null | grep -o '"sequence": [0-9]*' | awk '{print $2}' || echo "0")
    SEQUENCE=$((CURRENT_SEQUENCE + 1))
    
    log "Starting Chaincode Commit Script (26) - Auto-detecting Sequence"
    log "Channel: $CHANNEL_NAME"
    log "Chaincode Name: $CHAINCODE_NAME"
    log "Version: $CHAINCODE_VERSION"
    log "Current sequence: $CURRENT_SEQUENCE, Committing sequence: $SEQUENCE"
    log "Policy: $ENDORSEMENT_POLICY"
    log "Init Required: ${INIT_REQUIRED:-false}"
    # CONSTRUCTOR_ARGS is no longer needed for commit with --init-required
    # log "Constructor Args: $CONSTRUCTOR_ARGS"
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
    COMMIT_CMD="peer lifecycle chaincode commit \\
        -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local \\
        --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version $CHAINCODE_VERSION \\
        --sequence $SEQUENCE $INIT_REQUIRED \\
        --signature-policy \\\"$ENDORSEMENT_POLICY\\\" \\
        $COLLECTION_CONFIG \\
        --peerAddresses $PEER_ADDRESS_ORG1 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG1 \\
        --peerAddresses $PEER_ADDRESS_ORG2 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG2 \\
        --tls --cafile $ORDERER_CA_CERT \\
        --connTimeout 10s" # Increased connection timeout

    # Construct the full command to be executed remotely via bash -c "..."
    # The entire string inside "..." for bash -c needs to be valid.
    # $CONSTRUCTOR_ARGS already has single quotes around its JSON. We need to ensure these are preserved.
    # When ssh fabricadmin@$ORG_IP "docker exec ... bash -c \"...\"", the \"...\" is one argument to bash -c.
    # Let's ensure the single quotes for --ctor are correctly passed.
    # The variable $CONSTRUCTOR_ARGS is '{"function":"InitLedger","Args":[]}'
    # So --ctor '$CONSTRUCTOR_ARGS' becomes --ctor ''{"function":"InitLedger","Args":[]}'' which is wrong.
    # We need --ctor '{"function":"InitLedger","Args":[]}'
    # So, inside the bash -c "..." string, we need exactly that.
    # CONSTRUCTOR_ARGS='{"function":"InitLedger","Args":[]}'
    # Then use it as: --ctor "'$CONSTRUCTOR_ARGS'"

    # Execute the commit command
    log "🚢 Executing chaincode commit..."
    log "   Executing on $ORG_IP: docker exec $CLI_CONTAINER bash -c \"$COMMIT_CMD\""
    COMMIT_OUTPUT=$(ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c \"$COMMIT_CMD\"" 2>&1)
    COMMIT_EXIT_CODE=$?
    
    # Log the output
    echo "Commit Output:" >> $LOG_FILE
    echo "$COMMIT_OUTPUT" >> $LOG_FILE
    
    if [ $COMMIT_EXIT_CODE -eq 0 ]; then
        log "✅ Chaincode commit successful"
    else
        log "⛔ Chaincode commit failed with exit code: $COMMIT_EXIT_CODE"
        log "Output: $COMMIT_OUTPUT"
        exit 1
    fi
    
    # Wait for commit to propagate
    log "Waiting for commit to propagate..."
    sleep 5

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
    
# example command to init ledger
# ssh fabricadmin@10.104.0.2 << 'EOF'
# docker exec cli.org1.fabriczakat.local bash -c "peer chaincode invoke \
#   -o orderer.fabriczakat.local:7050 \
#   --ordererTLSHostnameOverride orderer.fabriczakat.local \
#   --tls \
#   --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem \
#   -C zakatchannel \
#   -n zakat \
#   --isInit \
#   -c '{\"function\":\"InitLedger\",\"Args\":[]}' \
#   --peerAddresses peer.org1.fabriczakat.local:7051 \
#   --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/peers/peer.org1.fabriczakat.local/tls/ca.crt \
#   --peerAddresses peer.org2.fabriczakat.local:7051 \
#   --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/peers/peer.org2.fabriczakat.local/tls/ca.crt \
#   --connTimeout 10s"
# EOF
# ssh fabricadmin@10.104.0.2 "docker exec cli.org1.fabriczakat.local bash -c 'peer lifecycle chaincode querycommitted -C zakatchannel -n zakat --output json'"
