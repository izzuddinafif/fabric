#!/bin/bash
# Script 08: Enroll Bootstrap User with Orderer CA
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

# Define variables
CA_CLIENT_HOME="$HOME/fabric/fabric-ca-client"
TLS_CERT_PATH="$CA_CLIENT_HOME/tls-root-cert"
ORDERER_CA_HOME="$CA_CLIENT_HOME/orderer-ca"
BOOTSTRAP_USER="btstrp-orderer"
BOOTSTRAP_PASS="btstrp-ordererpw"
CA_HOST="ca.orderer.${ORDERER_DOMAIN}"
CA_PORT=7055

# Function to verify directory structure
verify_directory_structure() {
    local required_dirs=(
        "$CA_CLIENT_HOME"
        "$TLS_CERT_PATH"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "⛔ Required directory not found: $dir"
            return 1
        fi
    done
    
    # Verify TLS root certificate
    if [ ! -f "$TLS_CERT_PATH/tls-ca-cert.pem" ]; then
        echo "⛔ TLS root certificate not found: $TLS_CERT_PATH/tls-ca-cert.pem"
        echo "Have you run script 03 to enroll with TLS CA?"
        return 1
    fi
    
    return 0
}

# Function to verify CA is available
verify_ca_available() {
    echo "🔍 Verifying Orderer CA is available..."
    if ! curl -sk https://$CA_HOST:$CA_PORT/cainfo > /dev/null; then
        echo "⛔ Orderer CA is not responding at $CA_HOST:$CA_PORT"
        echo "Have you started the Orderer CA server?"
        return 1
    fi
    echo "✅ Orderer CA is available"
    return 0
}

# Function to verify enrollment success
verify_enrollment() {
    local msp_dir="$1"
    local required_dirs=("cacerts" "keystore" "signcerts")
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$msp_dir/$dir" ] || [ -z "$(ls -A $msp_dir/$dir)" ]; then
            echo "⛔ Missing or empty required directory: $dir"
            return 1
        fi
    done
    
    # Verify certificate files exist
    if [ ! -f "$msp_dir/signcerts/cert.pem" ]; then
        echo "⛔ Certificate file not found"
        return 1
    fi
    
    if [ -z "$(ls $msp_dir/keystore/*_sk 2>/dev/null)" ]; then
        echo "⛔ Private key file not found"
        return 1
    fi
    
    return 0
}

# Function to rename private key
rename_private_key() {
    local msp_dir="$1"
    local keystore_dir="$msp_dir/keystore"
    local key_file
    
    key_file=$(find "$keystore_dir" -type f -name "*_sk")
    if [ -z "$key_file" ]; then
        echo "⛔ Private key file not found in $keystore_dir"
        return 1
    fi
    
    mv "$key_file" "$keystore_dir/key.pem"
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to rename private key file"
        return 1
    fi
    
    echo "✅ Private key renamed to key.pem"
    return 0
}

echo "🚀 Starting Orderer CA bootstrap enrollment process..."

# Verify prerequisites
verify_directory_structure || exit 1
verify_ca_available || exit 1

# Clean up existing enrollment if it exists
if [ -d "$ORDERER_CA_HOME" ]; then
    echo "🧹 Cleaning up existing Orderer CA enrollment..."
    rm -rf "$ORDERER_CA_HOME"
fi

# Create required directory
echo "📁 Creating Orderer CA directory..."
mkdir -p "$ORDERER_CA_HOME"

# Set working directory and environment
cd "$CA_CLIENT_HOME"
export FABRIC_CA_CLIENT_HOME="$PWD"

# Define MSP directory
MSP_DIR="$ORDERER_CA_HOME/$BOOTSTRAP_USER/msp"

echo "🔐 Enrolling bootstrap user '$BOOTSTRAP_USER' with Orderer CA..."
./fabric-ca-client enroll -d \
    -u "https://$BOOTSTRAP_USER:$BOOTSTRAP_PASS@$CA_HOST:$CA_PORT" \
    --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
    --mspdir "orderer-ca/$BOOTSTRAP_USER/msp"

# Verify enrollment was successful
if verify_enrollment "$MSP_DIR"; then
    echo "✅ Bootstrap enrollment completed successfully"
else
    echo "⛔ Bootstrap enrollment verification failed"
    exit 1
fi

# Rename the private key
echo "🔑 Processing private key..."
rename_private_key "$MSP_DIR" || exit 1

echo "🎉 Bootstrap user enrollment completed successfully!"
echo ""
echo "Generated artifacts:"
echo "- MSP Directory: $MSP_DIR"
echo "- Certificate: $MSP_DIR/signcerts/cert.pem"
echo "- Private Key: $MSP_DIR/keystore/key.pem"
echo ""
echo "Next Steps:"
echo "1. Register and enroll the admin identity"
echo "2. Register and enroll the orderer node identity"
echo "----------------------------------------"

exit 0
