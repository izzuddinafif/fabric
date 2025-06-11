#!/bin/bash
# Script 18: Deploy Orderer Node

set -e # Exit on error

echo "🚀 Deploying Orderer Node..."

# Define paths and variables
COMPOSE_FILE="$HOME/fabric/docker/docker-compose-orderer.yaml"
GENESIS_BLOCK="$HOME/fabric/channel-artifacts/genesis.block"
ORDERER_MSP_DIR="$HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp"
ORDERER_TLS_DIR="$HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/tls"
LOG_DIR="$HOME/fabric/logs"
LOG_FILE="$LOG_DIR/18-deploy-orderer.log"
ORDERER_CONTAINER_NAME="orderer.fabriczakat.local"
NETWORK_NAME="fabric_network" # As defined in compose file

# Create logs directory if it doesn't exist
mkdir -p $LOG_DIR
touch $LOG_FILE

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Orderer Deployment Script (18)"

# Check if docker and docker compose are installed
log "🔎 Checking for Docker and Docker Compose..."
if ! command -v docker &> /dev/null; then
    log "⛔ Error: docker command not found. Please install Docker."
    exit 1
fi
if ! docker compose version &> /dev/null; then
    log "⛔ Error: docker compose command not found. Please install Docker Compose V2."
    exit 1
fi
log "✅ Docker and Docker Compose found."

# Check for required files and directories
log "🔎 Checking for required artifacts..."
if [ ! -f "$COMPOSE_FILE" ]; then log "⛔ Error: Docker compose file not found at $COMPOSE_FILE"; exit 1; fi
if [ ! -f "$GENESIS_BLOCK" ]; then log "⛔ Error: Genesis block not found at $GENESIS_BLOCK"; exit 1; fi
if [ ! -d "$ORDERER_MSP_DIR" ]; then log "⛔ Error: Orderer MSP directory not found at $ORDERER_MSP_DIR"; exit 1; fi
if [ ! -d "$ORDERER_TLS_DIR" ]; then log "⛔ Error: Orderer TLS directory not found at $ORDERER_TLS_DIR"; exit 1; fi
# Check specifically for TLS certs needed by compose file
if [ ! -f "$ORDERER_TLS_DIR/server.key" ]; then log "⛔ Error: Orderer TLS server key not found in $ORDERER_TLS_DIR"; exit 1; fi
if [ ! -f "$ORDERER_TLS_DIR/server.crt" ]; then log "⛔ Error: Orderer TLS server cert not found in $ORDERER_TLS_DIR"; exit 1; fi
if [ ! -f "$ORDERER_TLS_DIR/ca.crt" ]; then log "⛔ Error: Orderer TLS CA cert not found in $ORDERER_TLS_DIR"; exit 1; fi
log "✅ Required artifacts found."

# Cleanup previous runs
log "🧹 Cleaning up previous Orderer deployment (if any)..."
if [ "$(docker ps -q -f name=^/${ORDERER_CONTAINER_NAME}$)" ]; then
    log "  Stopping container $ORDERER_CONTAINER_NAME..."
    docker stop $ORDERER_CONTAINER_NAME >> $LOG_FILE 2>&1
    log "  Container $ORDERER_CONTAINER_NAME stopped."
fi
if [ "$(docker ps -aq -f name=^/${ORDERER_CONTAINER_NAME}$)" ]; then
    log "  Removing container $ORDERER_CONTAINER_NAME..."
    docker rm $ORDERER_CONTAINER_NAME >> $LOG_FILE 2>&1
    log "  Container $ORDERER_CONTAINER_NAME removed."
fi

# Remove potentially conflicting volumes defined in the compose file
# Check if volumes exist before attempting removal
echo "=== REMOVING ALL VOLUMES ==="
docker volume prune -f
docker volume rm $(docker volume ls -q) 2>/dev/null || true

# Check if the network exists, create if not (though compose should handle this)
log "  Checking for network $NETWORK_NAME..."
if ! docker network inspect $NETWORK_NAME &> /dev/null; then
    log "  Network $NETWORK_NAME not found. Creating..."
    docker network create $NETWORK_NAME >> $LOG_FILE 2>&1
    log "  Network $NETWORK_NAME created."
else
    log "  Network $NETWORK_NAME already exists."
fi
log "✅ Cleanup complete."

# Deploy the orderer
log "🚢 Deploying Orderer using Docker Compose..."
docker compose -f $COMPOSE_FILE up -d >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "⛔ Error deploying Orderer with Docker Compose. Check logs in $LOG_FILE and docker logs $ORDERER_CONTAINER_NAME."
    docker logs $ORDERER_CONTAINER_NAME >> $LOG_FILE 2>&1 # Capture logs on failure
    exit 1
fi

# Verify deployment
log "🔎 Verifying Orderer deployment..."
sleep 5 # Give the container a moment to start

if ! docker ps -f name=^/${ORDERER_CONTAINER_NAME}$ --format "{{.Names}}" | grep -q "^${ORDERER_CONTAINER_NAME}$"; then
    log "⛔ Error: Orderer container $ORDERER_CONTAINER_NAME is not running."
    log "   Check logs in $LOG_FILE and docker logs $ORDERER_CONTAINER_NAME."
    docker logs $ORDERER_CONTAINER_NAME >> $LOG_FILE 2>&1 # Capture logs on failure
    exit 1
fi

log "✅ Orderer container $ORDERER_CONTAINER_NAME is running."
log "🎉 Orderer Node deployed successfully!"
log "----------------------------------------"

exit 0
