#!/bin/bash

# Source SSH utilities
source "$(dirname "$0")/ssh-utils.sh"

# Create MSP directory structure
# Arguments:
#   $1: Base directory path
#   $2: Organization name
#   $3: Domain name
create_msp_structure() {
    local base_dir=$1
    local org=$2
    local domain=$3
    
    mkdir -p "$base_dir/$domain/msp/"{cacerts,tlscacerts,admincerts}
    mkdir -p "$base_dir/$domain/peers"
    mkdir -p "$base_dir/$domain/users"
}

# Copy organization MSP files from remote to local
# Arguments:
#   $1: Remote IP
#   $2: Remote org path
#   $3: Local org path
copy_org_msp() {
    local ip=$1
    local remote_path=$2
    local local_path=$3

    # Create MSP directories
    mkdir -p "$local_path/msp/"{cacerts,tlscacerts,admincerts}
    
    # Copy MSP files
    scp_file "fabricadmin@$ip:~/$remote_path/msp/config.yaml" "$local_path/msp/" || echo "⚠️ No remote config.yaml found"
    scp_file "fabricadmin@$ip:~/$remote_path/msp/cacerts/*" "$local_path/msp/cacerts/" || echo "⚠️ No remote cacerts found"
    scp_file "fabricadmin@$ip:~/$remote_path/msp/tlscacerts/*" "$local_path/msp/tlscacerts/" || echo "⚠️ No remote tlscacerts found"
    
    # Verify critical cacerts
    if [ -z "$(ls -A $local_path/msp/cacerts/)" ]; then
        echo "⛔ Error: Failed to copy critical cacerts"
        return 1
    fi
    return 0
}

# Copy peer certificates from remote to local
# Arguments:
#   $1: Remote IP
#   $2: Remote peer path
#   $3: Local peer path
copy_peer_certs() {
    local ip=$1
    local remote_path=$2
    local local_path=$3
    
    # Create directories
    mkdir -p "$local_path/"{msp/cacerts,msp/tlscacerts,msp/signcerts,tls}
    
    # Copy MSP files
    scp_file "fabricadmin@$ip:~/$remote_path/msp/config.yaml" "$local_path/msp/" || echo "⚠️ No remote peer config.yaml found"
    scp_file "fabricadmin@$ip:~/$remote_path/msp/signcerts/*" "$local_path/msp/signcerts/" || echo "⚠️ No remote peer signcerts found"
    scp_file "fabricadmin@$ip:~/$remote_path/msp/cacerts/*" "$local_path/msp/cacerts/" || echo "⚠️ No remote peer cacerts found"
    scp_file "fabricadmin@$ip:~/$remote_path/msp/tlscacerts/*" "$local_path/msp/tlscacerts/" || echo "⚠️ No remote peer tlscacerts found"
    
    # Copy TLS files
    scp_file "fabricadmin@$ip:~/$remote_path/tls/server.crt" "$local_path/tls/" || echo "⚠️ No remote peer server.crt found"
    scp_file "fabricadmin@$ip:~/$remote_path/tls/ca.crt" "$local_path/tls/" || echo "⚠️ No remote peer ca.crt found"
    
    # Verify critical files
    if [ -z "$(ls -A $local_path/msp/signcerts/)" ]; then
        echo "⛔ Error: Failed to copy critical signcerts"
        return 1
    fi
    if [ ! -f "$local_path/tls/server.crt" ]; then
        echo "⛔ Error: Failed to copy critical server.crt"
        return 1
    fi
    return 0
}

# Copy admin certificates from remote to local
# Arguments:
#   $1: Remote IP
#   $2: Remote admin path
#   $3: Local admin path
copy_admin_certs() {
    local ip=$1
    local remote_path=$2
    local local_path=$3
    
    # Create directories
    mkdir -p "$local_path/"{msp/cacerts,msp/tlscacerts,msp/signcerts}
    
    # Copy MSP files
    scp_file "fabricadmin@$ip:~/$remote_path/msp/config.yaml" "$local_path/msp/" || echo "⚠️ No remote admin config.yaml found"
    scp_file "fabricadmin@$ip:~/$remote_path/msp/signcerts/*" "$local_path/msp/signcerts/" || echo "⚠️ No remote admin signcerts found"
    scp_file "fabricadmin@$ip:~/$remote_path/msp/cacerts/*" "$local_path/msp/cacerts/" || echo "⚠️ No remote admin cacerts found"
    scp_file "fabricadmin@$ip:~/$remote_path/msp/tlscacerts/*" "$local_path/msp/tlscacerts/" || echo "⚠️ No remote admin tlscacerts found"
    
    # Verify critical files
    if [ -z "$(ls -A $local_path/msp/signcerts/)" ]; then
        echo "⛔ Error: Failed to copy critical signcerts"
        return 1
    fi
    return 0
}

# Create a distribution bundle with MSP artifacts
# Arguments:
#   $1: Temporary directory path
#   $2: Local peer org directory
#   $3: Orderer org directory
#   $4: Array of org names
create_msp_bundle() {
    local temp_dir=$1
    local peer_org_dir=$2
    local orderer_org_dir=$3
    shift 3
    local orgs=("$@")

    # Create bundle structure
    mkdir -p "$temp_dir/ordererOrganizations" "$temp_dir/peerOrganizations"
    
    # Copy peer organizations
    for org in "${orgs[@]}"; do
        local domain="${org}.fabriczakat.local"
        if [ -d "$peer_org_dir/$domain" ]; then
            cp -r "$peer_org_dir/$domain" "$temp_dir/peerOrganizations/" || return 1
        fi
    done

    # Copy orderer organization (safely without private keys)
    local orderer_domain="fabriczakat.local"
    local orderer_temp_dir="$temp_dir/ordererOrganizations/$orderer_domain"
    
    # Create orderer directory structure
    mkdir -p "$orderer_temp_dir/msp/"{cacerts,tlscacerts} \
             "$orderer_temp_dir/orderers/orderer.$orderer_domain/"{msp/cacerts,msp/tlscacerts,msp/signcerts,tls} \
             "$orderer_temp_dir/users/Admin@$orderer_domain/"{msp/cacerts,msp/tlscacerts,msp/signcerts}
    
    # Copy orderer organization files (only certs)
    cp_if_exists() { if [ -e "$1" ]; then cp -r "$1" "$2"; fi; }
    
    cp_if_exists "$orderer_org_dir/msp/config.yaml" "$orderer_temp_dir/msp/"
    cp_if_exists "$orderer_org_dir/msp/cacerts/"* "$orderer_temp_dir/msp/cacerts/"
    cp_if_exists "$orderer_org_dir/msp/tlscacerts/"* "$orderer_temp_dir/msp/tlscacerts/"
    
    # Copy orderer node certs
    local orderer_node="orderer.$orderer_domain"
    cp_if_exists "$orderer_org_dir/orderers/$orderer_node/msp/config.yaml" "$orderer_temp_dir/orderers/$orderer_node/msp/"
    cp_if_exists "$orderer_org_dir/orderers/$orderer_node/msp/cacerts/"* "$orderer_temp_dir/orderers/$orderer_node/msp/cacerts/"
    cp_if_exists "$orderer_org_dir/orderers/$orderer_node/msp/tlscacerts/"* "$orderer_temp_dir/orderers/$orderer_node/msp/tlscacerts/"
    cp_if_exists "$orderer_org_dir/orderers/$orderer_node/msp/signcerts/"* "$orderer_temp_dir/orderers/$orderer_node/msp/signcerts/"
    cp_if_exists "$orderer_org_dir/orderers/$orderer_node/tls/server.crt" "$orderer_temp_dir/orderers/$orderer_node/tls/"
    cp_if_exists "$orderer_org_dir/orderers/$orderer_node/tls/ca.crt" "$orderer_temp_dir/orderers/$orderer_node/tls/"
    
    # Copy orderer admin certs
    local admin_name="Admin@$orderer_domain"
    cp_if_exists "$orderer_org_dir/users/$admin_name/msp/config.yaml" "$orderer_temp_dir/users/$admin_name/msp/"
    cp_if_exists "$orderer_org_dir/users/$admin_name/msp/cacerts/"* "$orderer_temp_dir/users/$admin_name/msp/cacerts/"
    cp_if_exists "$orderer_org_dir/users/$admin_name/msp/tlscacerts/"* "$orderer_temp_dir/users/$admin_name/msp/tlscacerts/"
    cp_if_exists "$orderer_org_dir/users/$admin_name/msp/signcerts/"* "$orderer_temp_dir/users/$admin_name/msp/signcerts/"
    
    # Create archive
    tar -czf "$temp_dir/all-msps.tar.gz" -C "$temp_dir" . || return 1
    
    return 0
}

# Distribute MSP bundle to remote organizations
# Arguments:
#   $1: Bundle path
#   $2: IP address
distribute_msp_bundle() {
    local bundle=$1
    local ip=$2
    
    # Copy archive
    scp_file "$bundle" "$ip:~/fabric/" || return 1
    
    # Extract archive
    ssh_exec "$ip" "mkdir -p ~/fabric/organizations && tar -xzf ~/fabric/all-msps.tar.gz -C ~/fabric/organizations/" || return 1
    
    # Cleanup archive
    ssh_exec "$ip" "rm ~/fabric/all-msps.tar.gz" || echo "⚠️ Warning: Failed to remove remote archive"
    
    return 0
}
