#!/bin/bash
# Script 23: Install Chaincode on Peers

set -e # Exit on error

echo "🚀 Installing Chaincode on Peers..."

# Define Organization Details
ORG_NAMES=("Org1" "Org2")
ORG_DOMAINS=("org1.fabriczakat.local" "org2.fabriczakat.local")
ORG_IPS=("10.104.0.2" "10.104.0.4")

# Chaincode package details (must match the package script)
CHAINCODE_NAME="zakat"
CHAINCODE_VERSION="2.1"
CHAINCODE_LABEL="${CHAINCODE_NAME}_${CHAINCODE_VERSION}" # e.g., zakat_2.0
LOCAL_PACKAGE_FILE="$HOME/fabric/chaincode-packages/${CHAINCODE_LABEL}.tar.gz"

# Remote paths on Org machines
REMOTE_FABRIC_DIR="/home/fabricadmin/fabric"
REMOTE_PACKAGE_DIR="$REMOTE_FABRIC_DIR/chaincode-packages"
REMOTE_PACKAGE_FILE="$REMOTE_PACKAGE_DIR/${CHAINCODE_LABEL}.tar.gz"
# Path inside the CLI container where the package will be accessible
# This depends on the volume mounts defined in docker-compose-peer-cli-template.yaml
# We mounted ../chaincode -> /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode
# Let's copy the package to the host's chaincode-packages dir and mount that too, or copy into the mounted chaincode dir.
# Simpler: Copy the package file directly into the CLI container after copying it to the host.
# Alternative: Copy to a location on the host that is mounted into the CLI.
# Let's copy to REMOTE_PACKAGE_DIR on the host, then use that path in the install command.
# The CLI container needs access to this path. Let's adjust the template if needed, or use docker cp.
# Re-checking template: ../chaincode is mounted to /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode
# Let's copy the package to $REMOTE_FABRIC_DIR/chaincode-packages on the host,
# and then use `docker cp` to put it inside the CLI container, e.g., at /opt/gopath/src/
# Or, modify the CLI volume mount to include chaincode-packages. Let's try modifying the mount.

# Log file on the Orderer machine
LOG_DIR="$HOME/fabric/logs"
LOG_FILE="$LOG_DIR/23-install-chaincode.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Chaincode Installation Script (23)"

# Check if local package file exists
log "🔎 Checking for local chaincode package: $LOCAL_PACKAGE_FILE"
if [ ! -f "$LOCAL_PACKAGE_FILE" ]; then
    log "⛔ Error: Local chaincode package not found at $LOCAL_PACKAGE_FILE"
    log "   Run script 22-package-chaincode.sh first."
    exit 1
fi
log "✅ Local chaincode package found."

# Loop through each organization to install the chaincode
for i in ${!ORG_NAMES[@]}; do
    ORG_NAME=${ORG_NAMES[$i]}
    ORG_DOMAIN=${ORG_DOMAINS[$i]}
    ORG_IP=${ORG_IPS[$i]}
    CLI_CONTAINER="cli.${ORG_DOMAIN}"

    log "----------------------------------------"
    log "Processing $ORG_NAME ($ORG_IP)..."
    log "----------------------------------------"

    # --- Step 1: Copy package file to the remote host ---
    log "📦 Copying chaincode package to $ORG_NAME ($ORG_IP)..."
    ssh fabricadmin@$ORG_IP "mkdir -p $REMOTE_PACKAGE_DIR"
    scp "$LOCAL_PACKAGE_FILE" "fabricadmin@$ORG_IP:$REMOTE_PACKAGE_FILE" >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
        log "⛔ Error copying package to $ORG_IP."
        exit 1
    fi
    log "✅ Package copied to $ORG_IP:$REMOTE_PACKAGE_FILE"

    # --- Step 2: Install chaincode using the CLI container ---
    log "⚙️ Installing chaincode on $ORG_NAME peer using $CLI_CONTAINER..."

    # Command to execute inside the Org's CLI container
    # Note: Environment variables like CORE_PEER_ADDRESS are set in the container.
    # The install command uses the peer's admin identity implicitly via CORE_PEER_MSPCONFIGPATH.
    # The path to the package file needs to be accessible *inside* the container.
    # We copied it to the host at $REMOTE_PACKAGE_FILE.
    # Let's use `docker cp` to get it inside the container temporarily.
    CONTAINER_PACKAGE_PATH="/opt/gopath/src/${CHAINCODE_LABEL}.tar.gz" # Temporary path inside CLI

    log "   Copying package into $CLI_CONTAINER..."
    ssh fabricadmin@$ORG_IP "docker cp $REMOTE_PACKAGE_FILE $CLI_CONTAINER:$CONTAINER_PACKAGE_PATH" >> $LOG_FILE 2>&1
     if [ $? -ne 0 ]; then
        log "⛔ Error copying package into container $CLI_CONTAINER on $ORG_IP."
        exit 1
    fi
    log "   ✅ Package copied into container at $CONTAINER_PACKAGE_PATH"

    INSTALL_CMD="peer lifecycle chaincode install $CONTAINER_PACKAGE_PATH"

    log "   Executing on $CLI_CONTAINER@$ORG_IP: $INSTALL_CMD"

    # Execute the install command via SSH + docker exec with timeout
    INSTALL_OUTPUT=$(timeout 300 ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER bash -c '$INSTALL_CMD'" 2>&1)
    INSTALL_EXIT_CODE=$?

    echo "$INSTALL_OUTPUT" >> $LOG_FILE # Log output regardless of success/failure

    if [ $INSTALL_EXIT_CODE -eq 124 ]; then
        log "⛔ Error: Installation timed out after 300 seconds for $ORG_NAME."
        log "   This may indicate network issues or the peer is under heavy load."
        exit 1
    elif [ $INSTALL_EXIT_CODE -ne 0 ]; then
        log "⛔ Error: Failed to install chaincode for $ORG_NAME (exit code: $INSTALL_EXIT_CODE)."
        log "   Check the logs ($LOG_FILE) and the container logs on $ORG_IP: docker logs $CLI_CONTAINER"
        exit 1
    fi

    # Extract Package ID from the output (important for approval step)
    PACKAGE_ID=$(echo "$INSTALL_OUTPUT" | grep -oP 'Chaincode code package identifier: \K(.*)')

    if [ -z "$PACKAGE_ID" ]; then
        log "⚠️ Warning: Could not extract Package ID for $ORG_NAME from install output."
        log "   Install Output: $INSTALL_OUTPUT"
        # Attempt alternative extraction if format changes
        PACKAGE_ID=$(echo "$INSTALL_OUTPUT" | awk '/Chaincode code package identifier:/ {print $NF}')
        if [ -z "$PACKAGE_ID" ]; then
           log "⛔ Error: Still could not extract Package ID. Manual check required."
           exit 1
        fi
         log "   Extracted Package ID (alternative method): $PACKAGE_ID"
    fi

    log "✅ Chaincode installed successfully on $ORG_NAME. Package ID: $PACKAGE_ID"
    # Store package ID for later use (e.g., write to a file)
    echo "$PACKAGE_ID" >> "$LOG_DIR/chaincode_package_ids.txt"
    # Clean up the package file inside the container? Optional.
    # ssh fabricadmin@$ORG_IP "docker exec $CLI_CONTAINER rm $CONTAINER_PACKAGE_PATH"

    sleep 2 # Small delay before processing next org

done

log "🎉 Chaincode installation complete on all specified peers!"
log "----------------------------------------"
# Display extracted package IDs
log "📄 Extracted Package IDs (saved in $LOG_DIR/chaincode_package_ids.txt):"
cat "$LOG_DIR/chaincode_package_ids.txt" | tee -a $LOG_FILE

exit 0
