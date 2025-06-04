#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/configtx-utils.sh"

echo "🔧 Generating Genesis Block and Channel Artifacts..."

# Set environment variables
export FABRIC_CFG_PATH=$HOME/fabric/config
CHANNEL_NAME="zakatchannel"
OUTPUT_DIR=$HOME/fabric/channel-artifacts
MSP_DIR=$HOME/fabric/organizations # Used implicitly by configtx.yaml relative paths

# Make sure the output directory exists
echo "📁 Ensuring output directory exists: $OUTPUT_DIR"
mkdir -p $OUTPUT_DIR || {
    echo "⛔ Failed to create output directory $OUTPUT_DIR"
    exit 1
}
echo "✅ Output directory ensured."

# Check for configtx.yaml
echo "🔎 Checking for configtx.yaml in $FABRIC_CFG_PATH..."
if [ ! -f "$FABRIC_CFG_PATH/configtx.yaml" ]; then
    echo "  ⚠️ configtx.yaml not found. Creating it now..."
    
    generate_configtx_yaml "$FABRIC_CFG_PATH/configtx.yaml" "zakat" || {
        echo "  ⛔ Failed to create configtx.yaml file."
        exit 1
    }
    echo "  ✅ configtx.yaml created successfully."
else
    echo "  ✅ configtx.yaml already exists."
fi

# Verify prerequisites
echo "🔎 Verifying prerequisites..."
verify_configtx_prerequisites "$MSP_DIR" || {
    echo "⛔ Prerequisites check failed."
    exit 1
}
echo "✅ Prerequisites verified."

# Generate artifacts
echo "📝 Generating channel artifacts..."
generate_artifacts "$OUTPUT_DIR" "$CHANNEL_NAME" "Zakat" || {
    echo "⛔ Failed to generate channel artifacts."
    exit 1
}

echo "🎉 Genesis block and channel artifacts generated successfully!"
echo ""
echo "Summary of artifacts:"
echo "- Genesis Block: $OUTPUT_DIR/genesis.block"
echo "- Channel Transaction: $OUTPUT_DIR/${CHANNEL_NAME}.tx"
echo "- Org1 Anchor Peer Update: $OUTPUT_DIR/Org1MSPanchors.tx"
echo "- Org2 Anchor Peer Update: $OUTPUT_DIR/Org2MSPanchors.tx"
echo ""
echo "Next Steps:"
echo "1. Start the orderer with the genesis block"
echo "2. Create the channel using the channel transaction"
echo "3. Join peers to the channel"
echo "4. Update anchor peers using the anchor peer transactions"
