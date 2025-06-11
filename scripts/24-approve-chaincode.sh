#!/bin/bash
    # Script 24: Approve Chaincode Definition for Orgs

    set -e # Exit on error

    echo "🚀 Approving Chaincode Definition..."

    # Define Organization Details
    ORG_NAMES=("Org1" "Org2")
    ORG_DOMAINS=("org1.fabriczakat.local" "org2.fabriczakat.local")
    ORG_IPS=("10.104.0.2" "10.104.0.4")
    ORG_MSPS=("Org1MSP" "Org2MSP")

    # Channel details
    CHANNEL_NAME="zakatchannel"

    # Chaincode definition details
    CHAINCODE_NAME="zakat"
    CHAINCODE_VERSION="2.1"
    # Endorsement policy: Requires endorsement from a member of both Org1 and Org2
    ENDORSEMENT_POLICY="AND('Org1MSP.member', 'Org2MSP.member')"
    # Collection config (if any, leave empty if none)
    COLLECTION_CONFIG="" # Example: --collections-config /path/to/collections.json
    # Init required flag (use if chaincode has an Init function, like InitLedger)
    INIT_REQUIRED="--init-required" # Use "--init-required" or ""

    # Orderer details (as seen from within the CLI containers)
    ORDERER_ADDRESS="orderer.fabriczakat.local:7050"
    ORDERER_CA_CERT="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem" # Path inside CLI container

    # Log file on the Orderer machine
    LOG_DIR="$HOME/fabric/logs"
    LOG_FILE="$LOG_DIR/24-approve-chaincode.log"
    mkdir -p $LOG_DIR
    # Clear the log file for the new attempt
    > $LOG_FILE

    # Function to log messages
    log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
    }
    
    # Auto-detect Package ID from the install step (script 23)
    PACKAGE_ID_FILE="$HOME/fabric/logs/chaincode_package_ids.txt"
    if [ -f "$PACKAGE_ID_FILE" ]; then
        PACKAGE_ID=$(tail -1 "$PACKAGE_ID_FILE" | sed 's/^=//')
        log "Auto-detected Package ID: $PACKAGE_ID"
    else
        log "⛔ Error: Package ID file not found. Run script 23 (install-chaincode) first."
        exit 1
    fi
    
    if [ -z "$PACKAGE_ID" ]; then
        log "⛔ Error: Could not extract Package ID from $PACKAGE_ID_FILE"
        exit 1
    fi
    
    # Auto-detect next sequence number by querying current committed sequence
    CLI_CONTAINER_TEMP="cli.org1.fabriczakat.local"
    ORG_IP_TEMP="10.104.0.2"
    CURRENT_SEQUENCE=$(ssh fabricadmin@$ORG_IP_TEMP "docker exec $CLI_CONTAINER_TEMP bash -c 'peer lifecycle chaincode querycommitted -C $CHANNEL_NAME -n $CHAINCODE_NAME --output json'" 2>/dev/null | grep -o '"sequence": [0-9]*' | awk '{print $2}' || echo "0")
    SEQUENCE=$((CURRENT_SEQUENCE + 1))
    log "Current sequence: $CURRENT_SEQUENCE, Using sequence: $SEQUENCE"

    log "Starting Chaincode Approval Script (24) - Auto-detecting Package ID and Sequence"
    log "Chaincode Name: $CHAINCODE_NAME"
    log "Version: $CHAINCODE_VERSION"
    log "Sequence: $SEQUENCE"
    log "Package ID: $PACKAGE_ID"
    log "Policy: $ENDORSEMENT_POLICY"
    log "Init Required: ${INIT_REQUIRED:-false}" # Display 'false' if empty

    # Loop through each organization to approve the chaincode definition
    for i in ${!ORG_NAMES[@]}; do
        ORG_NAME=${ORG_NAMES[$i]}
        ORG_DOMAIN=${ORG_DOMAINS[$i]}
        ORG_IP=${ORG_IPS[$i]}
        ORG_MSP=${ORG_MSPS[$i]}
        CLI_CONTAINER="cli.${ORG_DOMAIN}"

        log "----------------------------------------"
        log "Approving for $ORG_NAME ($ORG_IP)..."
        log "----------------------------------------"

        # Command string construction - Escape the double quotes around the policy variable
        APPROVE_CMD="peer lifecycle chaincode approveformyorg \
            -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local \
            --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version $CHAINCODE_VERSION \
            --package-id $PACKAGE_ID --sequence $SEQUENCE \
            $INIT_REQUIRED \
            --signature-policy \\\"$ENDORSEMENT_POLICY\\\" \
            $COLLECTION_CONFIG \
            --tls --cafile $ORDERER_CA_CERT"

        # Construct the full command to be executed remotely via bash -c "..."
        # Use double quotes around the bash -c argument for SSH
        FULL_REMOTE_CMD="docker exec $CLI_CONTAINER bash -c \"$APPROVE_CMD\""

        log "Executing on $ORG_IP: $FULL_REMOTE_CMD"

        # Execute the command via SSH
        ssh fabricadmin@$ORG_IP "$FULL_REMOTE_CMD" >> $LOG_FILE 2>&1

        if [ $? -ne 0 ]; then
            log "⛔ Error: Failed to approve chaincode for $ORG_NAME."
            log "   Check the logs ($LOG_FILE) and the container logs on $ORG_IP: docker logs $CLI_CONTAINER"
            # Optionally, try to query the committed definition to see if it somehow succeeded despite error code
            log "   Attempting to query committed definition on $ORG_NAME..."
            QUERY_COMMITTED_CMD="peer lifecycle chaincode querycommitted -C $CHANNEL_NAME -n $CHAINCODE_NAME --output json"
            ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c '$QUERY_COMMITTED_CMD'" >> $LOG_FILE 2>&1 || true # Keep single quotes for simple query
            exit 1
        fi

        log "✅ Chaincode definition approved successfully by $ORG_NAME."

        # Optional: Verify approval status immediately
        log "🔎 Verifying approval status for $ORG_NAME..."
        QUERY_APPROVED_CMD="peer lifecycle chaincode queryapproved -C $CHANNEL_NAME -n $CHAINCODE_NAME --sequence $SEQUENCE --output json"
        log "   Executing on $CLI_CONTAINER@$ORG_IP: $QUERY_APPROVED_CMD"
        # Keep single quotes for simple query
        APPROVAL_STATUS=$(ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c '$QUERY_APPROVED_CMD'" 2>&1)
        echo "Approval Status for $ORG_NAME:" >> $LOG_FILE
        echo "$APPROVAL_STATUS" >> $LOG_FILE
        # Basic check - look for the sequence number in the JSON output
        if ! echo "$APPROVAL_STATUS" | grep -q "\"sequence\": $SEQUENCE"; then
             log "⚠️ Warning: Could not verify approval status for $ORG_NAME via queryapproved. Check logs."
        else
             log "✅ Approval status verified for $ORG_NAME."
        fi

        sleep 2 # Small delay before processing next org
    done

    log "🎉 Chaincode definition approved by all specified organizations!"
    log "----------------------------------------"

    exit 0
