#!/bin/bash
set -e

echo "  🚀 Starting CA setup process on $IP for $ORG..."

# Create CA directory
echo "  📁 Ensuring CA directory exists: ~/$CA_DIR"
mkdir -p ~/$CA_DIR
mkdir -p ~/$CA_DIR/tls

# Debug: Show TLS directory contents
echo "  🔎 Contents of ~/$CA_DIR/tls:"
ls -la ~/$CA_DIR/tls/

# Copy fabric-ca-server binary
echo "  📄 Copying fabric-ca-server binary..."
cp $REMOTE_BIN_DIR/fabric-ca-server ~/$CA_DIR/

cd ~/$CA_DIR

# Verify TLS cert and key
echo "  🔎 Verifying TLS certificate and key..."
if [ ! -f tls/cert.pem ]; then echo "  ⛔ TLS cert missing"; exit 1; fi
if [ ! -f tls/key.pem ]; then echo "  ⛔ TLS key missing"; exit 1; fi
echo "  ✅ TLS certificate and key found."

# Initialize CA server if config doesn't exist
if [ ! -f fabric-ca-server-config.yaml ]; then
    echo "  🚀 Initializing CA server configuration..."
    ./fabric-ca-server init -b $BOOTSTRAP_USER:$BOOTSTRAP_PASS
else
    echo "  ℹ️ CA server configuration file already exists, skipping init."
fi

# Configure CA server
echo "  ⚙️ Applying custom configuration..."
yq eval '
  .tls.enabled = true |
  .tls.certfile = "tls/cert.pem" |
  .tls.keyfile = "tls/key.pem" |
  .ca.name = "${ORG}-ca" |
  .csr.cn = "${ORG}-ca" |
  .csr.hosts = ["localhost", "$CSR_HOSTNAME"] |
  .csr.names[0].C = "ID" |
  .csr.names[0].ST = "East Java" |
  .csr.names[0].L = "Surabaya" |
  .csr.names[0].O = "YDSF"
' -i fabric-ca-server-config.yaml

# Remove old artifacts
echo "  🗑️ Removing old certificates and MSP to force regeneration..."
rm -rf msp/ ca-cert.pem IssuerPublicKey IssuerRevocationPublicKey fabric-ca-server.db

# Start CA server
echo "  ▶️ Starting the CA server..."
nohup ./fabric-ca-server start -b $BOOTSTRAP_USER:$BOOTSTRAP_PASS >> fabric-ca-server-${ORG}.log 2>&1 &
PID=$!
echo $PID > fabric-ca-server-${ORG}.pid

# Verify process started
sleep 2
if ps -p $PID > /dev/null; then
   echo "  ✅ ${ORG} CA server started successfully with PID $PID."
   echo "  🪵 ${ORG} CA server logs are being written to fabric-ca-server-${ORG}.log"
else
   echo "  ⛔ ${ORG} CA server failed to start. Check logs for details."
   exit 1
fi
