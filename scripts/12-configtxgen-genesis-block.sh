#!/bin/bash

# Ensure the config directory and configtx.yaml exist
if ! [ -f "$HOME/config/configtx.yaml" ]; then
    echo "Configuration file $HOME/config/configtx.yaml not found. Exiting."
    exit 1
fi

# Ensure the output directory exists (or create it)
mkdir -p $HOME/config

# Check if genesis block already exists
if [ -f "$HOME/config/genesis.block" ]; then
    echo "Genesis block $HOME/config/genesis.block already exists. Exiting."
    exit 1
fi

# Check if configtxgen binary exists (assuming it's in $HOME/bin)
# Adjust path if necessary
CONFIGTXGEN_PATH="$HOME/bin/configtxgen"
if ! [ -x "$CONFIGTXGEN_PATH" ]; then
    echo "configtxgen binary not found or not executable at $CONFIGTXGEN_PATH"
    echo "Please ensure Hyperledger Fabric binaries are installed and in the correct location."
    exit 1
fi


echo "Generating genesis block for the system channel..."

# Set the FABRIC_CFG_PATH environment variable to the directory containing configtx.yaml
export FABRIC_CFG_PATH=$HOME/config

# Execute configtxgen
# -profile: Specifies the profile in configtx.yaml to use (OneOrgOrdererGenesis)
# -channelID: Specifies the ID for the system channel (system-channel)
# -outputBlock: Specifies the path where the genesis block will be saved
"$CONFIGTXGEN_PATH" -profile OneOrgOrdererGenesis -channelID system-channel -outputBlock $HOME/config/genesis.block

# Check if the command was successful
if [ $? -ne 0 ]; then
    echo "Failed to generate genesis block."
    exit 1
else
    echo "Genesis block successfully generated at $HOME/config/genesis.block"
fi

# Unset FABRIC_CFG_PATH (optional, good practice)
unset FABRIC_CFG_PATH
