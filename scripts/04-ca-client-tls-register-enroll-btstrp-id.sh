#!/bin/bash
# Script 04: Register and Enroll Bootstrap Identities with TLS CA
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

# Define variables
CA_CLIENT_HOME="$HOME/fabric/fabric-ca-client"
TLS_CERT_PATH="$CA_CLIENT_HOME/tls-root-cert"
TLS_ADMIN_MSP="$CA_CLIENT_HOME/tls-ca/tlsadmin/msp"
CA_HOST="tls-ca.${ORDERER_DOMAIN}"
CA_PORT=7054

# Bootstrap users configuration
declare -A BOOTSTRAP_USERS=(
    ["rcaadmin-org1"]="org1pw"
    ["rcaadmin-org2"]="org2pw"
    ["rcaadmin-orderer"]="ordererpw"
)

# Function to verify directory and file existence
verify_prerequisites() {
    local dirs=("$CA_CLIENT_HOME" "$TLS_CERT_PATH" "$TLS_ADMIN_MSP")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "⛔ Required directory not found: $dir"
            return 1
        fi
    done
    
    if [ ! -f "$TLS_CERT_PATH/tls-ca-cert.pem" ]; then
        echo "⛔ TLS CA certificate not found"
        return 1
    fi
    
    if [ ! -f "$CA_CLIENT_HOME/fabric-ca-client" ]; then
        echo "⛔ fabric-ca-client binary not found"
        return 1
    fi
    
    return 0
}

# Function to register a bootstrap user
register_bootstrap_user() {
    local username=$1
    local password=$2
    
    echo "🔐 Registering $username..."
    ./fabric-ca-client register -d \
        --id.name "$username" \
        --id.secret "$password" \
        -u "https://$CA_HOST:$CA_PORT" \
        --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
        --mspdir "$TLS_ADMIN_MSP"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to register $username"
        return 1
    fi
    echo "✅ $username registered successfully"
    return 0
}

# Function to enroll a bootstrap user
enroll_bootstrap_user() {
    local username=$1
    local password=$2
    local host_suffix=$3
    
    echo "🔐 Enrolling $username..."
    ./fabric-ca-client enroll \
        -u "https://$username:$password@$CA_HOST:$CA_PORT" \
        --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
        --enrollment.profile tls \
        --csr.hosts "ca.$host_suffix" \
        --mspdir "tls-ca/$username/msp"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to enroll $username"
        return 1
    fi
    echo "✅ $username enrolled successfully"
    return 0
}

# Function to rename private key files
rename_private_keys() {
    local username=$1
    local keystore_dir="tls-ca/$username/msp/keystore"
    
    if [ -d "$keystore_dir" ]; then
        echo "🔑 Renaming private key for $username..."
        find "$keystore_dir" -name "*_sk" -exec mv {} "$keystore_dir/key.pem" \;
        if [ $? -ne 0 ]; then
            echo "⚠️ Warning: Could not rename private key for $username"
            return 1
        fi
    else
        echo "⚠️ Warning: Keystore directory not found for $username"
        return 1
    fi
    return 0
}

echo "🚀 Starting bootstrap identity registration and enrollment..."

# Change to CA client directory
cd "$CA_CLIENT_HOME"
export FABRIC_CA_CLIENT_HOME="$PWD"

# Verify prerequisites
verify_prerequisites || exit 1

# Clean up existing rcaadmin directories if they exist
echo "🧹 Cleaning up existing rcaadmin directories..."
rm -rf tls-ca/rcaadmin-*

# Register bootstrap users
echo "📝 Registering bootstrap users..."
for username in "${!BOOTSTRAP_USERS[@]}"; do
    register_bootstrap_user "$username" "${BOOTSTRAP_USERS[$username]}" || exit 1
done

# Enroll bootstrap users
echo "🔒 Enrolling bootstrap users..."
for username in "${!BOOTSTRAP_USERS[@]}"; do
    # Extract org name from username (rcaadmin-org1 -> org1)
    org=${username#rcaadmin-}
    # Create host suffix based on org name
    host_suffix="$org.${ORDERER_DOMAIN}"
    
    enroll_bootstrap_user "$username" "${BOOTSTRAP_USERS[$username]}" "$host_suffix" || exit 1
    rename_private_keys "$username" || true
done

echo "🎉 Bootstrap identity registration and enrollment completed successfully!"
echo ""
echo "Generated artifacts:"
for username in "${!BOOTSTRAP_USERS[@]}"; do
    echo "- $CA_CLIENT_HOME/tls-ca/$username/msp/"
done
echo "----------------------------------------"

exit 0
