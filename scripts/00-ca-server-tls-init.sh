#!/bin/bash
# Script 00: Initialize TLS CA Server
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

echo "🔐 Initializing TLS CA Server..."

# Define variables - using centralized config
FABRIC_BIN="$HOME/bin"
CA_DIR="$HOME/fabric/fabric-ca-server-tls"
CSR_HOSTNAME="tls-ca.${ORDERER_DOMAIN}"
BOOTSTRAP_USER="tls-admin"
BOOTSTRAP_PASS="tls-adminpw"

# Create required directories
echo "📁 Creating CA directories..."
mkdir -p "$CA_DIR/msp/keystore" "$CA_DIR/msp/signcerts" "$CA_DIR/msp/user"
mkdir -p "$CA_DIR/tls"

# Validate binary exists
if [ ! -f "$FABRIC_BIN/fabric-ca-server" ]; then
    echo "⛔ fabric-ca-server binary not found in $FABRIC_BIN"
    exit 1
fi

# Copy binary
echo "📄 Copying fabric-ca-server binary..."
cp "$FABRIC_BIN/fabric-ca-server" "$CA_DIR/"

# Prepare the setup script by reading from template
SETUP_FILE="$(dirname "$0")/templates/tls-ca-setup.sh"
if [ ! -f "$SETUP_FILE" ]; then
    echo "⛔ TLS CA setup template not found at: $SETUP_FILE"
    exit 1
fi

# Set up environment variables for the template
export CA_DIR CSR_HOSTNAME BOOTSTRAP_USER BOOTSTRAP_PASS

# Read and process the template
echo "📝 Reading TLS CA setup template..."
SETUP_SCRIPT=$(<"$SETUP_FILE")

# Execute the setup script with variable substitution
echo "⚙️ Executing setup script..."
eval "echo \"$SETUP_SCRIPT\"" | bash

# Verify setup completed successfully
if [ ! -f "$CA_DIR/fabric-ca-server-config.yaml" ]; then
    echo "⛔ Setup failed: fabric-ca-server-config.yaml not created"
    exit 1
fi

echo "🎉 TLS CA initialization process completed successfully!"
echo ""
echo "Created files and directories:"
echo "- $CA_DIR/fabric-ca-server"
echo "- $CA_DIR/fabric-ca-server-config.yaml"
echo "- $CA_DIR/msp/"
echo ""
echo "Next Steps:"
echo "1. Start the TLS CA server: ./scripts/01-ca-server-tls-start.sh"
echo "2. Enroll the bootstrap identity"
echo "3. Register and enroll additional identities"
echo "----------------------------------------"

exit 0
