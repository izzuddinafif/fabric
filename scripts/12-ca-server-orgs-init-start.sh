#!/bin/bash

declare -A ORGS=(
    ["10.104.0.2"]="org1"
    ["10.104.0.4"]="org2"
)

REMOTE_BIN_DIR="~/bin"
CA_CLIENT_DIR="~/fabric/fabric-ca-client"
BOOTSTRAP_PASS_SUFFIX="pw"  # e.g., btstrp-org1:org1pw

for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    CA_DIR="fabric/fabric-ca-server-$ORG"
    BOOTSTRAP_USER="btstrp-$ORG"
    BOOTSTRAP_PASS="${ORG}${BOOTSTRAP_PASS_SUFFIX}"
    CSR_HOSTNAME="ca.${ORG}.fabriczakat.local"

    echo "🚀 Initializing and starting CA for $ORG at $IP..."

    # Important: Use multiple SSH commands to debug and verify
    # Check what files actually exist in the TLS directory
    echo "  🔎 Checking remote TLS directory contents..."
    ssh "fabricadmin@$IP" "ls -la ~/fabric/fabric-ca-server-$ORG/tls/ 2>/dev/null || echo '  ℹ️ Remote TLS directory does not exist or is empty'"
    
    # Run the main script with the triple quotes approach
    ssh "fabricadmin@$IP" """
set -e # Exit immediately if a command exits with a non-zero status.

echo \"  🚀 Starting CA setup process on $IP for $ORG...\"

# Create and enter CA dir (do not remove existing dir to preserve TLS certs)
echo \"  📁 Ensuring CA directory exists: ~/$CA_DIR\"
mkdir -p ~/$CA_DIR
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to create directory ~/$CA_DIR\"; exit 1; fi
echo \"  ✅ CA directory ensured.\"

echo \"  📁 Ensuring TLS directory exists: ~/$CA_DIR/tls\"
mkdir -p ~/$CA_DIR/tls
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to create directory ~/$CA_DIR/tls\"; exit 1; fi
echo \"  ✅ TLS directory ensured.\"

# Debug: Show what's in the TLS directory
echo \"  🔎 Contents of ~/$CA_DIR/tls:\"
ls -la ~/$CA_DIR/tls/

# Copy the fabric-ca-server binary
echo \"  📄 Copying fabric-ca-server binary...\"
cp $REMOTE_BIN_DIR/fabric-ca-server ~/$CA_DIR/
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to copy fabric-ca-server binary\"; exit 1; fi
echo \"  ✅ fabric-ca-server binary copied.\"

# Debug: Show where we're looking for the TLS certs
echo \"  🔎 Checking for TLS cert at ~/$CA_DIR/tls/cert.pem\"
echo \"  🔎 Checking for TLS key at ~/$CA_DIR/tls/key.pem\"

cd ~/$CA_DIR

# Ensure TLS cert and key exist
echo \"  🔎 Verifying TLS certificate and key...\"
if [ ! -f tls/cert.pem ]; then echo \"  ⛔ TLS cert missing in ~/$CA_DIR/tls.\"; exit 1; fi
if [ ! -f tls/key.pem ]; then echo \"  ⛔ TLS key missing in ~/$CA_DIR/tls.\"; exit 1; fi
echo \"  ✅ TLS certificate and key found.\"

# Install yq if missing
if ! command -v yq &> /dev/null; then
    echo \"  🔧 yq not found. Installing yq...\"
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to download yq\"; exit 1; fi
    sudo chmod +x /usr/local/bin/yq
    if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to make yq executable\"; exit 1; fi
    echo \"  ✅ yq installed.\"
else
    echo \"  ✅ yq is already installed.\"
fi

# First time initialization if config doesn't exist
if [ ! -f fabric-ca-server-config.yaml ]; then
    echo \"  🚀 Initializing CA server configuration...\"
    ./fabric-ca-server init -b $BOOTSTRAP_USER:$BOOTSTRAP_PASS
    if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to initialize CA server\"; exit 1; fi
    echo \"  ✅ CA server initialized.\"
else
    echo \"  ℹ️ CA server configuration file already exists, skipping init.\"
fi

# Apply custom configuration - always update
echo \"  ⚙️ Applying custom configuration using yq...\"
yq eval '.tls.enabled = true' -i fabric-ca-server-config.yaml && \
yq eval '.tls.certfile = \"tls/cert.pem\"' -i fabric-ca-server-config.yaml && \
yq eval '.tls.keyfile = \"tls/key.pem\"' -i fabric-ca-server-config.yaml && \
yq eval '.ca.name = \"${ORG}-ca\"' -i fabric-ca-server-config.yaml && \
yq eval '.csr.cn = \"${ORG}-ca\"' -i fabric-ca-server-config.yaml && \
yq eval '.csr.hosts = [\"localhost\", \"$CSR_HOSTNAME\"]' -i fabric-ca-server-config.yaml && \
yq eval '.csr.names[0].C = \"ID\" | .csr.names[0].ST = \"East Java\" | .csr.names[0].L = \"Surabaya\" | .csr.names[0].O= \"YDSF\"' -i fabric-ca-server-config.yaml
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to apply configuration updates with yq\"; exit 1; fi
echo \"  ✅ Custom configuration applied.\"

# Remove old certs and MSP to force regeneration with new settings
echo \"  🗑️ Removing old certificates and MSP to force regeneration...\"
rm -rf msp/ ca-cert.pem IssuerPublicKey IssuerRevocationPublicKey fabric-ca-server.db
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to remove old artifacts\"; exit 1; fi
echo \"  ✅ Old artifacts removed.\"

# Start the CA server
echo \"  ▶️ Starting the CA server...\"
nohup ./fabric-ca-server start -b $BOOTSTRAP_USER:$BOOTSTRAP_PASS >> fabric-ca-server-${ORG}.log 2>&1 &
PID=\$!
echo \$PID > fabric-ca-server-${ORG}.pid
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to start CA server or write PID file\"; exit 1; fi

# Check if the process started
sleep 2 # Give it a moment to potentially fail
if ps -p \$PID > /dev/null; then
   echo \"  ✅ ${ORG} CA server started successfully with PID \$PID.\"
   echo \"  🪵 ${ORG} CA server logs are being written to fabric-ca-server-${ORG}.log\"
else
   echo \"  ⛔ ${ORG} CA server failed to start. Check fabric-ca-server-${ORG}.log for details.\"
   exit 1
fi
"""

    # Check the exit status of the SSH command
    if [ $? -eq 0 ]; then
        echo "✅ Successfully initialized and started CA for $ORG at $IP."
    else
        echo "⛔ Failed to initialize or start CA for $ORG at $IP. Check logs on the remote machine."
    fi
    echo "-----------------------------------------------------"

done

echo "🎉 All organization CAs processed."
