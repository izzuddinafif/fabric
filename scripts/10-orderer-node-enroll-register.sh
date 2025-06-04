#!/bin/bash
# Script 10: Register and Enroll Orderer Node Identity
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

# Define variables
CA_CLIENT_HOME="$HOME/fabric/fabric-ca-client"
TLS_CERT_PATH="$CA_CLIENT_HOME/tls-root-cert"
ORDERER_CA_PATH="$CA_CLIENT_HOME/orderer-ca"
TLS_CA_PATH="$CA_CLIENT_HOME/tls-ca"
ORGANIZATIONS_PATH="$HOME/fabric/organizations"
ORDERER_ORG_PATH="$ORGANIZATIONS_PATH/ordererOrganizations/${ORDERER_DOMAIN}"
ORDERER_PATH="$ORDERER_ORG_PATH/orderers/$ORDERER_HOSTNAME"
NODE_MSP="$ORDERER_PATH/msp"
TLS_PATH="$ORDERER_PATH/tls"
CA_PORT=7055
TLS_PORT=7054

# Function to verify prerequisites
verify_prerequisites() {
    local required_dirs=(
        "$CA_CLIENT_HOME"
        "$TLS_CERT_PATH"
        "$ORDERER_CA_PATH/btstrp-orderer/msp"
        "$TLS_CA_PATH/tlsadmin/msp"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "⛔ Required directory not found: $dir"
            return 1
        fi
    done
    
    if [ ! -f "$TLS_CERT_PATH/tls-ca-cert.pem" ]; then
        echo "⛔ TLS root certificate not found"
        return 1
    fi
    
    return 0
}

# Function to create MSP directories
create_msp_directories() {
    echo "📁 Creating MSP directory structure..."
    mkdir -p "$NODE_MSP"/{cacerts,keystore,signcerts,tlscacerts}
    mkdir -p "$TLS_PATH"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to create MSP directories"
        return 1
    fi
    return 0
}

# Function to register identities
register_identities() {
    # Register node identity with orderer CA
    echo "🔐 Registering orderer node identity..."
    ./fabric-ca-client register -d \
        --id.name "$ORDERER_HOSTNAME" \
        --id.secret ordererpw \
        --id.type orderer \
        --mspdir "$ORDERER_CA_PATH/btstrp-orderer/msp" \
        --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
        -u "https://ca.orderer.${ORDERER_DOMAIN}:$CA_PORT"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to register orderer node identity"
        return 1
    fi
    
    # Register TLS identity with TLS CA
    echo "🔐 Registering orderer node TLS identity..."
    ./fabric-ca-client register -d \
        --id.name "$ORDERER_HOSTNAME" \
        --id.secret ordererpw \
        -u "https://tls.${ORDERER_DOMAIN}:$TLS_PORT" \
        --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
        --mspdir "$TLS_CA_PATH/tlsadmin/msp"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to register orderer node TLS identity"
        return 1
    fi
    
    return 0
}

# Function to enroll node identity
enroll_node_identity() {
    echo "🔐 Enrolling orderer node identity..."
    ./fabric-ca-client enroll -d \
        -u "https://$ORDERER_HOSTNAME:ordererpw@ca.orderer.${ORDERER_DOMAIN}:$CA_PORT" \
        --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
        --mspdir "$NODE_MSP"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to enroll orderer node identity"
        return 1
    fi
    return 0
}

# Function to enroll TLS identity
enroll_tls_identity() {
    echo "🔐 Enrolling orderer node TLS identity..."
    ./fabric-ca-client enroll -d \
        -u "https://$ORDERER_HOSTNAME:ordererpw@tls.${ORDERER_DOMAIN}:$TLS_PORT" \
        --enrollment.profile tls \
        --csr.hosts "$ORDERER_HOSTNAME" \
        --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
        --mspdir "$TLS_PATH"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to enroll orderer node TLS identity"
        return 1
    fi
    return 0
}

# Function to rename and organize credentials
organize_credentials() {
    echo "🔑 Organizing credentials..."
    
    # Rename node identity files
    local node_key=$(find "$NODE_MSP/keystore/" -type f -name "*_sk")
    local node_cert=$(find "$NODE_MSP/signcerts/" -type f -name "*.pem")
    
    if [ -z "$node_key" ] || [ -z "$node_cert" ]; then
        echo "⛔ Node credentials not found"
        return 1
    fi
    
    mv "$node_key" "$NODE_MSP/keystore/orderer-node-key.pem"
    mv "$node_cert" "$NODE_MSP/signcerts/orderer-node-cert.pem"
    
    # Organize TLS files
    local tls_key=$(find "$TLS_PATH/keystore/" -type f -name "*_sk")
    local tls_cert="$TLS_PATH/signcerts/cert.pem"
    
    if [ ! -f "$tls_cert" ] || [ -z "$tls_key" ]; then
        echo "⛔ TLS credentials not found"
        return 1
    fi
    
    cp "$tls_cert" "$TLS_PATH/server.crt"
    cp "$tls_key" "$TLS_PATH/server.key"
    cp "$TLS_CERT_PATH/tls-ca-cert.pem" "$TLS_PATH/ca.crt"
    cp "$TLS_PATH/ca.crt" "$NODE_MSP/tlscacerts/tls-ca-cert.pem"
    
    return 0
}

# Function to setup MSP configuration
setup_msp_config() {
    echo "⚙️ Setting up MSP configuration..."
    local cacert=$(ls "$NODE_MSP/cacerts"/*.pem | head -n 1)
    
    if [ ! -f "$cacert" ]; then
        echo "⛔ CA certificate not found"
        return 1
    fi
    
    ../scripts/helper/create-config-yaml.sh "$cacert" "$NODE_MSP"
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to create MSP config"
        return 1
    fi
    return 0
}

echo "🚀 Starting orderer node enrollment process..."

# Change to CA client directory
cd "$CA_CLIENT_HOME"
export FABRIC_CA_CLIENT_HOME="$PWD"

# Execute the process
verify_prerequisites || exit 1
create_msp_directories || exit 1
register_identities || exit 1
enroll_node_identity || exit 1
enroll_tls_identity || exit 1
organize_credentials || exit 1
setup_msp_config || exit 1

echo "🎉 Orderer node setup completed successfully!"
echo ""
echo "Generated artifacts:"
echo "- Node MSP: $NODE_MSP"
echo "- TLS Path: $TLS_PATH"
echo ""
echo "Next Steps:"
echo "1. Deploy the orderer node"
echo "2. Configure the orderer service"
echo "----------------------------------------"

exit 0
