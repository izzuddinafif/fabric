#!/bin/bash
set -e

echo "  🚀 Starting Orderer CA setup process..."

# Create CA directory
echo "  📁 Creating Orderer CA directory: $CA_DIR"
if [ -d "$CA_DIR" ]; then
    echo "  ℹ️ Directory $CA_DIR already exists."
    echo "  ✅ Orderer CA initialization can be skipped."
    exit 0
fi

mkdir -p "$CA_DIR"

# Copy fabric-ca-server binary
echo "  📄 Copying fabric-ca-server binary..."
cp "$FABRIC_BIN/fabric-ca-server" "$CA_DIR/"

cd "$CA_DIR"

# Initialize CA server
echo "  🚀 Initializing Orderer CA server..."
./fabric-ca-server init -b "$BOOTSTRAP_USER:$BOOTSTRAP_PASS"

# Configure CA server for Orderer
echo "  ⚙️ Applying Orderer CA configuration..."
yq eval '
  .ca.name = "orderer-ca" |
  .csr.cn = "orderer-ca" |
  .csr.hosts = ["localhost", "$CSR_HOSTNAME"] |
  .csr.names[0].C = "ID" |
  .csr.names[0].ST = "East Java" |
  .csr.names[0].L = "Surabaya" |
  .csr.names[0].O = "YDSF"
' -i fabric-ca-server-config.yaml

echo "  ✅ Orderer CA server initialized successfully."
