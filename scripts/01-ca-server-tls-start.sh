#!/bin/bash
# Script 01: Start TLS CA Server
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

# Define variables
CA_HOME="$HOME/fabric/fabric-ca-server-tls"
PID_FILE="$CA_HOME/fabric-ca-server-tls.pid"
LOG_FILE="$CA_HOME/fabric-ca-server-tls.log"
CA_PORT=7054
OPS_PORT=9443

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

echo "🚀 Starting TLS CA Server..."

# Check if we're in the right directory
if [ ! -d "$CA_HOME" ]; then
    echo "⛔ TLS CA directory not found: $CA_HOME"
    exit 1
fi
cd "$CA_HOME"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "📦 yq could not be found, installing..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi

# Check if server is already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p $OLD_PID > /dev/null; then
        echo "✅ TLS CA server is already running with PID $OLD_PID"
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

# Verify configuration
echo "⚙️ Verifying CA server configuration..."
if [ ! -f fabric-ca-server-config.yaml ]; then
    echo "⛔ Configuration file not found. Please run 00-ca-server-tls-init.sh first"
    exit 1
fi

# Update configuration if needed
echo "📝 Updating CA server configuration..."
yq eval '
    .tls.enabled = true |
    del(.signing.profiles.ca) |
    .ca.name = "tls-ca" |
    .csr.hosts = ["localhost", "tls-ca.'$ORDERER_DOMAIN'"] |
    .csr.names[0].C = "ID" |
    .csr.names[0].ST = "East Java" |
    .csr.names[0].L = "Surabaya" |
    .csr.names[0].O = "YDSF"
' -i fabric-ca-server-config.yaml

# Start the TLS CA server
echo "▶️ Starting TLS CA server..."
nohup ./fabric-ca-server start >> "$LOG_FILE" 2>&1 &
PID=$!
echo $PID > "$PID_FILE"

# Verify server started successfully
if verify_ca_running $PID; then
    echo "🎉 TLS CA server started successfully!"
    echo "📋 Logs are being written to: $LOG_FILE"
    echo "🔍 Monitor logs with: tail -f $LOG_FILE"
else
    echo "⛔ Failed to start TLS CA server"
    exit 1
fi

exit 0
