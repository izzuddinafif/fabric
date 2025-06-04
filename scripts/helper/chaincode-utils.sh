#!/bin/bash

# Source other utilities
source "$(dirname "$0")/docker-utils.sh"
source "$(dirname "$0")/ssh-utils.sh"

# Package chaincode
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Package name
#   $4: Chaincode path
#   $5: Chaincode label
#   $6: Remote log file
package_chaincode() {
    local org_ip=$1
    local org_domain=$2
    local package_name=$3
    local cc_path=$4
    local cc_label=$5
    local remote_log=$6
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "📦 Packaging chaincode $cc_label..."

    # Set environment variables for peer CLI
    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local peer_cmd="peer lifecycle chaincode package $package_name \
        --path $cc_path \
        --lang golang \
        --label $cc_label"

    ssh_exec "$org_ip" "docker exec $cli_container $env_vars $peer_cmd" || {
        log_msg "$remote_log" "⛔ Failed to package chaincode"
        return 1
    }

    log_msg "$remote_log" "✅ Chaincode packaged successfully."
    return 0
}

# Install chaincode on peer
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Package path
#   $4: Remote log file
install_chaincode() {
    local org_ip=$1
    local org_domain=$2
    local package_path=$3
    local remote_log=$4
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "📥 Installing chaincode on peer..."

    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local peer_cmd="peer lifecycle chaincode install $package_path"

    ssh_exec "$org_ip" "docker exec $cli_container $env_vars $peer_cmd" || {
        log_msg "$remote_log" "⛔ Failed to install chaincode"
        return 1
    }

    log_msg "$remote_log" "✅ Chaincode installed successfully."
    return 0
}

# Get installed chaincode package ID
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Chaincode label
#   $4: Remote log file
get_package_id() {
    local org_ip=$1
    local org_domain=$2
    local cc_label=$3
    local remote_log=$4
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "🔍 Getting chaincode package ID..."

    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local peer_cmd="peer lifecycle chaincode queryinstalled --output json"

    local query_result
    query_result=$(ssh_exec "$org_ip" "docker exec $cli_container $env_vars $peer_cmd")
    if [ $? -ne 0 ]; then
        log_msg "$remote_log" "⛔ Failed to query installed chaincodes"
        return 1
    fi

    # Extract package ID using the label
    local package_id=$(echo "$query_result" | grep -o "\"${cc_label}:[^\"]*\"" | sed 's/"//g')
    if [ -z "$package_id" ]; then
        log_msg "$remote_log" "⛔ Package ID not found for label $cc_label"
        return 1
    }

    echo "$package_id"
    return 0
}

# Approve chaincode for organization
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Channel name
#   $4: Package ID
#   $5: Sequence number
#   $6: Remote log file
approve_chaincode() {
    local org_ip=$1
    local org_domain=$2
    local channel_name=$3
    local package_id=$4
    local sequence=$5
    local remote_log=$6
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "👍 Approving chaincode for ${org_domain}..."

    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local peer_cmd="peer lifecycle chaincode approveformyorg \
        -o orderer.fabriczakat.local:7050 \
        --channelID $channel_name \
        --name mycc \
        --version 1.0 \
        --package-id $package_id \
        --sequence $sequence \
        --tls --cafile /etc/hyperledger/fabric/tls/ca.crt"

    ssh_exec "$org_ip" "docker exec $cli_container $env_vars $peer_cmd" || {
        log_msg "$remote_log" "⛔ Failed to approve chaincode"
        return 1
    }

    log_msg "$remote_log" "✅ Chaincode approved successfully."
    return 0
}

# Check commit readiness
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Channel name
#   $4: Sequence number
#   $5: Remote log file
check_commit_readiness() {
    local org_ip=$1
    local org_domain=$2
    local channel_name=$3
    local sequence=$4
    local remote_log=$5
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "🔍 Checking commit readiness..."

    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local peer_cmd="peer lifecycle chaincode checkcommitreadiness \
        --channelID $channel_name \
        --name mycc \
        --version 1.0 \
        --sequence $sequence \
        --tls --cafile /etc/hyperledger/fabric/tls/ca.crt \
        --output json"

    ssh_exec "$org_ip" "docker exec $cli_container $env_vars $peer_cmd" || {
        log_msg "$remote_log" "⛔ Failed to check commit readiness"
        return 1
    }

    log_msg "$remote_log" "✅ Commit readiness check completed."
    return 0
}

# Commit chaincode
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Channel name
#   $4: Sequence number
#   $5: Remote log file
commit_chaincode() {
    local org_ip=$1
    local org_domain=$2
    local channel_name=$3
    local sequence=$4
    local remote_log=$5
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "📝 Committing chaincode definition..."

    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local peer_cmd="peer lifecycle chaincode commit \
        -o orderer.fabriczakat.local:7050 \
        --channelID $channel_name \
        --name mycc \
        --version 1.0 \
        --sequence $sequence \
        --tls --cafile /etc/hyperledger/fabric/tls/ca.crt \
        --peerAddresses peer.org1.fabriczakat.local:7051 \
        --tlsRootCertFiles /etc/hyperledger/fabric/tls/ca.crt \
        --peerAddresses peer.org2.fabriczakat.local:7051 \
        --tlsRootCertFiles /etc/hyperledger/fabric/tls/ca.crt"

    ssh_exec "$org_ip" "docker exec $cli_container $env_vars $peer_cmd" || {
        log_msg "$remote_log" "⛔ Failed to commit chaincode"
        return 1
    }

    log_msg "$remote_log" "✅ Chaincode committed successfully."
    return 0
}

# Query committed chaincode
# Arguments:
#   $1: Organization IP
#   $2: Organization domain
#   $3: Channel name
#   $4: Remote log file
query_committed() {
    local org_ip=$1
    local org_domain=$2
    local channel_name=$3
    local remote_log=$4
    local cli_container="cli.$org_domain"

    log_msg "$remote_log" "🔍 Querying committed chaincode..."

    local env_vars="CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp"
    local peer_cmd="peer lifecycle chaincode querycommitted \
        --channelID $channel_name \
        --name mycc \
        --output json"

    ssh_exec "$org_ip" "docker exec $cli_container $env_vars $peer_cmd" || {
        log_msg "$remote_log" "⛔ Failed to query committed chaincode"
        return 1
    }

    log_msg "$remote_log" "✅ Committed chaincode query completed."
    return 0
}
