#!/bin/bash
# Script 19: Deploy Org Peers & CLIs via SSH

set -e # Exit on error

echo "🚀 Deploying Org Peers & CLIs..."

# Define Organization Details
ORG_NAMES=("Org1" "Org2")
ORG_DOMAINS=("org1.fabriczakat.local" "org2.fabriczakat.local")
ORG_IPS=("10.104.0.2" "10.104.0.4")
PEER_PORTS=("7051" "7051") # Standard peer port, can be same on different hosts
CC_PORTS=("7052" "7052")   # Standard chaincode port
OPS_PORTS=("9445" "9445")

# Orderer details (needed for extra_hosts and CLI config)
ORDERER_IP="10.104.0.3"
ORDERER_DOMAIN="fabriczakat.local"

# Local paths on the Orderer machine (where this script runs)
LOCAL_FABRIC_DIR="$HOME/fabric"
LOCAL_COMPOSE_TEMPLATE="$LOCAL_FABRIC_DIR/docker/docker-compose-peer-cli-template.yaml"
LOCAL_ORG_DIR="$LOCAL_FABRIC_DIR/organizations"
LOCAL_CHANNEL_ARTIFACTS_DIR="$LOCAL_FABRIC_DIR/channel-artifacts"
LOCAL_CHAINCODE_DIR="$LOCAL_FABRIC_DIR/chaincode"

# Remote paths on Org machines
REMOTE_FABRIC_DIR="/home/fabricadmin/fabric" # Assuming same user and base path
REMOTE_DOCKER_DIR="$REMOTE_FABRIC_DIR/docker"
REMOTE_ORG_DIR="$REMOTE_FABRIC_DIR/organizations"
REMOTE_CHANNEL_ARTIFACTS_DIR="$REMOTE_FABRIC_DIR/channel-artifacts"
REMOTE_CHAINCODE_DIR="$REMOTE_FABRIC_DIR/chaincode"
REMOTE_LOG_DIR="$REMOTE_FABRIC_DIR/logs"

# Log file on the Orderer machine
LOG_DIR="$LOCAL_FABRIC_DIR/logs"
LOG_FILE="$LOG_DIR/19-deploy-peers-clis.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Peer/CLI Deployment Script (19)"

# Check if local template file exists
log "🔎 Checking for local compose template: $LOCAL_COMPOSE_TEMPLATE"
if [ ! -f "$LOCAL_COMPOSE_TEMPLATE" ]; then
    log "⛔ Error: Local Docker compose template not found at $LOCAL_COMPOSE_TEMPLATE"
    exit 1
fi
log "✅ Local compose template found."

# Check if local organizations directory exists
log "🔎 Checking for local organizations directory: $LOCAL_ORG_DIR"
if [ ! -d "$LOCAL_ORG_DIR" ]; then
    log "⛔ Error: Local organizations directory not found at $LOCAL_ORG_DIR"
    exit 1
fi
log "✅ Local organizations directory found."

# Check if local channel artifacts directory exists
log "🔎 Checking for local channel artifacts directory: $LOCAL_CHANNEL_ARTIFACTS_DIR"
if [ ! -d "$LOCAL_CHANNEL_ARTIFACTS_DIR" ]; then
    log "⛔ Error: Local channel artifacts directory not found at $LOCAL_CHANNEL_ARTIFACTS_DIR"
    exit 1
fi
log "✅ Local channel artifacts directory found."

# Check if local chaincode directory exists
log "🔎 Checking for local chaincode directory: $LOCAL_CHAINCODE_DIR"
if [ ! -d "$LOCAL_CHAINCODE_DIR" ]; then
    log "⛔ Error: Local chaincode directory not found at $LOCAL_CHAINCODE_DIR"
    exit 1
fi
log "✅ Local chaincode directory found."


# Loop through each organization
for i in ${!ORG_NAMES[@]}; do
    ORG_NAME=${ORG_NAMES[$i]}
    ORG_DOMAIN=${ORG_DOMAINS[$i]}
    ORG_IP=${ORG_IPS[$i]}
    PEER_PORT=${PEER_PORTS[$i]}
    CC_PORT=${CC_PORTS[$i]}
    OPS_PORT=${OPS_PORTS[$i]}
    REMOTE_COMPOSE_FILE="$REMOTE_DOCKER_DIR/docker-compose-${ORG_NAME}.yaml" # Org-specific compose file name
    REMOTE_LOG_FILE_ORG="$REMOTE_LOG_DIR/deploy-${ORG_NAME}.log"

    log "----------------------------------------"
    log "Processing $ORG_NAME ($ORG_IP)..."
    log "----------------------------------------"

    # Define IPs for extra_hosts dynamically
    ORG1_IP=${ORG_IPS[0]}
    ORG2_IP=${ORG_IPS[1]}

    # --- Step 1: Copy required files to the remote machine ---
    log "📦 Copying required files to $ORG_NAME ($ORG_IP)..."

    # Create remote directories first via SSH
    log "  Creating remote directories..."
    ssh fabricadmin@$ORG_IP "mkdir -p $REMOTE_FABRIC_DIR $REMOTE_DOCKER_DIR $REMOTE_ORG_DIR $REMOTE_CHANNEL_ARTIFACTS_DIR $REMOTE_CHAINCODE_DIR $REMOTE_LOG_DIR && touch $REMOTE_LOG_FILE_ORG"
    if [ $? -ne 0 ]; then log "⛔ Error creating remote directories on $ORG_IP"; exit 1; fi
    log "  ✅ Remote directories ensured."

    # Copy Compose Template
    log "  Copying compose template..."
    scp $LOCAL_COMPOSE_TEMPLATE fabricadmin@$ORG_IP:$REMOTE_DOCKER_DIR/docker-compose-peer-cli-template.yaml >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then log "⛔ Error copying compose template to $ORG_IP"; exit 1; fi

    # Copy Organizations (Current Org + Orderer Org)
    log "  Copying organization MSP/TLS data..."
    scp -r $LOCAL_ORG_DIR/peerOrganizations/$ORG_DOMAIN fabricadmin@$ORG_IP:$REMOTE_ORG_DIR/peerOrganizations/ >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then log "⛔ Error copying $ORG_NAME peer org data to $ORG_IP"; exit 1; fi
    # Ensure the orderer org dir exists remotely before copying into it
    ssh fabricadmin@$ORG_IP "mkdir -p $REMOTE_ORG_DIR/ordererOrganizations/"
    scp -r $LOCAL_ORG_DIR/ordererOrganizations/$ORDERER_DOMAIN fabricadmin@$ORG_IP:$REMOTE_ORG_DIR/ordererOrganizations/ >> $LOG_FILE 2>&1
     if [ $? -ne 0 ]; then log "⛔ Error copying orderer org data to $ORG_IP"; exit 1; fi

    # Copy Channel Artifacts
    log "  Copying channel artifacts..."
    scp -r $LOCAL_CHANNEL_ARTIFACTS_DIR fabricadmin@$ORG_IP:$REMOTE_FABRIC_DIR/ >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then log "⛔ Error copying channel artifacts to $ORG_IP"; exit 1; fi

    # Copy Chaincode
    log "  Copying chaincode..."
    scp -r $LOCAL_CHAINCODE_DIR fabricadmin@$ORG_IP:$REMOTE_FABRIC_DIR/ >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then log "⛔ Error copying chaincode to $ORG_IP"; exit 1; fi

    log "✅ Files copied successfully to $ORG_NAME ($ORG_IP)."

    # --- Step 2: Execute deployment steps remotely via SSH ---
    log "⚙️ Executing deployment steps on $ORG_NAME ($ORG_IP)..."
    ssh fabricadmin@$ORG_IP "
        set -e # Exit on error within SSH command

        echo \"🚀 Executing deployment tasks for $ORG_NAME on \$(hostname) ($ORG_IP)...\"

        # Create remote directories
        echo \"📁 Creating remote directories...\"
        mkdir -p $REMOTE_FABRIC_DIR $REMOTE_DOCKER_DIR $REMOTE_ORG_DIR $REMOTE_CHANNEL_ARTIFACTS_DIR $REMOTE_CHAINCODE_DIR $REMOTE_LOG_DIR
        touch $REMOTE_LOG_FILE_ORG
        echo \"✅ Remote directories created.\"

        # Log function for remote execution
        remote_log() {
            echo \"\$(date '+%Y-%m-%d %H:%M:%S') - \$1\" | tee -a $REMOTE_LOG_FILE_ORG
        }

        remote_log \"Starting remote deployment for $ORG_NAME\"

        # Check for Docker and Docker Compose remotely
        remote_log \"🔎 Checking for Docker and Docker Compose...\"
        if ! command -v docker &> /dev/null; then remote_log \"⛔ Error: docker command not found.\"; exit 1; fi
        if ! docker compose version &> /dev/null; then remote_log \"⛔ Error: docker compose command not found.\"; exit 1; fi
        remote_log \"✅ Docker and Docker Compose found.\"

        # Cleanup previous runs
        PEER_CONTAINER_NAME=\"peer.$ORG_DOMAIN\"
        CLI_CONTAINER_NAME=\"cli.$ORG_DOMAIN\"
        NETWORK_NAME=\"fabric_network\" # Must match compose file

        remote_log \"🧹 Cleaning up previous $ORG_NAME deployment (if any)...\"
        # Stop and remove containers if they exist
        for container in \$PEER_CONTAINER_NAME \$CLI_CONTAINER_NAME; do
            if [ \"\$(docker ps -q -f name=^\${container}\$)\" ]; then
                remote_log \"  Stopping container \$container...\"
                docker stop \$container >> $REMOTE_LOG_FILE_ORG 2>&1
                remote_log \"  Container \$container stopped.\"
            fi
            if [ \"\$(docker ps -aq -f name=^\${container}\$)\" ]; then
                remote_log \"  Removing container \$container...\"
                docker rm \$container >> $REMOTE_LOG_FILE_ORG 2>&1
                remote_log \"  Container \$container removed.\"
            fi
        done

        # Remove potentially conflicting volumes
        remote_log \"  Checking for existing volumes...\"
        VOLUMES_TO_REMOVE=(\"peer.${ORG_DOMAIN}_data\" \"peer.${ORG_DOMAIN}_couchdb_data\") # Add couchdb if used
        for vol in \"\${VOLUMES_TO_REMOVE[@]}\"; do
            if docker volume inspect \$vol &> /dev/null; then
                remote_log \"  Removing volume \$vol...\"
                docker volume rm \$vol >> $REMOTE_LOG_FILE_ORG 2>&1
                remote_log \"  Volume \$vol removed.\"
            else
                remote_log \"  Volume \$vol does not exist, skipping removal.\"
            fi
        done

        # Ensure the network exists (it should have been created by orderer or manually)
        remote_log \"  Checking for network \$NETWORK_NAME...\"
        if ! docker network inspect \$NETWORK_NAME &> /dev/null; then
            remote_log \"  ⚠️ Network \$NETWORK_NAME not found. Creating... (Ideally created beforehand)\"
            docker network create \$NETWORK_NAME >> $REMOTE_LOG_FILE_ORG 2>&1
            remote_log \"  Network \$NETWORK_NAME created.\"
        else
            remote_log \"  Network \$NETWORK_NAME already exists.\"
        fi
        remote_log \"✅ Remote cleanup complete.\"

        # Substitute variables in the template file (copied in the next step)
        # Export variables needed by envsubst
        export ORG_NAME=$ORG_NAME
        export ORG_DOMAIN=$ORG_DOMAIN
        export PEER_PORT=$PEER_PORT
        export CC_PORT=$CC_PORT
        export PEER_OPERATIONS_PORT=$OPS_PORT
        export ORDERER_IP=$ORDERER_IP
        export ORG1_IP=$ORG1_IP
        export ORG2_IP=$ORG2_IP

        remote_log \"📝 Substituting variables into compose template...\"
        # Use single quotes for envsubst pattern to prevent local shell expansion
        envsubst '\${ORG_NAME} \${ORG_DOMAIN} \${PEER_PORT} \${CC_PORT} \${PEER_OPERATIONS_PORT} \${ORDERER_IP} \${ORG1_IP} \${ORG2_IP}' < $REMOTE_DOCKER_DIR/docker-compose-peer-cli-template.yaml > $REMOTE_COMPOSE_FILE
        if [ \$? -ne 0 ]; then remote_log \"⛔ Error substituting variables.\"; exit 1; fi
        remote_log \"✅ Compose file created: $REMOTE_COMPOSE_FILE\"

        # Deploy Peer and CLI
        remote_log \"🚢 Deploying $ORG_NAME Peer and CLI using Docker Compose...\"
        docker compose -f $REMOTE_COMPOSE_FILE up -d >> $REMOTE_LOG_FILE_ORG 2>&1
        if [ \$? -ne 0 ]; then
            remote_log \"⛔ Error deploying $ORG_NAME containers. Check logs: $REMOTE_LOG_FILE_ORG and docker logs.\"
            docker logs \$PEER_CONTAINER_NAME >> $REMOTE_LOG_FILE_ORG 2>&1 || true # Capture logs if container exists
            docker logs \$CLI_CONTAINER_NAME >> $REMOTE_LOG_FILE_ORG 2>&1 || true
            exit 1
        fi

        # Verify deployment
        remote_log \"🔎 Verifying $ORG_NAME deployment...\"
        sleep 5 # Give containers time to start

        if ! docker ps -f name=^\${PEER_CONTAINER_NAME}\$ --format '{{.Names}}' | grep -q \"^\${PEER_CONTAINER_NAME}\$\"; then
            remote_log \"⛔ Error: Peer container \$PEER_CONTAINER_NAME is not running.\"
            docker logs \$PEER_CONTAINER_NAME >> $REMOTE_LOG_FILE_ORG 2>&1 || true
            exit 1
        fi
        remote_log \"✅ Peer container \$PEER_CONTAINER_NAME is running.\"

        if ! docker ps -f name=^\${CLI_CONTAINER_NAME}\$ --format '{{.Names}}' | grep -q \"^\${CLI_CONTAINER_NAME}\$\"; then
            remote_log \"⛔ Error: CLI container \$CLI_CONTAINER_NAME is not running.\"
            docker logs \$CLI_CONTAINER_NAME >> $REMOTE_LOG_FILE_ORG 2>&1 || true
            exit 1
        fi
        remote_log \"✅ CLI container \$CLI_CONTAINER_NAME is running.\"

        remote_log \"🎉 $ORG_NAME Peer and CLI deployed successfully!\"
        remote_log \"----------------------------------------\"

    " # End of SSH command block

    # Check SSH command exit status
    if [ $? -ne 0 ]; then
        log "⛔ SSH command failed for $ORG_NAME ($ORG_IP). Check remote logs: $REMOTE_LOG_FILE_ORG"
        # Attempt to retrieve remote log file for debugging
        scp fabricadmin@$ORG_IP:$REMOTE_LOG_FILE_ORG ${LOG_DIR}/FAILED_deploy-${ORG_NAME}.log || log "⚠️ Failed to retrieve remote log file ${REMOTE_LOG_FILE_ORG}"
        exit 1
    fi

    log "✅ Successfully deployed Peer and CLI for $ORG_NAME ($ORG_IP)."

done

log "🎉 All Peers and CLIs deployed successfully!"
log "----------------------------------------"

exit 0
