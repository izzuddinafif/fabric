#!/bin/bash
# Script 22: Package Chaincode

set -e # Exit on error

echo "🚀 Packaging Chaincode..."

# Define paths and variables
FABRIC_CFG_PATH="$HOME/fabric/config" # Needed for peer command config resolution
CHAINCODE_NAME="zakat" # Corrected chaincode name based on directory
CHAINCODE_VERSION="2.1"
CHAINCODE_LANG="golang"
# Path to the chaincode source code directory
CHAINCODE_SRC_PATH="$HOME/fabric/chaincode/${CHAINCODE_NAME}" # Corrected path
# Output directory for the packaged chaincode
CHAINCODE_PACKAGE_DIR="$HOME/fabric/chaincode-packages"
# Output package file name
CHAINCODE_LABEL="${CHAINCODE_NAME}_${CHAINCODE_VERSION}" # e.g., zakat_1.0
CHAINCODE_PACKAGE_FILE="${CHAINCODE_PACKAGE_DIR}/${CHAINCODE_LABEL}.tar.gz"

# Log file
LOG_DIR="$HOME/fabric/logs"
LOG_FILE="$LOG_DIR/22-package-chaincode.log"
mkdir -p $LOG_DIR $CHAINCODE_PACKAGE_DIR
touch $LOG_FILE

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Chaincode Packaging Script (22)"

# Check if peer binary exists
log "🔎 Checking for peer binary..."
if ! command -v peer &> /dev/null; then
    log "⛔ Error: peer command not found. Make sure Fabric binaries are in your PATH."
    exit 1
fi
log "✅ peer binary found."

# Check if chaincode source directory exists
log "🔎 Checking for chaincode source directory: $CHAINCODE_SRC_PATH"
if [ ! -d "$CHAINCODE_SRC_PATH" ]; then
    log "⛔ Error: Chaincode source directory not found at $CHAINCODE_SRC_PATH"
    exit 1
fi
# Optional: Check for go.mod if it's Go chaincode
if [ "$CHAINCODE_LANG" == "golang" ]; then
    if [ ! -f "$CHAINCODE_SRC_PATH/go.mod" ]; then
        log "⚠️ Warning: go.mod file not found in $CHAINCODE_SRC_PATH. Packaging might fail if dependencies are not vendored or resolvable."
    fi
fi
log "✅ Chaincode source directory found."

# Package the chaincode
log "📦 Packaging chaincode '$CHAINCODE_NAME' version '$CHAINCODE_VERSION'..."
log "   Source: $CHAINCODE_SRC_PATH"
log "   Output: $CHAINCODE_PACKAGE_FILE"
log "   Label: $CHAINCODE_LABEL"

# Execute the packaging command
# The FABRIC_CFG_PATH is set to ensure peer can find core.yaml if needed, though package doesn't strictly require it.
FABRIC_CFG_PATH=$FABRIC_CFG_PATH peer lifecycle chaincode package \
    "$CHAINCODE_PACKAGE_FILE" \
    --path "$CHAINCODE_SRC_PATH" \
    --lang "$CHAINCODE_LANG" \
    --label "$CHAINCODE_LABEL" >> $LOG_FILE 2>&1

if [ $? -ne 0 ]; then
    log "⛔ Error: Failed to package chaincode. Check logs ($LOG_FILE)."
    exit 1
fi

# Verify the package file was created
log "🔎 Verifying package file creation..."
if [ ! -f "$CHAINCODE_PACKAGE_FILE" ]; then
    log "⛔ Error: Chaincode package file was not created at $CHAINCODE_PACKAGE_FILE."
    exit 1
fi
ls -l "$CHAINCODE_PACKAGE_FILE" >> $LOG_FILE # Log file details
log "✅ Chaincode packaged successfully: $CHAINCODE_PACKAGE_FILE"

log "🎉 Chaincode packaging complete!"
log "----------------------------------------"

exit 0
