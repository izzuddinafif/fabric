#!/bin/bash
set -e

echo "  🚀 Starting TLS CA setup process..."

# Create CA directory
echo "  📁 Creating TLS CA directory: $CA_DIR"
if [ -d "$CA_DIR" ]; then
    echo "  ℹ️ Directory $CA_DIR already exists."
    echo "  ✅ TLS CA initialization can be skipped."
    exit 0
fi

mkdir -p "$CA_DIR"

# Copy fabric-ca-server binary
echo "  📄 Copying fabric-ca-server binary..."
cp "$FABRIC_BIN/fabric-ca-server" "$CA_DIR/"

cd "$CA_DIR"

# Initialize CA server
echo "  🚀 Initializing TLS CA server..."
./fabric-ca-server init -b "$BOOTSTRAP_USER:$BOOTSTRAP_PASS"

# Configure CA server for TLS
echo "  ⚙️ Applying TLS CA configuration..."
yq eval '
  .ca.name = "tls-ca" |
  .csr.cn = "tls-ca" |
  .csr.hosts = ["localhost", "$CSR_HOSTNAME"] |
  .csr.names[0].C = "ID" |
  .csr.names[0].ST = "East Java" |
  .csr.names[0].L = "Surabaya" |
  .csr.names[0].O = "YDSF"
' -i fabric-ca-server-config.yaml

echo "  ✅ TLS CA server initialized successfully."
