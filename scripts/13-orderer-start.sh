#!/bin/bash

# Ensure the config directory and necessary files exist
if ! [ -f "$HOME/config/orderer.yaml" ]; then
    echo "Orderer configuration file $HOME/config/orderer.yaml not found. Exiting."
    exit 1
fi
if ! [ -f "$HOME/config/genesis.block" ]; then
    echo "Genesis block $HOME/config/genesis.block not found. Did you run script 12?"
    exit 1
fi

# Ensure the orderer's MSP and TLS directories exist
if ! [ -d "$HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp" ]; then
    echo "Orderer MSP directory not found. Did you run script 10?"
    exit 1
fi
if ! [ -d "$HOME/fabric-ca-client/orderer-ca/orderer0.example.local/tls" ]; then
    echo "Orderer TLS directory not found. Did you run script 11?"
    exit 1
fi

# Check if orderer binary exists (assuming it's in $HOME/bin)
# Adjust path if necessary
ORDERER_PATH="$HOME/bin/orderer"
if ! [ -x "$ORDERER_PATH" ]; then
    echo "orderer binary not found or not executable at $ORDERER_PATH"
    echo "Please ensure Hyperledger Fabric binaries are installed and in the correct location."
    exit 1
fi

# Create production directories if they don't exist (as specified in orderer.yaml)
mkdir -p $HOME/production/orderer0.example.local/ledger
mkdir -p $HOME/production/orderer0.example.local/etcdraft/wal
mkdir -p $HOME/production/orderer0.example.local/etcdraft/snapshot

# Check if orderer is already running (simple check based on pid file)
PID_FILE="$HOME/production/orderer0.example.local/orderer.pid"
if [ -f "$PID_FILE" ] && ps -p $(cat "$PID_FILE") > /dev/null; then
   echo "Orderer seems to be already running with PID $(cat "$PID_FILE"). Exiting."
   exit 1
fi

echo "Starting the orderer node (orderer0.example.local)..."

# Set the FABRIC_CFG_PATH environment variable to the directory containing orderer.yaml
export FABRIC_CFG_PATH=$HOME/config

# Start the orderer in the background
# Redirect stdout and stderr to a log file
LOG_FILE="$HOME/production/orderer0.example.local/orderer.log"
nohup "$ORDERER_PATH" start > "$LOG_FILE" 2>&1 &

# Save the PID of the background process
echo $! > "$PID_FILE"

# Give it a moment to start up
sleep 2

# Check if the process started successfully
if ps -p $(cat "$PID_FILE") > /dev/null; then
   echo "Orderer started successfully with PID $(cat "$PID_FILE")."
   echo "Logs are being written to: $LOG_FILE"
else
   echo "Failed to start orderer. Check the log file for errors: $LOG_FILE"
   rm -f "$PID_FILE" # Remove PID file if start failed
   exit 1
fi

# Unset FABRIC_CFG_PATH (optional, good practice)
unset FABRIC_CFG_PATH
