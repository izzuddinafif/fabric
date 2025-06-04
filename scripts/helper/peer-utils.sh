#!/bin/bash

# Source Docker and SSH utilities
source "$(dirname "$0")/docker-utils.sh"
source "$(dirname "$0")/ssh-utils.sh"

# ORG details - these should come from config later
ORG_NAMES=("Org1" "Org2")
ORG_DOMAINS=("org1.fabriczakat.local" "org2.fabriczakat.local")
ORG_IPS=("10.104.0.2" "10.104.0.4")
PEER_PORTS=("7051" "7051")
CC_PORTS=("7052" "7052")
OPS_PORTS=("9443" "9444")

# Remote standard paths
REMOTE_FABRIC_DIR="/home/fabricadmin/fabric"
REMOTE_DOCKER_DIR="$REMOTE_FABRIC_DIR/docker"
REMOTE_ORG_DIR="$REMOTE_FABRIC_DIR/organizations"
REMOTE_CHANNEL_ARTIFACTS_DIR="$REMOTE_FABRIC_DIR/channel-artifacts"
REMOTE_CHAINCODE_DIR="$REMOTE_FABRIC_DIR/chaincode"
REMOTE_LOG_DIR="$REMOTE_FABRIC_DIR/logs"

# Copy required files for peer deployment
# Arguments:
#   $1: Organization name
#   $2: Organization IP
#   $3: Local fabric directory
#   $4: Remote log file
copy_peer_artifacts() {
    local org_name=$1
    local org_ip=$2
    local local_dir=$3
    local remote_log=$4
    local org_domain="${org_name,,}.fabriczakat.local"

    log_msg "$remote_log" "📦 Copying required files to $org_name ($org_ip)..."

    # Create remote directories
    ssh_exec "$org_ip" "mkdir -p $REMOTE_DOCKER_DIR $REMOTE_ORG_DIR $REMOTE_CHANNEL_ARTIFACTS_DIR $REMOTE_CHAINCODE_DIR $REMOTE_LOG_DIR" || return 1

    # Copy file sets
    scp_file "$local_dir/docker/docker-compose-peer-cli-template.yaml" "$org_ip" "$REMOTE_DOCKER_DIR/" || return 1
    scp_file "$local_dir/organizations/peerOrganizations/$org_domain" "$org_ip" "$REMOTE_ORG_DIR/peerOrganizations/" || return 1
    scp_file "$local_dir/organizations/ordererOrganizations" "$org_ip" "$REMOTE_ORG_DIR/" || return 1
    scp_file "$local_dir/channel-artifacts" "$org_ip" "$REMOTE_FABRIC_DIR/" || return 1
    scp_file "$local_dir/chaincode" "$org_ip" "$REMOTE_FABRIC_DIR/" || return 1

    return 0
}

# Verify peer deployment prerequisites
# Arguments:
#   $1: Organization IP
#   $2: Remote log file
verify_peer_prerequisites() {
    local org_ip=$1
    local remote_log=$2

    # Check Docker and Docker Compose
    ssh_exec "$org_ip" "command -v docker >/dev/null 2>&1" || {
        log_msg "$remote_log" "⛔ Docker not found on remote host"
        return 1
    }
    ssh_exec "$org_ip" "docker compose version >/dev/null 2>&1" || {
        log_msg "$remote_log" "⛔ Docker Compose not found on remote host"
        return 1
    }

    return 0
}

# Create organization-specific compose file from template
# Arguments:
#   $1: Organization name
#   $2: Organization domain
#   $3: Organization IP
#   $4: Peer port
#   $5: Chaincode port
#   $6: Operations port
#   $7: Orderer IP
#   $8: Remote compose file path
#   $9: Template file path
create_org_compose_file() {
    local org_name=$1
    local org_domain=$2
    local org_ip=$3
    local peer_port=$4
    local cc_port=$5
    local ops_port=$6
    local orderer_ip=$7
    local compose_file=$8
    local template=$9

    # Create substitution script
    local subst_script="""
export ORG_NAME='$org_name'
export ORG_DOMAIN='$org_domain'
export PEER_PORT='$peer_port'
export CC_PORT='$cc_port'
export PEER_OPERATIONS_PORT='$ops_port'
export ORDERER_IP='$orderer_ip'
export ORG1_IP='${ORG_IPS[0]}'
export ORG2_IP='${ORG_IPS[1]}'
envsubst '\${ORG_NAME} \${ORG_DOMAIN} \${PEER_PORT} \${CC_PORT} \${PEER_OPERATIONS_PORT} \${ORDERER_IP} \${ORG1_IP} \${ORG2_IP}' < $template > $compose_file
"""

    # Execute substitution on remote host
    ssh_exec "$org_ip" "$subst_script" || return 1
    return 0
}

# Deploy peer and CLI containers for an organization
# Arguments:
#   $1: Organization name
#   $2: Organization domain
#   $3: Organization IP
#   $4: Remote compose file path
#   $5: Remote log file
deploy_peer_and_cli() {
    local org_name=$1
    local org_domain=$2
    local org_ip=$3
    local compose_file=$4
    local remote_log=$5

    local peer_container="peer.$org_domain"
    local cli_container="cli.$org_domain"
    
    # Clean up existing containers
    cleanup_container "$peer_container" "$remote_log" || return 1
    cleanup_container "$cli_container" "$remote_log" || return 1

    # Clean up volumes
    local volumes=("peer.${org_domain}_data" "peer.${org_domain}_couchdb_data" "$remote_log")
    cleanup_volumes "${volumes[@]}" || return 1

    # Ensure network exists
    ensure_network "fabric_network" "$remote_log" || return 1

    # Deploy services
    deploy_compose_service "$compose_file" "$peer_container" "$remote_log" || return 1
    
    # Verify both containers
    wait_for_container "$peer_container" 30 || return 1
    wait_for_container "$cli_container" 30 || return 1

    return 0
}
