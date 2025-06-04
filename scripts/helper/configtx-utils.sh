#!/bin/bash

# Source organization config
source "$(dirname "$0")/../config/orgs-config.sh"

# Verify MSP directory structure
# Arguments:
#   $1: Base MSP directory
verify_msp_structure() {
    local base_dir=$1

    local missing_dirs=0
    # Check orderer org
    if [ ! -d "$base_dir/ordererOrganizations/fabriczakat.local/msp" ]; then 
        echo "⛔ Orderer MSP directory not found!"
        missing_dirs=1
    fi

    # Check peer orgs
    for ORG in "${ORGS[@]}"; do
        if [ ! -d "$base_dir/peerOrganizations/${ORG}.fabriczakat.local/msp" ]; then
            echo "⛔ ${ORG} MSP directory not found!"
            missing_dirs=1
        fi
    done

    # Check critical certs
    if [ -z "$(ls -A $base_dir/ordererOrganizations/fabriczakat.local/msp/cacerts 2>/dev/null)" ]; then 
        echo "⛔ Orderer cacerts missing!"
        missing_dirs=1
    fi

    for ORG in "${ORGS[@]}"; do
        if [ -z "$(ls -A $base_dir/peerOrganizations/${ORG}.fabriczakat.local/msp/cacerts 2>/dev/null)" ]; then
            echo "⛔ ${ORG} cacerts missing!"
            missing_dirs=1
        fi
    done

    return $missing_dirs
}

# Generate configtx.yaml
# Arguments:
#   $1: Output path
#   $2: Channel name
generate_configtx_yaml() {
    local output_path=$1
    local channel_name=$2

    # Create Profiles section first
    local org_list=""
    for ORG in "${ORGS[@]}"; do
        org_list="$org_list                    - *${ORG^}"$'\n'
    done

    cat > "$output_path" << EOF
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
        Name: OrdererOrg
        ID: OrdererMSP
        MSPDir: ../organizations/ordererOrganizations/fabriczakat.local/msp
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

EOF

    # Add peer organizations
    for ORG in "${ORGS[@]}"; do
        local upper_org="${ORG^}"
        cat >> "$output_path" << EOF
    - &$upper_org
        Name: ${upper_org}MSP
        ID: ${upper_org}MSP
        MSPDir: ../organizations/peerOrganizations/${ORG}.fabriczakat.local/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('${upper_org}MSP.admin', '${upper_org}MSP.peer', '${upper_org}MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('${upper_org}MSP.admin', '${upper_org}MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('${upper_org}MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('${upper_org}MSP.peer')"
        AnchorPeers:
            - Host: peer.${ORG}.fabriczakat.local
              Port: 7051

EOF
    done

    # Add capabilities and other sections
    cat >> "$output_path" << EOF
################################################################################
#
#   SECTION: Capabilities
#
################################################################################
Capabilities:
    Channel: &ChannelCapabilities
        V2_0: true
    Orderer: &OrdererCapabilities
        V2_0: true
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
    OrdererType: etcdraft
    EtcdRaft:
        Consenters:
            - Host: orderer.fabriczakat.local
              Port: 7050
              ClientTLSCert: ../organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/tls/server.crt
              ServerTLSCert: ../organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/tls/server.crt
    BatchTimeout: 2s
    BatchSize:
        MaxMessageCount: 10
        AbsoluteMaxBytes: 99 MB
        PreferredMaxBytes: 512 KB
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
            Rule: "ANY Admins"
        BlockValidation:
            Type: ImplicitMeta
            Rule: "ANY Writers"
    Capabilities:
        <<: *OrdererCapabilities

################################################################################
#
#   CHANNEL
#
################################################################################
Channel: &ChannelDefaults
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
    Capabilities:
        <<: *ChannelCapabilities

################################################################################
#
#   Profile
#
################################################################################
Profiles:
    ${channel_name^}OrdererGenesis:
        <<: *ChannelDefaults
        Orderer:
            <<: *OrdererDefaults
            Organizations:
                - *OrdererOrg
        Consortiums:
            ${channel_name^}Consortium:
                Organizations:
$org_list
    ${channel_name^}Channel:
        Consortium: ${channel_name^}Consortium
        <<: *ChannelDefaults
        Application:
            <<: *ApplicationDefaults
            Organizations:
$org_list
            Capabilities:
                <<: *ApplicationCapabilities
EOF

    return $?
}

# Check configtxgen availability and MSPs before generating artifacts
# Arguments:
#   $1: Base MSP directory
verify_configtx_prerequisites() {
    local base_dir=$1

    # Check configtxgen binary
    if ! command -v configtxgen &> /dev/null; then
        echo "⛔ Error: configtxgen binary not found. Make sure Fabric binaries are installed and in your PATH."
        return 1
    fi

    # Verify MSP structure
    if ! verify_msp_structure "$base_dir"; then
        echo "⛔ Error: Missing required MSP directories or certificates."
        return 1
    fi

    return 0
}

# Generate all required artifacts using configtxgen
# Arguments:
#   $1: Output directory
#   $2: Channel name
#   $3: Profile name prefix
generate_artifacts() {
    local output_dir=$1
    local channel_name=$2
    local profile_prefix=$3

    # Generate genesis block
    configtxgen -profile ${profile_prefix}OrdererGenesis -channelID system-channel -outputBlock "$output_dir/genesis.block" || return 1

    # Generate channel transaction
    configtxgen -profile ${profile_prefix}Channel -outputCreateChannelTx "$output_dir/${channel_name}.tx" -channelID "$channel_name" || return 1

    # Generate anchor peer updates for each org
    for ORG in "${ORGS[@]}"; do
        local upper_org="${ORG^}"
        configtxgen -profile ${profile_prefix}Channel -outputAnchorPeersUpdate "$output_dir/${upper_org}MSPanchors.tx" \
            -channelID "$channel_name" -asOrg ${upper_org}MSP || return 1
    done

    return 0
}
