#!/bin/bash
# Script 06: Start Orderer CA Server
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

# Define variables
CA_HOME="$HOME/fabric/fabric-ca-server-orderer"
PID_FILE="$CA_HOME/fabric-ca-server-orderer.pid"
LOG_FILE="$CA_HOME/fabric-ca-server-orderer.log"
CA_PORT=7055
OPS_PORT=9444

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -i ":$port" > /dev/null; then
        echo "⚠️ Port $port is in use. Attempting to free it..."
        sudo kill $(lsof -t -i:$port) || true
        sleep 2
        if lsof -i ":$port" > /dev/null; then
            echo "⛔ Failed to free port $port"
            return 1
        fi
    fi
    return 0
}

# Function to verify CA server is running
verify_ca_running() {
    local pid=$1
    local count=0
    local max_attempts=10
    
    while [ $count -lt $max_attempts ]; do
        if ! ps -p $pid > /dev/null; then
            echo "⛔ CA server process died"
            if [ -f "$LOG_FILE" ]; then
                echo "Last few log lines:"
                tail -n 5 "$LOG_FILE"
            fi
            return 1
        fi
        
        # Check if server is responding
        if curl -sk https://localhost:$CA_PORT/cainfo > /dev/null 2>&1; then
            echo "✅ CA server is responding on port $CA_PORT"
            return 0
        fi
        
        echo "⏳ Waiting for CA server to start... (attempt $((count + 1))/$max_attempts)"
        sleep 2
        count=$((count + 1))
    done
    
    echo "⛔ CA server failed to respond within expected time"
    return 1
}

# Function to verify and install yq
ensure_yq_installed() {
    if ! command -v yq &> /dev/null; then
        echo "📦 yq not found, installing..."
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
        if ! command -v yq &> /dev/null; then
            echo "⛔ Failed to install yq"
            return 1
        fi
        echo "✅ yq installed successfully"
    fi
    return 0
}

# Function to update CA configuration
update_ca_config() {
    echo "⚙️ Configuring Orderer CA server..."
    yq eval '
        .port = 7055 |
        .tls.enabled = true |
        .tls.certfile = "tls/cert.pem" |
        .tls.keyfile = "tls/key.pem" |
        .ca.name = "orderer-ca" |
        .operations.listenAddress = "0.0.0.0:9444" |
        .csr.hosts = ["localhost", "ca.'$ORDERER_HOSTNAME'"] |
        .csr.cn = "orderer-ca" |
        .csr.names[0].C = "ID" |
        .csr.names[0].ST = "East Java" |
        .csr.names[0].L = "Surabaya" |
        .csr.names[0].O = "YDSF"
    ' -i fabric-ca-server-config.yaml
    
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to update CA configuration"
        return 1
    fi
    echo "✅ CA configuration updated successfully"
    return 0
}

echo "🚀 Starting Orderer CA Server..."

# Check if we're in the right directory
if [ ! -d "$CA_HOME" ]; then
    echo "⛔ Orderer CA directory not found: $CA_HOME"
    exit 1
fi
cd "$CA_HOME"

# Check if server is already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p $OLD_PID > /dev/null; then
        echo "✅ Orderer CA server is already running with PID $OLD_PID"
        exit 0
    else
        echo "🗑️ Removing stale PID file"
        rm "$PID_FILE"
    fi
fi

# Check and free required ports
echo "🔍 Checking required ports..."
check_port $CA_PORT || exit 1
check_port $OPS_PORT || exit 1

# Install yq if needed and update configuration
ensure_yq_installed || exit 1

# Update configuration if needed
if [[ $(yq eval '.tls.enabled' fabric-ca-server-config.yaml) == "false" ]]; then
    update_ca_config || exit 1
    
    # Clean up old certificates
    echo "🧹 Cleaning up old certificates..."
    rm -rf msp/ ca-cert.pem
fi

# Start the CA server
echo "▶️ Starting Orderer CA server..."
nohup ./fabric-ca-server start >> "$LOG_FILE" 2>&1 &
PID=$!
echo $PID > "$PID_FILE"

# Verify server started successfully
if verify_ca_running $PID; then
    echo "🎉 Orderer CA server started successfully!"
    echo "📋 Logs are being written to: $LOG_FILE"
    echo "🔍 Monitor logs with: tail -f $LOG_FILE"
else
    echo "⛔ Failed to start Orderer CA server"
    exit 1
fi

exit 0
