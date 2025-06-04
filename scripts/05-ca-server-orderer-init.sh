#!/bin/bash
# Script 05: Initialize Orderer CA Server
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

echo "🔐 Initializing Orderer CA Server..."

# Define variables
FABRIC_BIN="$HOME/bin"
CA_DIR="$HOME/fabric/fabric-ca-server-orderer"
CSR_HOSTNAME="$ORDERER_HOSTNAME"
BOOTSTRAP_USER="admin"
BOOTSTRAP_PASS="adminpw"

# Function to verify binary existence
verify_binary() {
    if [ ! -f "$FABRIC_BIN/fabric-ca-server" ]; then
        echo "⛔ fabric-ca-server binary not found in $FABRIC_BIN"
        return 1
    fi
    return 0
}

# Function to verify TLS certificates
verify_tls_certs() {
    local rcaadmin_dir="$HOME/fabric/fabric-ca-client/tls-ca/rcaadmin-orderer"
    local required_files=(
        "msp/keystore/key.pem"
        "msp/signcerts/cert.pem"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$rcaadmin_dir/$file" ]; then
            echo "⛔ Required TLS file not found: $rcaadmin_dir/$file"
            echo "Have you run scripts 03 and 04 to set up TLS certificates?"
            return 1
        fi
    done
    return 0
}

# Function to create necessary directories
create_directories() {
    echo "📁 Creating CA directories..."
    mkdir -p "$CA_DIR/msp/keystore"
    mkdir -p "$CA_DIR/msp/signcerts"
    mkdir -p "$CA_DIR/msp/user"
    mkdir -p "$CA_DIR/tls"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to create required directories"
        return 1
    fi
    return 0
}

# Function to copy required files
copy_files() {
    echo "📄 Copying necessary files..."
    # Copy the binary
    cp "$FABRIC_BIN/fabric-ca-server" "$CA_DIR/"
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to copy fabric-ca-server binary"
        return 1
    fi
    
    # Copy TLS certificates from rcaadmin enrollment
    local tls_src="$HOME/fabric/fabric-ca-client/tls-ca/rcaadmin-orderer/msp"
    cp "$tls_src/signcerts/cert.pem" "$CA_DIR/tls/cert.pem"
    cp "$tls_src/keystore/key.pem" "$CA_DIR/tls/key.pem"
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to copy TLS certificates"
        return 1
    fi
    return 0
}

# Function to execute template
execute_template() {
    echo "📝 Reading Orderer CA setup template..."
    local template_file="$(dirname "$0")/templates/orderer-ca-setup.sh"
    
    if [ ! -f "$template_file" ]; then
        echo "⛔ Orderer CA setup template not found at: $template_file"
        return 1
    fi
    
    # Export variables for template substitution
    export CA_DIR CSR_HOSTNAME BOOTSTRAP_USER BOOTSTRAP_PASS
    
    echo "⚙️ Executing setup script..."
    SETUP_SCRIPT=$(<"$template_file")
    eval "echo \"$SETUP_SCRIPT\"" | bash
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to execute setup script"
        return 1
    fi
    return 0
}

# Verify prerequisites
verify_binary || exit 1
verify_tls_certs || exit 1

# Create directories and copy files
create_directories || exit 1
copy_files || exit 1

# Execute the template
execute_template || exit 1

# Verify the configuration was created
if [ ! -f "$CA_DIR/fabric-ca-server-config.yaml" ]; then
    echo "⛔ CA server configuration was not created"
    exit 1
fi

echo "🎉 Orderer CA initialization completed successfully!"
echo ""
echo "Created artifacts:"
echo "- $CA_DIR/fabric-ca-server"
echo "- $CA_DIR/fabric-ca-server-config.yaml"
echo "- $CA_DIR/tls/{cert,key}.pem"
echo ""
echo "Next Steps:"
echo "1. Start the Orderer CA server (./scripts/06-ca-server-orderer-start.sh)"
echo "2. Enroll the bootstrap identity"
echo "3. Register and enroll additional identities"
echo "----------------------------------------"

exit 0
