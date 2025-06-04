#!/bin/bash

# Source other utilities
source "$(dirname "$0")/docker-utils.sh"
source "$(dirname "$0")/ssh-utils.sh"
source "$(dirname "$0")/peer-utils.sh"

# Execute peer channel command
# Arguments:
#   $1: Organization IP
#   $2: CLI container name
#   $3: Command to execute
#   $4: Remote log file
execute_channel_command() {
    local org_ip=$1
    local cli_container=$2
    local command=$3
    local remote_log=$4

    ssh_exec "$org_ip" "docker exec $cli_container $command" || {
        log_msg "$remote_log" "⛔ Channel command failed: $command"
        return 1
    }
    return 0
}

# Create channel using the first organization
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Channel name
#   $4: Channel TX file path
#   $5: Remote log file
create_channel() {
    local org_ip=$1
    local org_domain=$2
    local channel_name=$3
    local channel_tx=$4
    local remote_log=$5
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "📝 Creating channel $channel_name..."

    # Set environment variables for peer CLI
    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local peer_cmd="peer channel create -o orderer.fabriczakat.local:7050 \
        -c $channel_name \
        -f $channel_tx \
        --timeout 10s \
        --tls --cafile /etc/hyperledger/fabric/tls/ca.crt"

    execute_channel_command "$org_ip" "$cli_container" "$env_vars $peer_cmd" "$remote_log" || return 1
    
    log_msg "$remote_log" "✅ Channel $channel_name created successfully."
    return 0
}

# Join channel for a specific organization
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Channel name
#   $4: Remote log file
join_channel() {
    local org_ip=$1
    local org_domain=$2
    local channel_name=$3
    local remote_log=$4
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "📝 Joining channel $channel_name for $org_domain..."

    # Set environment variables for peer CLI
    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"

    # Fetch the channel block first
    local fetch_cmd="peer channel fetch 0 /etc/hyperledger/fabric/channel-artifacts/$channel_name.block \
        -o orderer.fabriczakat.local:7050 \
        -c $channel_name \
        --tls --cafile /etc/hyperledger/fabric/tls/ca.crt"

    execute_channel_command "$org_ip" "$cli_container" "$env_vars $fetch_cmd" "$remote_log" || return 1

    # Join the channel
    local join_cmd="peer channel join -b /etc/hyperledger/fabric/channel-artifacts/$channel_name.block"
    execute_channel_command "$org_ip" "$cli_container" "$env_vars $join_cmd" "$remote_log" || return 1

    log_msg "$remote_log" "✅ $org_domain joined channel $channel_name successfully."
    return 0
}

# Update anchor peers for an organization
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Channel name
#   $4: Anchor peer update TX file path
#   $5: Remote log file
update_anchor_peers() {
    local org_ip=$1
    local org_domain=$2
    local channel_name=$3
    local anchor_tx=$4
    local remote_log=$5
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "📝 Updating anchor peers for $org_domain..."

    # Set environment variables for peer CLI
    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local update_cmd="peer channel update -o orderer.fabriczakat.local:7050 \
        -c $channel_name \
        -f $anchor_tx \
        --tls --cafile /etc/hyperledger/fabric/tls/ca.crt"

    execute_channel_command "$org_ip" "$cli_container" "$env_vars $update_cmd" "$remote_log" || return 1

    log_msg "$remote_log" "✅ Anchor peers updated for $org_domain."
    return 0
}

# Get channel information
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Channel name
#   $4: Remote log file
get_channel_info() {
    local org_ip=$1
    local org_domain=$2
    local channel_name=$3
    local remote_log=$4
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "🔎 Getting channel info for $channel_name..."

    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local info_cmd="peer channel getinfo -c $channel_name"

    execute_channel_command "$org_ip" "$cli_container" "$env_vars $info_cmd" "$remote_log" || return 1

    return 0
}

# List all channels for a peer
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Remote log file
list_channels() {
    local org_ip=$1
    local org_domain=$2
    local remote_log=$3
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "📋 Listing channels for $org_domain..."

    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local list_cmd="peer channel list"

    execute_channel_command "$org_ip" "$cli_container" "$env_vars $list_cmd" "$remote_log" || return 1

    return 0
}
