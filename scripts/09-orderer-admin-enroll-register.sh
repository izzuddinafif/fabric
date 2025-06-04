#!/bin/bash
# Script 09: Register and Enroll Orderer Admin Identity
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

# Define variables
CA_CLIENT_HOME="$HOME/fabric/fabric-ca-client"
TLS_CERT_PATH="$CA_CLIENT_HOME/tls-root-cert"
ORDERER_CA_PATH="$CA_CLIENT_HOME/orderer-ca"
ORGANIZATIONS_PATH="$HOME/fabric/organizations"
ORDERER_ORG_PATH="$ORGANIZATIONS_PATH/ordererOrganizations/${ORDERER_DOMAIN}"
ADMIN_MSP="$ORDERER_ORG_PATH/users/Admin@${ORDERER_DOMAIN}/msp"
ORG_MSP="$ORDERER_ORG_PATH/msp"
CA_PORT=7055

# Function to verify prerequisites
verify_prerequisites() {
    local required_dirs=(
        "$CA_CLIENT_HOME"
        "$TLS_CERT_PATH"
        "$ORDERER_CA_PATH/btstrp-orderer/msp"
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
    mkdir -p "$ADMIN_MSP"/{cacerts,keystore,signcerts,tlscacerts}
    mkdir -p "$ORG_MSP"/{cacerts,tlscacerts}
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to create MSP directories"
        return 1
    fi
    return 0
}

# Function to register identity
register_identity() {
    echo "🔐 Registering orderer admin identity 'ordereradmin'..."
    ./fabric-ca-client register -d \
        --id.name ordereradmin \
        --id.secret ordereradminpw \
        --id.type admin \
        --mspdir "$ORDERER_CA_PATH/btstrp-orderer/msp" \
        --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
        -u "https://ca.orderer.${ORDERER_DOMAIN}:$CA_PORT"
        
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to register orderer admin"
        return 1
    fi
    return 0
}

# Function to enroll identity
enroll_identity() {
    echo "🔐 Enrolling orderer admin identity 'ordereradmin'..."
    ./fabric-ca-client enroll -d \
        -u "https://ordereradmin:ordereradminpw@ca.orderer.${ORDERER_DOMAIN}:$CA_PORT" \
        --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
        --mspdir "$ADMIN_MSP"
        
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to enroll orderer admin"
        return 1
    fi
    return 0
}

# Function to rename credentials
rename_credentials() {
    echo "🔑 Renaming admin credentials..."
    local key_file=$(find "$ADMIN_MSP/keystore/" -type f -name "*_sk")
    local cert_file=$(find "$ADMIN_MSP/signcerts/" -type f -name "*.pem")
    
    if [ -z "$key_file" ] || [ -z "$cert_file" ]; then
        echo "⛔ Credentials not found"
        return 1
    fi
    
    mv "$key_file" "$ADMIN_MSP/keystore/orderer-admin-key.pem"
    mv "$cert_file" "$ADMIN_MSP/signcerts/orderer-admin-cert.pem"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to rename credentials"
        return 1
    fi
    return 0
}

# Function to setup MSP configuration
setup_msp_config() {
    echo "⚙️ Setting up MSP configuration..."
    
    # Create admin MSP config
    local admin_cacert=$(ls "$ADMIN_MSP/cacerts"/*.pem | head -n 1)
    if [ ! -f "$admin_cacert" ]; then
        echo "⛔ Admin CA certificate not found"
        return 1
    fi
    ../scripts/helper/create-config-yaml.sh "$admin_cacert" "$ADMIN_MSP"
    
    # Create org MSP config
    local org_cacert="$ORG_MSP/cacerts/orderer-ca-cert.pem"
    ../scripts/helper/create-config-yaml.sh "$org_cacert" "$ORG_MSP"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to create MSP config files"
        return 1
    fi
    return 0
}

# Function to copy certificates
copy_certificates() {
    echo "📄 Copying certificates..."
    
    # Copy TLS CA cert to admin MSP
    cp "$TLS_CERT_PATH/tls-ca-cert.pem" "$ADMIN_MSP/tlscacerts/"
    
    # Copy certificates to org MSP
    cp "../fabric-ca-server-orderer/ca-cert.pem" "$ORG_MSP/cacerts/orderer-ca-cert.pem"
    cp "$TLS_CERT_PATH/tls-ca-cert.pem" "$ORG_MSP/tlscacerts/"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to copy certificates"
        return 1
    fi
    return 0
}

echo "🚀 Starting orderer admin registration and enrollment process..."

# Change to CA client directory
cd "$CA_CLIENT_HOME"
export FABRIC_CA_CLIENT_HOME="$PWD"

# Execute the process
verify_prerequisites || exit 1
create_msp_directories || exit 1
register_identity || exit 1
enroll_identity || exit 1
rename_credentials || exit 1
copy_certificates || exit 1
setup_msp_config || exit 1

echo "🎉 Orderer admin identity setup completed successfully!"
echo ""
echo "Generated artifacts:"
echo "- Admin MSP: $ADMIN_MSP"
echo "- Organization MSP: $ORG_MSP"
echo ""
echo "Next Steps:"
echo "1. Register and enroll orderer node identity"
echo "2. Set up the orderer node configuration"
echo "----------------------------------------"

exit 0
