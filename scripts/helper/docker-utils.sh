#!/bin/bash

# Logging function
# Arguments:
#   $1: Log file path
#   $2: Message
log_msg() {
    local log_file=$1
    local message=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$log_file"
}

# Verify Docker and Docker Compose installation
verify_docker_installation() {
    if ! command -v docker &> /dev/null; then
        echo "⛔ Error: docker command not found. Please install Docker."
        return 1
    fi
    if ! docker compose version &> /dev/null; then
        echo "⛔ Error: docker compose command not found. Please install Docker Compose V2."
        return 1
    fi
    return 0
}

# Verify required directories and files for orderer deployment
# Arguments:
#   $1: Compose file path
#   $2: Genesis block path
#   $3: Orderer MSP directory
#   $4: Orderer TLS directory
verify_orderer_artifacts() {
    local compose_file=$1
    local genesis_block=$2
    local msp_dir=$3
    local tls_dir=$4
    
    # Check compose file and genesis block
    if [ ! -f "$compose_file" ]; then echo "⛔ Error: Docker compose file not found at $compose_file"; return 1; fi
    if [ ! -f "$genesis_block" ]; then echo "⛔ Error: Genesis block not found at $genesis_block"; return 1; fi
    
    # Check MSP and TLS directories
    if [ ! -d "$msp_dir" ]; then echo "⛔ Error: Orderer MSP directory not found at $msp_dir"; return 1; fi
    if [ ! -d "$tls_dir" ]; then echo "⛔ Error: Orderer TLS directory not found at $tls_dir"; return 1; fi
    
    # Check TLS certificates
    if [ ! -f "$tls_dir/server.key" ]; then echo "⛔ Error: Orderer TLS server key not found in $tls_dir"; return 1; fi
    if [ ! -f "$tls_dir/server.crt" ]; then echo "⛔ Error: Orderer TLS server cert not found in $tls_dir"; return 1; fi
    if [ ! -f "$tls_dir/ca.crt" ]; then echo "⛔ Error: Orderer TLS CA cert not found in $tls_dir"; return 1; fi
    
    return 0
}

# Clean up Docker container
# Arguments:
#   $1: Container name
#   $2: Log file path
cleanup_container() {
    local container=$1
    local log_file=$2
    
    if [ "$(docker ps -q -f name=^/${container}$)" ]; then
        log_msg "$log_file" "  Stopping container $container..."
        docker stop "$container" >> "$log_file" 2>&1
        log_msg "$log_file" "  Container $container stopped."
    fi
    
    if [ "$(docker ps -aq -f name=^/${container}$)" ]; then
        log_msg "$log_file" "  Removing container $container..."
        docker rm "$container" >> "$log_file" 2>&1
        log_msg "$log_file" "  Container $container removed."
    fi
}

# Clean up Docker volumes
# Arguments:
#   $1: Array of volume names
#   $2: Log file path
cleanup_volumes() {
    local volumes=("$@")
    local log_file="${volumes[-1]}" # Last argument is log file
    unset 'volumes[${#volumes[@]}-1]' # Remove log file from array
    
    log_msg "$log_file" "  Checking for existing volumes..."
    for vol in "${volumes[@]}"; do
        if docker volume inspect "$vol" &> /dev/null; then
            log_msg "$log_file" "  Removing volume $vol..."
            docker volume rm "$vol" >> "$log_file" 2>&1
            log_msg "$log_file" "  Volume $vol removed."
        else
            log_msg "$log_file" "  Volume $vol does not exist, skipping removal."
        fi
    done
}

# Create or verify Docker network exists
# Arguments:
#   $1: Network name
#   $2: Log file path
ensure_network() {
    local network=$1
    local log_file=$2
    
    log_msg "$log_file" "  Checking for network $network..."
    if ! docker network inspect "$network" &> /dev/null; then
        log_msg "$log_file" "  Network $network not found. Creating..."
        docker network create "$network" >> "$log_file" 2>&1
        log_msg "$log_file" "  Network $network created."
    else
        log_msg "$log_file" "  Network $network already exists."
    fi
}

# Deploy service using Docker Compose
# Arguments:
#   $1: Compose file path
#   $2: Container name to verify
#   $3: Log file path
deploy_compose_service() {
    local compose_file=$1
    local container_name=$2
    local log_file=$3
    
    log_msg "$log_file" "🚢 Deploying service using Docker Compose..."
    docker compose -f "$compose_file" up -d >> "$log_file" 2>&1
    
    # Give the container a moment to start
    sleep 5
    
    # Verify deployment
    log_msg "$log_file" "🔎 Verifying deployment..."
    if ! docker ps -f name=^/${container_name}$ --format "{{.Names}}" | grep -q "^${container_name}$"; then
        log_msg "$log_file" "⛔ Error: Container $container_name is not running."
        log_msg "$log_file" "   Check logs in $log_file and docker logs $container_name"
        docker logs "$container_name" >> "$log_file" 2>&1
        return 1
    fi
    
    log_msg "$log_file" "✅ Container $container_name is running."
    return 0
}

# Verify container is healthy
# Arguments:
#   $1: Container name
#   $2: Wait time in seconds (optional, default 30)
wait_for_container() {
    local container=$1
    local wait_time=${2:-30}
    local counter=0
    
    while [ $counter -lt $wait_time ]; do
        if [ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)" == "true" ]; then
            return 0
        fi
        sleep 1
        ((counter++))
    done
    
    return 1
}
