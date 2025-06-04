#!/bin/bash
# Script 02: Stop TLS CA Server
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

# Define variables
CA_HOME="$HOME/fabric/fabric-ca-server-tls"
PID_FILE="$CA_HOME/fabric-ca-server-tls.pid"
LOG_FILE="$CA_HOME/fabric-ca-server-tls.log"
CA_PORT=7054

# Function to check if process is running
is_process_running() {
    local pid=$1
    if [ -z "$pid" ]; then
        return 1
    fi
    if ps -p $pid > /dev/null; then
        return 0
    fi
    return 1
}

# Function to verify port is free
verify_port_free() {
    local port=$1
    if lsof -i ":$port" > /dev/null; then
        return 1
    fi
    return 0
}

echo "🛑 Stopping TLS CA Server..."

# Check if we're in the right directory
if [ ! -d "$CA_HOME" ]; then
    echo "⛔ TLS CA directory not found: $CA_HOME"
    exit 1
fi
cd "$CA_HOME"

# Check if server is running
if [ ! -f "$PID_FILE" ]; then
    echo "ℹ️ No PID file found, checking for running process on port $CA_PORT..."
    if verify_port_free $CA_PORT; then
        echo "✅ No TLS CA server running."
        exit 0
    else
        echo "⚠️ Process found on port $CA_PORT, attempting to stop it..."
        sudo kill $(lsof -t -i:$CA_PORT) || true
    fi
else
    PID=$(cat "$PID_FILE")
    if is_process_running $PID; then
        echo "🔄 Stopping TLS CA server with PID $PID..."
        kill $PID || sudo kill $PID
        
        # Wait for process to stop
        count=0
        while is_process_running $PID && [ $count -lt 10 ]; do
            echo "⏳ Waiting for process to stop..."
            sleep 1
            count=$((count + 1))
        done
        
        if is_process_running $PID; then
            echo "⚠️ Process still running, attempting force stop..."
            kill -9 $PID || sudo kill -9 $PID
        fi
    else
        echo "ℹ️ Process $PID not running"
    fi
    echo "🗑️ Removing PID file"
    rm -f "$PID_FILE"
fi

# Verify port is free
echo "🔍 Verifying CA port is free..."
if ! verify_port_free $CA_PORT; then
    echo "⚠️ Port $CA_PORT still in use, attempting force cleanup..."
    sudo kill -9 $(lsof -t -i:$CA_PORT) || true
    sleep 1
    if ! verify_port_free $CA_PORT; then
        echo "⛔ Failed to free port $CA_PORT"
        exit 1
    fi
fi

echo "✅ TLS CA server stopped successfully"
echo ""
echo "To completely remove the CA server:"
echo "cd $CA_HOME/..; rm -rf fabric-ca-server-tls/; rm -f fabric-ca-server-tls.log"
echo ""
echo "Note: This will delete all certificates and keys. Make sure you have backups if needed."
echo "----------------------------------------"

exit 0
