#!/bin/bash
# Script 03: Enroll TLS CA Admin
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

# Define variables
CA_CLIENT_HOME="$HOME/fabric/fabric-ca-client"
CA_SERVER_HOME="$HOME/fabric/fabric-ca-server-tls"
TLS_ADMIN_HOME="$CA_CLIENT_HOME/tls-ca/tlsadmin"
TLS_CERT_PATH="$CA_CLIENT_HOME/tls-root-cert"
CA_HOST="tls-ca.${ORDERER_DOMAIN}"
CA_PORT=7054

# Function to check if CA server is available
check_ca_server() {
    local host=$1
    local port=$2
    local max_attempts=10
    local count=0

    echo "⏳ Waiting for TLS CA server to be ready..."
    while [ $count -lt $max_attempts ]; do
        if curl -sk https://$host:$port/cainfo > /dev/null 2>&1; then
            echo "✅ TLS CA server is ready at $host:$port"
            return 0
        fi
        echo "⏳ Attempt $((count + 1))/$max_attempts - Server not ready yet..."
        sleep 2
        count=$((count + 1))
    done

    echo "⛔ TLS CA server is not responding at $host:$port"
    return 1
}

# Function to verify binary exists
verify_binary() {
    local binary=$1
    local search_paths=("$HOME/bin" "$HOME/fabric/bin" "/usr/local/bin")
    
    for path in "${search_paths[@]}"; do
        if [ -f "$path/$binary" ]; then
            echo "$path/$binary"
            return 0
        fi
    done
    
    echo ""
    return 1
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
    
    # Verify key and certificate files exist
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

echo "🚀 Starting TLS admin enrollment process..."

# Check if TLS CA server is available
check_ca_server $CA_HOST $CA_PORT || exit 1

# Verify directories exist
if [ ! -d "$CA_SERVER_HOME" ]; then
    echo "⛔ TLS CA server directory not found: $CA_SERVER_HOME"
    exit 1
fi

# Create required directories
echo "📁 Creating required directories..."
mkdir -p "$CA_CLIENT_HOME"
mkdir -p "$TLS_ADMIN_HOME/msp"
mkdir -p "$TLS_CERT_PATH"

# Check for existing enrollment
if [ -d "$TLS_ADMIN_HOME/msp" ] && verify_enrollment "$TLS_ADMIN_HOME/msp"; then
    echo "✅ TLS admin already enrolled successfully."
    exit 0
fi

# Copy TLS CA certificate
echo "📄 Copying CA certificate..."
cp "$CA_SERVER_HOME/ca-cert.pem" "$TLS_CERT_PATH/tls-ca-cert.pem"

# Locate and copy fabric-ca-client binary
if [ ! -f "$CA_CLIENT_HOME/fabric-ca-client" ]; then
    BINARY_PATH=$(verify_binary "fabric-ca-client")
    if [ -z "$BINARY_PATH" ]; then
        echo "⛔ fabric-ca-client binary not found in search paths"
        exit 1
    fi
    echo "📄 Copying fabric-ca-client binary from $BINARY_PATH..."
    cp "$BINARY_PATH" "$CA_CLIENT_HOME/"
fi

# Set up environment and perform enrollment
cd "$CA_CLIENT_HOME"
export FABRIC_CA_CLIENT_HOME="$PWD"

echo "🔐 Enrolling TLS admin..."
./fabric-ca-client enroll -d \
    -u "https://tls-admin:tls-adminpw@$CA_HOST:$CA_PORT" \
    --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
    --mspdir "tls-ca/tlsadmin/msp" \
    --enrollment.profile tls

# Verify enrollment success
if verify_enrollment "$TLS_ADMIN_HOME/msp"; then
    echo "✅ TLS admin enrolled successfully!"
    echo "📂 MSP Directory: $TLS_ADMIN_HOME/msp"
    echo "🔒 TLS Root Cert: $TLS_CERT_PATH/tls-ca-cert.pem"
else
    echo "⛔ TLS admin enrollment verification failed"
    exit 1
fi

exit 0
