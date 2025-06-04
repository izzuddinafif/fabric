#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/peer-utils.sh"

echo "🚀 Deploying Org Peers & CLIs..."

# Define paths
LOCAL_FABRIC_DIR="$HOME/fabric"
LOCAL_COMPOSE_TEMPLATE="$LOCAL_FABRIC_DIR/docker/docker-compose-peer-cli-template.yaml"
LOCAL_ORG_DIR="$LOCAL_FABRIC_DIR/organizations"
LOCAL_CHANNEL_ARTIFACTS_DIR="$LOCAL_FABRIC_DIR/channel-artifacts"
LOCAL_CHAINCODE_DIR="$LOCAL_FABRIC_DIR/chaincode"

# Orderer details
ORDERER_IP="10.104.0.3"
ORDERER_DOMAIN="fabriczakat.local"

# Setup logging
LOG_DIR="$LOCAL_FABRIC_DIR/logs"
LOG_FILE="$LOG_DIR/19-deploy-peers-clis.log"
mkdir -p $LOG_DIR
touch $LOG_FILE

log_msg "$LOG_FILE" "Starting Peer/CLI Deployment Script (19)"

# Verify local files exist
log_msg "$LOG_FILE" "🔎 Checking for required local files..."
for dir in "$LOCAL_COMPOSE_TEMPLATE" "$LOCAL_ORG_DIR" "$LOCAL_CHANNEL_ARTIFACTS_DIR" "$LOCAL_CHAINCODE_DIR"; do
    if [ ! -e "$dir" ]; then
        log_msg "$LOG_FILE" "⛔ Error: Local file/directory not found: $dir"
        exit 1
    fi
done
log_msg "$LOG_FILE" "✅ Local files verified."

# Process each organization
for i in ${!ORG_NAMES[@]}; do
    ORG_NAME=${ORG_NAMES[$i]}
    ORG_DOMAIN=${ORG_DOMAINS[$i]}
    ORG_IP=${ORG_IPS[$i]}
    PEER_PORT=${PEER_PORTS[$i]}
    CC_PORT=${CC_PORTS[$i]}
    OPS_PORT=${OPS_PORTS[$i]}
    REMOTE_COMPOSE_FILE="$REMOTE_DOCKER_DIR/docker-compose-${ORG_NAME}.yaml"
    REMOTE_LOG_FILE="$REMOTE_LOG_DIR/deploy-${ORG_NAME}.log"

    log_msg "$LOG_FILE" "----------------------------------------"
    log_msg "$LOG_FILE" "Processing $ORG_NAME ($ORG_IP)..."
    log_msg "$LOG_FILE" "----------------------------------------"

    # Copy required files
    if ! copy_peer_artifacts "$ORG_NAME" "$ORG_IP" "$LOCAL_FABRIC_DIR" "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to copy artifacts to $ORG_NAME ($ORG_IP)"
        exit 1
    fi
    log_msg "$LOG_FILE" "✅ Files copied successfully to $ORG_NAME ($ORG_IP)."

    # Verify prerequisites on remote host
    if ! verify_peer_prerequisites "$ORG_IP" "$LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Prerequisites check failed for $ORG_NAME ($ORG_IP)"
        exit 1
    fi
    log_msg "$LOG_FILE" "✅ Prerequisites verified on $ORG_NAME ($ORG_IP)."

    # Create org-specific compose file
    log_msg "$LOG_FILE" "📝 Creating compose file for $ORG_NAME..."
    if ! create_org_compose_file \
        "$ORG_NAME" \
        "$ORG_DOMAIN" \
        "$ORG_IP" \
        "$PEER_PORT" \
        "$CC_PORT" \
        "$OPS_PORT" \
        "$ORDERER_IP" \
        "$REMOTE_COMPOSE_FILE" \
        "$REMOTE_DOCKER_DIR/docker-compose-peer-cli-template.yaml"; then
        log_msg "$LOG_FILE" "⛔ Failed to create compose file for $ORG_NAME"
        exit 1
    fi
    log_msg "$LOG_FILE" "✅ Compose file created for $ORG_NAME."

    # Deploy peer and CLI
    log_msg "$LOG_FILE" "🚢 Deploying $ORG_NAME peer and CLI..."
    if ! deploy_peer_and_cli \
        "$ORG_NAME" \
        "$ORG_DOMAIN" \
        "$ORG_IP" \
        "$REMOTE_COMPOSE_FILE" \
        "$REMOTE_LOG_FILE"; then
        log_msg "$LOG_FILE" "⛔ Failed to deploy peer and CLI for $ORG_NAME"
        # Try to fetch remote logs for debugging
        scp_file "$ORG_IP:$REMOTE_LOG_FILE" "$LOG_DIR/FAILED_deploy-${ORG_NAME}.log" || true
        exit 1
    fi

    log_msg "$LOG_FILE" "✅ Successfully deployed Peer and CLI for $ORG_NAME ($ORG_IP)."
done

log_msg "$LOG_FILE" "🎉 All Peers and CLIs deployed successfully!"
log_msg "$LOG_FILE" "----------------------------------------"

exit 0
