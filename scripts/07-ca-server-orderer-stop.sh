#!/bin/bash
# Script 07: Stop Orderer CA Server
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

# Define variables
CA_HOME="$HOME/fabric/fabric-ca-server-orderer"
PID_FILE="$CA_HOME/fabric-ca-server-orderer.pid"
LOG_FILE="$CA_HOME/fabric-ca-server-orderer.log"
CA_PORT=7055
OPS_PORT=9444

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

# Function to stop process using port
stop_process_on_port() {
    local port=$1
    if ! verify_port_free $port; then
        echo "⚠️ Port $port still in use, attempting to free it..."
        sudo kill $(lsof -t -i:$port) || true
        sleep 2
        if ! verify_port_free $port; then
            echo "⚠️ Attempting force kill on port $port..."
            sudo kill -9 $(lsof -t -i:$port) || true
            sleep 1
        fi
    fi
}

echo "🛑 Stopping Orderer CA Server..."

# Check if we're in the right directory
if [ ! -d "$CA_HOME" ]; then
    echo "⛔ Orderer CA directory not found: $CA_HOME"
    exit 1
fi
cd "$CA_HOME"

# Check if server is running from PID file
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if is_process_running $PID; then
        echo "🔄 Stopping Orderer CA server with PID $PID..."
        kill $PID || sudo kill $PID
        
        # Wait for process to stop
        count=0
        while is_process_running $PID && [ $count -lt 10 ]; do
            echo "⏳ Waiting for process to stop... (attempt $((count + 1))/10)"
            sleep 1
            count=$((count + 1))
        done
        
        if is_process_running $PID; then
            echo "⚠️ Process still running, attempting force stop..."
            kill -9 $PID || sudo kill -9 $PID
            sleep 1
        fi
    else
        echo "ℹ️ Process $PID not running"
    fi
    echo "🗑️ Removing PID file"
    rm -f "$PID_FILE"
else
    echo "ℹ️ No PID file found"
fi

# Ensure ports are free
echo "🔍 Verifying ports are free..."
stop_process_on_port $CA_PORT
stop_process_on_port $OPS_PORT

# Final verification
PORTS_FREE=true
for port in $CA_PORT $OPS_PORT; do
    if ! verify_port_free $port; then
        echo "⛔ Port $port is still in use"
        PORTS_FREE=false
    fi
done

if $PORTS_FREE; then
    echo "✅ Orderer CA server stopped successfully"
    echo ""
    echo "To completely remove the CA server:"
    echo "cd $CA_HOME/..; rm -rf fabric-ca-server-orderer/; rm -f fabric-ca-server-orderer.log"
    echo ""
    echo "Note: This will delete all certificates and keys. Make sure you have backups if needed."
else
    echo "⚠️ Some ports are still in use. Check running processes manually."
    exit 1
fi

echo "----------------------------------------"
exit 0
