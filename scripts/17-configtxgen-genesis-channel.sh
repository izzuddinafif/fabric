#!/bin/bash
# Script 17: Generate Genesis Block and Channel Artifacts

set -e # Exit on error

echo "🔧 Generating Genesis Block and Channel Artifacts..."

# Set environment variables
export FABRIC_CFG_PATH=$HOME/fabric/config
CHANNEL_NAME="zakatchannel"
OUTPUT_DIR=$HOME/fabric/channel-artifacts
MSP_DIR=$HOME/fabric/organizations # Used implicitly by configtx.yaml relative paths

# Make sure the output directory exists
echo "📁 Ensuring output directory exists: $OUTPUT_DIR"
mkdir -p $OUTPUT_DIR
if [ $? -ne 0 ]; then echo "⛔ Failed to create output directory $OUTPUT_DIR"; exit 1; fi
echo "✅ Output directory ensured."

# Check if configtx.yaml exists
echo "🔎 Checking for configtx.yaml in $FABRIC_CFG_PATH..."
if [ ! -f "$FABRIC_CFG_PATH/configtx.yaml" ]; then
    echo "  ⚠️ configtx.yaml not found. Creating it now..."
    
    # Create configtx.yaml based on our network
    cat > "$FABRIC_CFG_PATH/configtx.yaml" << 'EOF'
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

---
################################################################################
#
#   Section: Organizations
#
################################################################################
Organizations:
    - &OrdererOrg
        # Name is the key by which this org will be referenced in channel configuration
        Name: OrdererOrg
        # ID is the key by which this org's MSP definition will be referenced
        ID: OrdererMSP
        # MSPDir is the filesystem path which contains the MSP configuration
        MSPDir: ../organizations/ordererOrganizations/fabriczakat.local/msp
        # Policies defines the set of policies at this level of the config tree
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Writers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Admins:
                Type: Signature
                Rule: "OR('OrdererMSP.admin')"
        OrdererEndpoints:
            - orderer.fabriczakat.local:7050

    - &Org1
        # Name is the key by which this org will be referenced in channel configuration
        Name: Org1MSP
        # ID is the key by which this org's MSP definition will be referenced
        ID: Org1MSP
        # MSPDir is the filesystem path which contains the MSP configuration
        MSPDir: ../organizations/peerOrganizations/org1.fabriczakat.local/msp
        # Policies defines the set of policies at this level of the config tree
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org1MSP.admin', 'Org1MSP.peer', 'Org1MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org1MSP.admin', 'Org1MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org1MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org1MSP.peer')"
        # AnchorPeers defines the location of peers which can be used for cross-org gossip communication
        AnchorPeers:
            - Host: peer.org1.fabriczakat.local
              Port: 7051

    - &Org2
        # Name is the key by which this org will be referenced in channel configuration
        Name: Org2MSP
        # ID is the key by which this org's MSP definition will be referenced
        ID: Org2MSP
        # MSPDir is the filesystem path which contains the MSP configuration
        MSPDir: ../organizations/peerOrganizations/org2.fabriczakat.local/msp
        # Policies defines the set of policies at this level of the config tree
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.peer', 'Org2MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org2MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org2MSP.peer')"
        # AnchorPeers defines the location of peers which can be used for cross-org gossip communication
        AnchorPeers:
            - Host: peer.org2.fabriczakat.local
              Port: 7051

################################################################################
#
#   SECTION: Capabilities
#
################################################################################
Capabilities:
    # Channel capabilities apply to both the orderers and the peers and must be
    # supported by both.
    Channel: &ChannelCapabilities
        V2_0: true

    # Orderer capabilities apply only to the orderers, and may be safely
    # used with prior release peers.
    Orderer: &OrdererCapabilities
        V2_0: true

    # Application capabilities apply only to the peer network, and may be safely
    # used with prior release orderers.
    Application: &ApplicationCapabilities
        V2_0: true

################################################################################
#
#   SECTION: Application
#
################################################################################
Application: &ApplicationDefaults
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        LifecycleEndorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
        Endorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"

    Capabilities:
        <<: *ApplicationCapabilities

################################################################################
#
#   SECTION: Orderer
#
################################################################################
Orderer: &OrdererDefaults
    # Orderer Type: The orderer implementation to start
    OrdererType: etcdraft
    
    # EtcdRaft defines configuration which must be set when the "etcdraft"
    # orderertype is chosen.
    EtcdRaft:
        # The set of Raft replicas for this network. Note that this list of
        # nodes is not necessarily the same as consenting nodes (see ConsentersMap)
        Consenters:
            - Host: orderer.fabriczakat.local
              Port: 7050
              ClientTLSCert: ../organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/tls/server.crt
              ServerTLSCert: ../organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/tls/server.crt
    
    # Batch Timeout: The amount of time to wait before creating a batch
    BatchTimeout: 2s
    
    # Batch Size: Controls the number of messages batched into a block
    BatchSize:
        # Max Message Count: The maximum number of messages to permit in a batch
        MaxMessageCount: 10
        # Absolute Max Bytes: The absolute maximum number of bytes allowed for
        # the serialized messages in a batch.
        AbsoluteMaxBytes: 99 MB
        # Preferred Max Bytes: The preferred maximum number of bytes allowed for
        # the serialized messages in a batch. A message larger than the preferred
        # max bytes will result in a batch larger than preferred max bytes.
        PreferredMaxBytes: 512 KB
    
    # Organizations is the list of orgs which are defined as participants on
    # the orderer side of the network
    Organizations:
    
    # Policies defines the set of policies at this level of the config tree
    # For Orderer policies, their canonical path is
    #   /Channel/Orderer/<PolicyName>
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "ANY Admins"
        # BlockValidation specifies what signatures must be included in the block
        # from the orderer for the peer to validate it.
        BlockValidation:
            Type: ImplicitMeta
            Rule: "ANY Writers"

    # Capabilities describes the orderer level capabilities, see the
    # dedicated Capabilities section elsewhere in this file for a full
    # description
    Capabilities:
        <<: *OrdererCapabilities

################################################################################
#
#   CHANNEL
#
################################################################################
Channel: &ChannelDefaults
    # Policies defines the set of policies at this level of the config tree
    # For Channel policies, their canonical path is
    #   /Channel/<PolicyName>
    Policies:
        # Who may invoke the 'Deliver' API
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        # Who may invoke the 'Broadcast' API
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        # By default, who may modify elements at this config level
        Admins:
            Type: ImplicitMeta
            Rule: "ANY Admins"
    
    # Capabilities describes the channel level capabilities, see the
    # dedicated Capabilities section elsewhere in this file for a full
    # description
    Capabilities:
        <<: *ChannelCapabilities

################################################################################
#
#   Profile
#
################################################################################
Profiles:
    ZakatOrdererGenesis:
        <<: *ChannelDefaults
        Orderer:
            <<: *OrdererDefaults
            Organizations:
                - *OrdererOrg
        Consortiums:
            ZakatConsortium:
                Organizations:
                    - *Org1
                    - *Org2
    
    ZakatChannel:
        Consortium: ZakatConsortium
        <<: *ChannelDefaults
        Application:
            <<: *ApplicationDefaults
            Organizations:
                - *Org1
                - *Org2
            Capabilities:
                <<: *ApplicationCapabilities
EOF
    # Verify creation
    if [ $? -ne 0 ] || [ ! -f "$FABRIC_CFG_PATH/configtx.yaml" ]; then
        echo "  ⛔ Failed to create configtx.yaml file."
        exit 1
    fi
    echo "  ✅ configtx.yaml created successfully."
else
    echo "  ✅ configtx.yaml already exists."
fi

# Check if configtxgen binary exists
echo "🔎 Checking for configtxgen binary..."
if ! command -v configtxgen &> /dev/null; then
    echo "⛔ Error: configtxgen binary not found. Make sure Fabric binaries are installed and in your PATH."
    echo "   You might need to run: export PATH=\$PATH:\$HOME/fabric/bin"
    exit 1
fi
echo "✅ configtxgen binary found."

# Check if necessary MSP directories exist (referenced by configtx.yaml)
echo "🔎 Verifying required MSP directories exist..."
if [ ! -d "$HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/msp" ]; then echo "⛔ Orderer MSP directory not found!"; exit 1; fi
if [ ! -d "$HOME/fabric/organizations/peerOrganizations/org1.fabriczakat.local/msp" ]; then echo "⛔ Org1 MSP directory not found!"; exit 1; fi
if [ ! -d "$HOME/fabric/organizations/peerOrganizations/org2.fabriczakat.local/msp" ]; then echo "⛔ Org2 MSP directory not found!"; exit 1; fi
# Check critical certs within MSPs
if [ -z "$(ls -A $HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/msp/cacerts)" ]; then echo "⛔ Orderer cacerts missing!"; exit 1; fi
if [ -z "$(ls -A $HOME/fabric/organizations/peerOrganizations/org1.fabriczakat.local/msp/cacerts)" ]; then echo "⛔ Org1 cacerts missing!"; exit 1; fi
if [ -z "$(ls -A $HOME/fabric/organizations/peerOrganizations/org2.fabriczakat.local/msp/cacerts)" ]; then echo "⛔ Org2 cacerts missing!"; exit 1; fi
echo "✅ Required MSP directories and certs verified."


echo "📝 Generating genesis block (system-channel)..."
configtxgen -profile ZakatOrdererGenesis -channelID system-channel -outputBlock $OUTPUT_DIR/genesis.block
if [ $? -ne 0 ]; then
    echo "⛔ Failed to generate genesis block."
    exit 1
fi
echo "✅ Genesis block created: $OUTPUT_DIR/genesis.block"

echo "📝 Generating channel creation transaction ($CHANNEL_NAME)..."
configtxgen -profile ZakatChannel -outputCreateChannelTx $OUTPUT_DIR/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
if [ $? -ne 0 ]; then
    echo "⛔ Failed to generate channel transaction for $CHANNEL_NAME."
    exit 1
fi
echo "✅ Channel transaction created: $OUTPUT_DIR/${CHANNEL_NAME}.tx"

echo "📝 Generating anchor peer update transactions..."
configtxgen -profile ZakatChannel -outputAnchorPeersUpdate $OUTPUT_DIR/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
if [ $? -ne 0 ]; then
    echo "⛔ Failed to generate Org1 anchor peer update."
    exit 1
fi
echo "✅ Org1 anchor peer update created: $OUTPUT_DIR/Org1MSPanchors.tx"

configtxgen -profile ZakatChannel -outputAnchorPeersUpdate $OUTPUT_DIR/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
if [ $? -ne 0 ]; then
    echo "⛔ Failed to generate Org2 anchor peer update."
    exit 1
fi
echo "✅ Org2 anchor peer update created: $OUTPUT_DIR/Org2MSPanchors.tx"

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