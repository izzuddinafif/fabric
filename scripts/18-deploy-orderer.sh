#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/docker-utils.sh"

echo "🚀 Deploying Orderer Node..."

# Define paths and variables
COMPOSE_FILE="$HOME/fabric/docker/docker-compose-orderer.yaml"
GENESIS_BLOCK="$HOME/fabric/channel-artifacts/genesis.block"
ORDERER_MSP_DIR="$HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp"
ORDERER_TLS_DIR="$HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/tls"
LOG_DIR="$HOME/fabric/logs"
LOG_FILE="$LOG_DIR/18-deploy-orderer.log"
ORDERER_CONTAINER_NAME="orderer.fabriczakat.local"
NETWORK_NAME="fabric_network"

# Create logs directory and file
mkdir -p $LOG_DIR
touch $LOG_FILE

log_msg "$LOG_FILE" "Starting Orderer Deployment Script (18)"

# Check Docker installation
log_msg "$LOG_FILE" "🔎 Checking for Docker and Docker Compose..."
if ! verify_docker_installation; then
    log_msg "$LOG_FILE" "⛔ Docker verification failed"
    exit 1
fi
log_msg "$LOG_FILE" "✅ Docker and Docker Compose found."

# Check for required files and directories
log_msg "$LOG_FILE" "🔎 Checking for required artifacts..."
if ! verify_orderer_artifacts "$COMPOSE_FILE" "$GENESIS_BLOCK" "$ORDERER_MSP_DIR" "$ORDERER_TLS_DIR"; then
    log_msg "$LOG_FILE" "⛔ Required artifacts verification failed"
    exit 1
fi
log_msg "$LOG_FILE" "✅ Required artifacts found."

# Cleanup previous deployment
log_msg "$LOG_FILE" "🧹 Cleaning up previous Orderer deployment (if any)..."

# Clean up container
cleanup_container "$ORDERER_CONTAINER_NAME" "$LOG_FILE"

# Clean up volumes
VOLUMES=("orderer_ledger" "orderer_etcdraft_wal" "orderer_etcdraft_snapshot" "$LOG_FILE")
cleanup_volumes "${VOLUMES[@]}"

# Ensure network exists
ensure_network "$NETWORK_NAME" "$LOG_FILE"

log_msg "$LOG_FILE" "✅ Cleanup complete."

# Deploy the orderer
if ! deploy_compose_service "$COMPOSE_FILE" "$ORDERER_CONTAINER_NAME" "$LOG_FILE"; then
    log_msg "$LOG_FILE" "⛔ Failed to deploy orderer. Check the logs."
    exit 1
fi

# Wait for container to be ready
log_msg "$LOG_FILE" "⏳ Waiting for orderer container to be ready..."
if ! wait_for_container "$ORDERER_CONTAINER_NAME" 30; then
    log_msg "$LOG_FILE" "⛔ Orderer container failed to start properly"
    docker logs "$ORDERER_CONTAINER_NAME" >> "$LOG_FILE" 2>&1
    exit 1
fi

log_msg "$LOG_FILE" "🎉 Orderer Node deployed successfully!"
log_msg "$LOG_FILE" "----------------------------------------"

exit 0
