# Comprehensive Fabric Zakat Network Setup Guide

## Comprehensive Script Analysis - All 28 Scripts

### Phase I: TLS CA Infrastructure (Scripts 00-04)

#### Script 00: ca-server-tls-init.sh
**Purpose**: Initialize TLS Certificate Authority server
**Key Operations**:
```bash
# Initialize TLS CA server with bootstrap credentials
fabric-ca-server init -b admin:adminpw \
  --csr.hosts "localhost,tls-ca.fabriczakat.local" \
  --home "$HOME/fabric/fabric-ca-server-tls"

# Critical Configuration:
# - Bootstrap admin user creation
# - TLS server certificate generation
# - CA database initialization
```

#### Script 01: ca-server-tls-start.sh
**Purpose**: Start TLS CA server with health monitoring
**Key Operations**:
```bash
# Port availability check and cleanup
check_port() {
    if lsof -i ":$port" > /dev/null; then
        sudo kill $(lsof -t -i:$port) || true
    fi
}

# Server startup with verification
nohup ./fabric-ca-server start >> "$LOG_FILE" 2>&1 &
verify_ca_running $PID

# Health Check via curl:
curl -sk https://localhost:7054/cainfo
```

#### Script 02: ca-server-tls-stop.sh
**Purpose**: Gracefully shutdown TLS CA server
**Key Operations**:
```bash
# Graceful shutdown process
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    kill -TERM $PID
    wait_for_shutdown $PID
fi

# Cleanup operations:
# - Remove PID file
# - Archive log files
# - Free listening ports
```

#### Script 03: ca-client-tls-enroll.sh
**Purpose**: Enroll TLS admin with certificate authority
**Key Operations**:
```bash
# TLS Admin Enrollment Process
fabric-ca-client enroll -u https://admin:adminpw@tls-ca.fabriczakat.local:7054 \
  --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
  --enrollment.profile tls \
  --csr.hosts "tls-ca.fabriczakat.local" \
  --mspdir "tls-ca/tlsadmin/msp"

# Certificate Subject Configuration:
# - C: Country (ID=Indonesia)
# - ST: State (East Java)
# - L: Locality (Surabaya)
# - O: Organization (YDSF)
```

#### Script 04: ca-client-tls-register-enroll-btstrp-id.sh
**Purpose**: Register and enroll bootstrap identities for organizations
**Key Operations**:
```bash
# Bootstrap user registration
declare -A BOOTSTRAP_USERS=(
    ["rcaadmin-org1"]="org1pw"
    ["rcaadmin-org2"]="org2pw"
    ["rcaadmin-orderer"]="ordererpw"
)

# Register each bootstrap user
for username in "${!BOOTSTRAP_USERS[@]}"; do
    fabric-ca-client register -d \
        --id.name "$username" \
        --id.secret "${BOOTSTRAP_USERS[$username]}" \
        -u "https://$CA_HOST:$CA_PORT" \
        --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem"
done

# Enroll with TLS profile and rename private keys
```

### Phase II: Orderer CA Infrastructure (Scripts 05-10)

#### Script 05: ca-server-orderer-init.sh
**Purpose**: Initialize Orderer Certificate Authority
**Key Operations**:
```bash
# Initialize Orderer CA with specific configuration
fabric-ca-server init -b admin:adminpw \
  --csr.hosts "localhost,ca.fabriczakat.local" \
  --home "$HOME/fabric/fabric-ca-server-orderer"

# Database and MSP structure creation
# Certificate chain establishment
```

#### Script 06: ca-server-orderer-start.sh
**Purpose**: Start Orderer CA server
**Key Operations**:
```bash
# Start orderer CA with TLS configuration
nohup ./fabric-ca-server start \
  --port 7054 \
  --tls.enabled true >> "$LOG_FILE" 2>&1 &

# Health verification and port binding checks
```

#### Script 07: ca-server-orderer-stop.sh
**Purpose**: Stop Orderer CA server gracefully
**Key Operations**:
```bash
# Graceful shutdown with cleanup
kill -TERM $PID
wait_for_shutdown $PID 30
cleanup_resources
```

#### Script 08: ca-server-orderer-enroll.sh
**Purpose**: Enroll bootstrap admin with Orderer CA
**Key Operations**:
```bash
# Orderer Node Identity Generation
fabric-ca-client register --id.name $ORDERER_NODE_ID \
  --id.secret $ORDERER_NODE_SECRET \
  --id.type orderer \
  --id.attrs "hf.Registrar.Roles=orderer" \
  --url https://$CA_HOST:$CA_PORT

# Extended Attribute Control:
# hf.Registrar.Roles: Limits registration capabilities
# hf.IntermediateCA: Disabled for node identities
# hf.GenCRL: Revocation list generation permission
```

#### Script 09: orderer-admin-enroll-register.sh
**Purpose**: Register and enroll orderer admin identity
**Key Operations**:
```bash
# Register orderer admin with bootstrap CA
fabric-ca-client register \
  --id.name "Admin@fabriczakat.local" \
  --id.secret "adminpw" \
  --id.type admin \
  --id.attrs "hf.Registrar.Roles=orderer,hf.Revoker=true" \
  --url "https://ca.fabriczakat.local:7054"

# Enroll orderer admin identity
fabric-ca-client enroll \
  -u "https://Admin@fabriczakat.local:adminpw@ca.fabriczakat.local:7054" \
  --mspdir "organizations/ordererOrganizations/fabriczakat.local/users/Admin@fabriczakat.local/msp"
```

#### Script 10: orderer-node-enroll-register.sh
**Purpose**: Register and enroll orderer node identity
**Key Operations**:
```bash
# Register orderer node
fabric-ca-client register \
  --id.name "orderer.fabriczakat.local" \
  --id.secret "ordererpw" \
  --id.type orderer \
  --url "https://ca.fabriczakat.local:7054"

# Enroll orderer node with TLS profile
fabric-ca-client enroll \
  -u "https://orderer.fabriczakat.local:ordererpw@ca.fabriczakat.local:7054" \
  --enrollment.profile tls \
  --csr.hosts "orderer.fabriczakat.local,localhost" \
  --mspdir "organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/tls"

# MSP Directory Security Configuration
chmod 700 $ORDERER_MSP/keystore
chmod 600 $ORDERER_MSP/keystore/*
chmod 755 $ORDERER_MSP/{cacerts,tlscacerts,signcerts}
```

#### Script 11: scp-orgs-tls-cert.sh
**Purpose**: Distribute TLS CA certificate to peer organizations
**Key Operations**:
```bash
# SCP TLS certificate to Org1
scp "$HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" \
  fabricadmin@10.104.0.2:~/fabric/tls-ca-cert.pem

# SCP TLS certificate to Org2
scp "$HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" \
  fabricadmin@10.104.0.4:~/fabric/tls-ca-cert.pem

# Verify certificate integrity on remote hosts
ssh fabricadmin@10.104.0.2 "openssl x509 -in ~/fabric/tls-ca-cert.pem -noout -text"
```

### Phase III: Peer Organization Setup (Scripts 12-16)

#### Script 12: ca-server-orgs-init-start.sh
**Purpose**: Initialize and start CA servers for peer organizations
**Key Operations**:
```bash
# Initialize Org1 CA
ssh fabricadmin@10.104.0.2 \
  "cd ~/fabric && fabric-ca-server init -b admin:adminpw --home fabric-ca-server-org1"

# Initialize Org2 CA
ssh fabricadmin@10.104.0.4 \
  "cd ~/fabric && fabric-ca-server init -b admin:adminpw --home fabric-ca-server-org2"

# Start CA servers on respective hosts
ssh fabricadmin@10.104.0.2 \
  "cd ~/fabric/fabric-ca-server-org1 && nohup ./fabric-ca-server start &"
ssh fabricadmin@10.104.0.4 \
  "cd ~/fabric/fabric-ca-server-org2 && nohup ./fabric-ca-server start &"
```

#### Script 13: ca-server-orgs-enroll-btstrp.sh
**Purpose**: Enroll bootstrap admins for peer organizations
**Key Operations**:
```bash
# Enroll Org1 bootstrap admin using TLS CA certificate
fabric-ca-client enroll \
  -u "https://rcaadmin-org1:org1pw@tls-ca.fabriczakat.local:7054" \
  --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
  --enrollment.profile tls \
  --csr.hosts "ca.org1.fabriczakat.local" \
  --mspdir "tls-ca/rcaadmin-org1/msp"

# Similar process for Org2
fabric-ca-client enroll \
  -u "https://rcaadmin-org2:org2pw@tls-ca.fabriczakat.local:7054" \
  --tls.certfiles "$TLS_CERT_PATH/tls-ca-cert.pem" \
  --enrollment.profile tls \
  --csr.hosts "ca.org2.fabriczakat.local" \
  --mspdir "tls-ca/rcaadmin-org2/msp"
```

#### Script 14: ca-server-orgs-entities.sh
**Purpose**: Create all organizational entities (peers, admins, users)
**Key Operations**:
```bash
# Register and enroll Org1 entities
for ORG in "org1" "org2"; do
  # Register peer admin
  fabric-ca-client register \
    --id.name "Admin@${ORG}.fabriczakat.local" \
    --id.secret "adminpw" \
    --id.type admin \
    --id.attrs "admin=true:ecert" \
    --url "https://ca.${ORG}.fabriczakat.local:7054"
  
  # Register peer node
  fabric-ca-client register \
    --id.name "peer0.${ORG}.fabriczakat.local" \
    --id.secret "peerpw" \
    --id.type peer \
    --url "https://ca.${ORG}.fabriczakat.local:7054"
    
  # Register user
  fabric-ca-client register \
    --id.name "User1@${ORG}.fabriczakat.local" \
    --id.secret "userpw" \
    --id.type client \
    --url "https://ca.${ORG}.fabriczakat.local:7054"
done
```

#### Script 15: cleanup-orgs-artifacts.sh
**Purpose**: Secure cleanup of sensitive cryptographic materials
**Key Operations**:
```bash
# Secure deletion using shred
find organizations/ -name "*_sk" -exec shred -vfz -n 3 {} \;

# Clear sensitive environment variables
unset FABRIC_CA_CLIENT_TLS_CERTFILES
unset FABRIC_CA_CLIENT_HOME

# Remove temporary files
find /tmp -name "fabric-ca-*" -mtime +1 -delete

# Clear bash history entries containing passwords
history -d $(history | grep -n "adminpw\|userpw" | cut -d: -f1)
```

#### Script 16: gather-distribute-msps.sh
**Purpose**: Collect and distribute MSP artifacts across the network
**Key Operations**:
```bash
# Collect Org1 MSP from peer host
scp -r fabricadmin@10.104.0.2:~/fabric/organizations/peerOrganizations/org1.fabriczakat.local/msp/ \
  organizations/peerOrganizations/org1.fabriczakat.local/

# Collect Org2 MSP from peer host
scp -r fabricadmin@10.104.0.4:~/fabric/organizations/peerOrganizations/org2.fabriczakat.local/msp/ \
  organizations/peerOrganizations/org2.fabriczakat.local/

# Distribute complete organizations directory to all hosts
for HOST in "10.104.0.2" "10.104.0.4"; do
  rsync -avz organizations/ fabricadmin@$HOST:~/fabric/organizations/
done
```

### Phase IV: Channel and Genesis Configuration (Scripts 17-21)

#### Script 17: configtxgen-genesis-channel.sh
**Purpose**: Generate genesis block and channel configuration
**Key Operations**:
```bash
# Generate genesis block for system channel
configtxgen -profile OrdererGenesis \
  -outputBlock channel-artifacts/genesis.block \
  -channelID system-channel

# Generate channel configuration transaction
configtxgen -profile OrgsChannel \
  -outputCreateChannelTx channel-artifacts/zakatchannel.tx \
  -channelID zakatchannel

# Generate anchor peer updates
configtxgen -profile OrgsChannel \
  -outputAnchorPeerUpdate channel-artifacts/Org1MSPanchors.tx \
  -channelID zakatchannel -asOrg Org1MSP

configtxgen -profile OrgsChannel \
  -outputAnchorPeerUpdate channel-artifacts/Org2MSPanchors.tx \
  -channelID zakatchannel -asOrg Org2MSP
```

#### Script 18: deploy-orderer.sh
**Purpose**: Deploy orderer node using Docker Compose
**Key Operations**:
```bash
# Create orderer docker-compose configuration
cat > docker-compose-orderer.yaml << EOF
version: '3.7'
services:
  orderer.fabriczakat.local:
    image: hyperledger/fabric-orderer:2.4.3
    environment:
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_BOOTSTRAPMETHOD=file
      - ORDERER_GENERAL_BOOTSTRAPFILE=/var/hyperledger/orderer/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
EOF

# Deploy orderer container
docker-compose -f docker-compose-orderer.yaml up -d

# Verify orderer is running
docker logs orderer.fabriczakat.local
```

#### Script 19: deploy-peers-clis.sh
**Purpose**: Deploy peer nodes and CLI containers on remote hosts
**Key Operations**:
```bash
# Deploy Org1 peer and CLI
ssh fabricadmin@10.104.0.2 << 'EOF'
  cd ~/fabric
  docker-compose -f docker-compose-peer-org1.yaml up -d
  docker ps | grep peer0.org1
EOF

# Deploy Org2 peer and CLI
ssh fabricadmin@10.104.0.4 << 'EOF'
  cd ~/fabric
  docker-compose -f docker-compose-peer-org2.yaml up -d
  docker ps | grep peer0.org2
EOF

# Verify peer connectivity
for HOST in "10.104.0.2" "10.104.0.4"; do
  ssh fabricadmin@$HOST "docker exec cli.org1.fabriczakat.local peer node status"
done
```

#### Script 20: channel-create-join.sh
**Purpose**: Create zakatchannel and join peers
**Key Operations**:
```bash
# Create channel using Org1 CLI
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer channel create \
    -o orderer.fabriczakat.local:7050 \
    -c zakatchannel \
    -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/zakatchannel.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"

# Join Org1 peer to channel
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer channel join \
    -b zakatchannel.block"

# Join Org2 peer to channel
ssh fabricadmin@10.104.0.4 \
  "docker exec cli.org2.fabriczakat.local peer channel join \
    -b zakatchannel.block"
```

#### Script 21: anchor-peer-update.sh
**Purpose**: Update anchor peers for both organizations
**Key Operations**:
```bash
# Update Org1 anchor peer
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer channel update \
    -o orderer.fabriczakat.local:7050 \
    -c zakatchannel \
    -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/Org1MSPanchors.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"

# Update Org2 anchor peer
ssh fabricadmin@10.104.0.4 \
  "docker exec cli.org2.fabriczakat.local peer channel update \
    -o orderer.fabriczakat.local:7050 \
    -c zakatchannel \
    -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/Org2MSPanchors.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"
```

### Phase V: Chaincode Lifecycle (Scripts 22-27)

#### Script 22: package-chaincode.sh
**Purpose**: Package zakat chaincode for deployment
**Key Operations**:
```bash
# Create chaincode package metadata
cat > metadata.json << EOF
{
  "type": "golang",
  "label": "zakat_1.0"
}
EOF

# Create code archive
tar czf code.tar.gz -C chaincode/zakat .

# Package chaincode
tar czf chaincode-packages/zakat_1.0.tar.gz metadata.json code.tar.gz

# Verify package
peer lifecycle chaincode calculatepackageid chaincode-packages/zakat_1.0.tar.gz
```

#### Script 23: install-chaincode.sh
**Purpose**: Install chaincode on all peer nodes
**Key Operations**:
```bash
# Install on Org1 peer
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer lifecycle chaincode install \
    /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode-packages/zakat_1.0.tar.gz"

# Install on Org2 peer
ssh fabricadmin@10.104.0.4 \
  "docker exec cli.org2.fabriczakat.local peer lifecycle chaincode install \
    /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode-packages/zakat_1.0.tar.gz"

# Query installed chaincodes to get package ID
PACKAGE_ID=$(ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer lifecycle chaincode queryinstalled" \
  | grep zakat_1.0 | cut -d' ' -f3 | cut -d',' -f1)

echo "Package ID: $PACKAGE_ID" | tee logs/chaincode_package_ids.txt
```

#### Script 24: approve-chaincode.sh
**Purpose**: Approve chaincode definition for both organizations
**Key Operations**:
```bash
# Read package ID from previous step
PACKAGE_ID=$(cat logs/chaincode_package_ids.txt | grep "Package ID:" | cut -d' ' -f3)

# Approve for Org1
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer lifecycle chaincode approveformyorg \
    -o orderer.fabriczakat.local:7050 \
    --channelID zakatchannel \
    --name zakat \
    --version 1.0 \
    --package-id $PACKAGE_ID \
    --sequence 1 \
    --init-required \
    --signature-policy \"AND('Org1MSP.member','Org2MSP.member')\" \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"

# Approve for Org2
ssh fabricadmin@10.104.0.4 \
  "docker exec cli.org2.fabriczakat.local peer lifecycle chaincode approveformyorg \
    -o orderer.fabriczakat.local:7050 \
    --channelID zakatchannel \
    --name zakat \
    --version 1.0 \
    --package-id $PACKAGE_ID \
    --sequence 1 \
    --init-required \
    --signature-policy \"AND('Org1MSP.member','Org2MSP.member')\" \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"
```

#### Script 25: check-commit-readiness.sh
**Purpose**: Verify chaincode definition approval status
**Key Operations**:
```bash
# Check commit readiness
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer lifecycle chaincode checkcommitreadiness \
    --channelID zakatchannel \
    --name zakat \
    --version 1.0 \
    --sequence 1 \
    --init-required \
    --signature-policy \"AND('Org1MSP.member','Org2MSP.member')\" \
    --output json"

# Expected output should show both Org1MSP and Org2MSP as true
```

#### Script 26: commit-chaincode.sh
**Purpose**: Commit chaincode definition to the channel
**Key Operations**:
```bash
# Commit chaincode definition
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer lifecycle chaincode commit \
    -o orderer.fabriczakat.local:7050 \
    --channelID zakatchannel \
    --name zakat \
    --version 1.0 \
    --sequence 1 \
    --init-required \
    --signature-policy \"AND('Org1MSP.member','Org2MSP.member')\" \
    --peerAddresses peer0.org1.fabriczakat.local:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/peers/peer0.org1.fabriczakat.local/tls/ca.crt \
    --peerAddresses peer0.org2.fabriczakat.local:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/peers/peer0.org2.fabriczakat.local/tls/ca.crt \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"

# Verify commitment
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer lifecycle chaincode querycommitted \
    --channelID zakatchannel --name zakat"
```

#### Script 27: zakat-demo.sh
**Purpose**: Demonstrate zakat chaincode functionality
**Key Operations**:
```bash
# Initialize ledger
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer chaincode invoke \
    -o orderer.fabriczakat.local:7050 \
    --isInit \
    -C zakatchannel \
    -n zakat \
    -c '{\"function\":\"InitLedger\",\"Args\":[]}' \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem \
    --peerAddresses peer0.org1.fabriczakat.local:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/peers/peer0.org1.fabriczakat.local/tls/ca.crt"

# Add new zakat transaction
ZAKAT_ID="ZKT$(date +%s)"
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer chaincode invoke \
    -o orderer.fabriczakat.local:7050 \
    -C zakatchannel \
    -n zakat \
    -c '{\"function\":\"AddZakat\",\"Args\":[\"$ZAKAT_ID\",\"Ahmad Ali\",\"2500000\",\"maal\",\"YDSF Malang\",\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"]}' \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"

# Query all zakat records
ssh fabricadmin@10.104.0.2 \
  "docker exec cli.org1.fabriczakat.local peer chaincode query \
    -C zakatchannel \
    -n zakat \
    -c '{\"function\":\"GetAllZakat\",\"Args\":[]}' | jq ."

# Distribute zakat
ssh fabricadmin@10.104.0.4 \
  "docker exec cli.org2.fabriczakat.local peer chaincode invoke \
    -o orderer.fabriczakat.local:7050 \
    -C zakatchannel \
    -n zakat \
    -c '{\"function\":\"DistributeZakat\",\"Args\":[\"$ZAKAT_ID\",\"Orphanage Foundation\",\"1000000\",\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"]}' \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"
```

## Part I: Network Architecture & Prerequisites

### Network Topology
```mermaid
graph TD
    A[TLS CA] -->|Issues TLS Certs| B(Orderer CA)
    A -->|Issues TLS Certs| C(Org1 CA)
    A -->|Issues TLS Certs| D(Org2 CA)
    B -->|Manages Identity| E[Orderer Node]
    C -->|Manages Identity| F[Org1 Peer]
    D -->|Manages Identity| G[Org2 Peer]
    E -->|Channel| H[Zakatchannel]
    F -->|Joins| H
    G -->|Joins| H
```

### Machine Specification
| Role                     | IP Address    | Hostname                      | Components Installed                    |
|--------------------------|---------------|-------------------------------|-----------------------------------------|
| Orderer + Control Node   | 10.104.0.3    | orderer.fabriczakat.local      | Orderer, Docker, CA Servers, Scripts   |
| Org1 Peer               | 10.104.0.2    | peer.org1.fabriczakat.local    | Peer, CLI, Docker                      |
| Org2 Peer               | 10.104.0.4    | peer.org2.fabriczakat.local    | Peer, CLI, Docker                      |

**Note**: All scripts and management operations are executed from the Orderer VPS (10.104.0.3), which serves as both the orderer node and the network control center.

### Prerequisites Checklist
```bash
# On all machines:
sudo apt-get install -y docker.io docker-compose openssh-server
sudo usermod -aG docker fabricadmin
mkdir -p ~/bin
wget https://github.com/hyperledger/fabric/releases/download/v2.4.3/hyperledger-fabric-linux-amd64-2.4.3.tar.gz
tar -xzf hyperledger-fabric-linux-amd64-2.4.3.tar.gz -C ~/bin
```

## Part II: Detailed Phase Implementation

### Peer Organization Setup (Scripts 12-16)

#### 13-ca-server-orgs-enroll-btstrp.sh
```bash
# Peer Admin Identity Fabrication
fabric-ca-client enroll -u https://$ADMIN_ID:$ADMIN_SECRET@$CA_HOST:$CA_PORT \
  --enrollment.attrs "admin,ecert" \
  --tls.certfiles $TLS_ROOT_CERT

# Attribute Certificate Controls:
# - 'admin' attribute grants MSP Admin privileges
# - ecert: Embeds attributes in enrollment certificate
```

#### 15-cleanup-orgs-artifacts.sh
```bash
# Secure Artifact Sanitization
shred -u $ORG_DIR/msp/keystore/*
find $ORG_DIR -type f -name "*.pem" -exec srm {} \;
dd if=/dev/urandom of=$TEMP_DIR/dummy bs=1M count=10
```

### Channel Operations (Scripts 20-21)

#### 20-channel-create-join.sh
```bash
# Channel Creation Cryptography
peer channel create -o $ORDERER_HOST:7050 \
  -c $CHANNEL_NAME \
  -f $CHANNEL_TX_FILE \
  --tls \
  --cafile $ORDERER_CA_CERT \
  --clientauth \
  --keyfile $CLIENT_KEY \
  --certfile $CLIENT_CERT

# TLS Client Authentication Flags:
# --clientauth: Enforces mutual TLS
# --keyfile: Client private key for TLS
# --certfile: Client certificate for TLS
```

#### 21-anchor-peer-update.sh
```bash
# Anchor Peer Update Sequence
configtxgen -profile OrgsChannel \
  -outputAnchorPeerUpdate $ANCHOR_TX_FILE \
  -asOrg $ORG_NAME \
  -channelID $CHANNEL_NAME

# configtxgen Parameters:
# -profile: Channel configuration profile
# -asOrg: Organization namespace
# -channelID: Target channel
```

### Phase 1: TLS CA Setup (Scripts 00-04)

#### Script 00: ca-server-tls-init.sh
**Purpose**: Initialize TLS Certificate Authority
```bash
# Key Command Breakdown
fabric-ca-server init -b $BOOTSTRAP_USER:$BOOTSTRAP_PASS \
  --csr.hosts $CSR_HOSTNAME \
  --home $CA_DIR

# Parameters:
# -b: Bootstrap user credentials
# --csr.hosts: TLS certificate SANs
# --home: CA server working directory

# Generated Artifacts:
# - fabric-ca-server-config.yaml
# - msp/keystore/ (private keys)
# - tls/ (TLS certificates)
```

### Phase 2: Orderer Setup (Scripts 05-10)

#### Script 09: orderer-admin-enroll-register.sh
**Key Operations**:
1. Register Orderer Admin Identity
```bash
fabric-ca-client register --id.name Admin@$ORDERER_DOMAIN \
  --id.secret adminpw \
  --id.type admin \
  --url https://$CA_HOST:$CA_PORT \
  --mspdir $BOOTSTRAP_MSP
```

2. Generate Admin MSP Structure
```bash
mkdir -p $ADMIN_MSP/{cacerts,keystore,signcerts,tlscacerts}
cp $ORG_MSP/cacerts/* $ADMIN_MSP/cacerts/
cp $TLS_CERT_PATH/tls-ca-cert.pem $ADMIN_MSP/tlscacerts/
```

## Part III: Chaincode Lifecycle Management

### Packaging & Installation (Scripts 22-23)

#### 22-package-chaincode.sh
```bash
# Chaincode Package Structure
tar -czf ${PKG_FILE} \
  -C $CHAINCODE_SRC_PATH \
  metadata.json \
  code.tar.gz

# metadata.json Contents:
# {
#   "type": "golang",
#   "label": "zakat_1.0",
#   "path": "chaincode/zakat"
# }
```

#### 23-install-chaincode.sh
```bash
# Peer Installation Process
peer lifecycle chaincode install $PKG_FILE \
  --peerAddresses $PEER_HOST:7051 \
  --tlsRootCertFiles $PEER_TLS_CERT

# Installation Artifact Storage:
# /var/hyperledger/production/lifecycle/chaincodes
```

### Approval & Commitment (Scripts 24-26)

#### 24-approve-chaincode.sh
```bash
# Chaincode Policy Definition
export CC_POLICY="AND('Org1.member','Org2.member')"

# Policy Validation Rules:
# - Requires endorsements from both orgs
# - Supports complex Boolean logic
```

#### 26-commit-chaincode.sh
```bash
# Distributed Commitment Protocol
peer lifecycle chaincode commit \
  -o $ORDERER_HOST:7050 \
  --channelID $CHANNEL_NAME \
  --name zakat \
  --version 1.0 \
  --sequence 1 \
  --init-required \
  --signature-policy $CC_POLICY \
  --tls \
  --cafile $ORDERER_CA_CERT

# Commitment Verification:
docker exec $PEER_CONTAINER peer lifecycle chaincode querycommitted \
  --channelID $CHANNEL_NAME
```

### MSP Directory Structure
```
organizations/
├── ordererOrganizations/
│   └── fabriczakat.local/
│       ├── msp/
│       │   ├── cacerts/         # Root CA certificate
│       │   ├── tlscacerts/      # TLS CA certificate
│       │   └── config.yaml      # Organizational configuration
│       └── orderers/
│           └── orderer.fabriczakat.local/
│               └── msp/
│                   ├── keystore/ # Node private key
│                   └── signcerts/ # Node certificate
└── peerOrganizations/
    └── org1.fabriczakat.local/
        ├── msp/                 # Org-level MSP
        ├── peers/
        │   └── peer0.org1.fabriczakat.local/
        │       └── msp/         # Peer-specific MSP
        └── users/
            └── Admin@org1.fabriczakat.local/
                └── msp/         # Admin user MSP
```

## Part VIII: Helper Scripts and Utilities Reference

### scripts/helper/ Directory Analysis

#### chaincode-utils.sh
**Purpose**: Chaincode lifecycle management utilities
**Key Functions**:
```bash
# package_chaincode() - Create chaincode packages
package_chaincode() {
    local CC_NAME=$1
    local CC_VERSION=$2
    local CC_PATH=$3
    
    # Create metadata.json
    cat > /tmp/metadata.json << EOF
{
    "type": "golang",
    "label": "${CC_NAME}_${CC_VERSION}"
}
EOF
    
    # Package source code
    tar czf "/tmp/code.tar.gz" -C "$CC_PATH" .
    tar czf "chaincode-packages/${CC_NAME}_${CC_VERSION}.tar.gz" \
        -C /tmp metadata.json code.tar.gz
}

# install_chaincode_on_peer() - Install on specific peer
install_chaincode_on_peer() {
    local PEER_HOST=$1
    local CLI_CONTAINER=$2
    local PACKAGE_FILE=$3
    
    ssh "fabricadmin@$PEER_HOST" \
        "docker exec $CLI_CONTAINER peer lifecycle chaincode install $PACKAGE_FILE"
}

# get_package_id() - Extract package ID from peer
get_package_id() {
    local PEER_HOST=$1
    local CLI_CONTAINER=$2
    local CC_LABEL=$3
    
    ssh "fabricadmin@$PEER_HOST" \
        "docker exec $CLI_CONTAINER peer lifecycle chaincode queryinstalled" \
        | grep "$CC_LABEL" | cut -d' ' -f3 | cut -d',' -f1
}
```

#### channel-utils.sh
**Purpose**: Channel management operations
**Key Functions**:
```bash
# create_channel() - Create new channel
create_channel() {
    local CHANNEL_NAME=$1
    local CHANNEL_TX=$2
    local ORDERER_ENDPOINT=$3
    local ORDERER_CA_CERT=$4
    
    peer channel create \
        -o "$ORDERER_ENDPOINT" \
        -c "$CHANNEL_NAME" \
        -f "$CHANNEL_TX" \
        --tls --cafile "$ORDERER_CA_CERT"
}

# join_peer_to_channel() - Join peer to existing channel
join_peer_to_channel() {
    local PEER_HOST=$1
    local CLI_CONTAINER=$2
    local CHANNEL_BLOCK=$3
    
    ssh "fabricadmin@$PEER_HOST" \
        "docker exec $CLI_CONTAINER peer channel join -b $CHANNEL_BLOCK"
}

# update_anchor_peer() - Update anchor peer configuration
update_anchor_peer() {
    local CHANNEL_NAME=$1
    local ANCHOR_TX=$2
    local ORDERER_ENDPOINT=$3
    local ORDERER_CA_CERT=$4
    
    peer channel update \
        -o "$ORDERER_ENDPOINT" \
        -c "$CHANNEL_NAME" \
        -f "$ANCHOR_TX" \
        --tls --cafile "$ORDERER_CA_CERT"
}
```

#### msp-utils.sh
**Purpose**: MSP structure management
**Key Functions**:
```bash
# create_msp_structure() - Create complete MSP hierarchy
create_msp_structure() {
    local BASE_PATH=$1
    local ORG_NAME=$2
    local ORG_DOMAIN=$3
    
    local MSP_PATH="$BASE_PATH/organizations/peerOrganizations/$ORG_DOMAIN"
    
    # Create organizational MSP structure
    mkdir -p "$MSP_PATH/msp/{cacerts,tlscacerts,config}"
    mkdir -p "$MSP_PATH/peers/peer0.$ORG_DOMAIN/msp/{cacerts,keystore,signcerts,tlscacerts}"
    mkdir -p "$MSP_PATH/peers/peer0.$ORG_DOMAIN/tls"
    mkdir -p "$MSP_PATH/users/Admin@$ORG_DOMAIN/msp/{cacerts,keystore,signcerts,tlscacerts}"
    mkdir -p "$MSP_PATH/users/User1@$ORG_DOMAIN/msp/{cacerts,keystore,signcerts,tlscacerts}"
    
    # Set proper permissions
    find "$MSP_PATH" -type d -name "keystore" -exec chmod 700 {} \;
    find "$MSP_PATH" -type f -name "*_sk" -exec chmod 600 {} \;
}

# copy_org_msp() - Securely copy MSP between hosts
copy_org_msp() {
    local REMOTE_HOST=$1
    local REMOTE_PATH=$2
    local LOCAL_PATH=$3
    
    # Create checksums before transfer
    ssh "fabricadmin@$REMOTE_HOST" \
        "find $REMOTE_PATH -type f -exec sha256sum {} \;" > /tmp/remote_checksums.txt
    
    # Transfer files
    rsync -avz --progress "fabricadmin@$REMOTE_HOST:$REMOTE_PATH/" "$LOCAL_PATH/"
    
    # Verify checksums after transfer
    find "$LOCAL_PATH" -type f -exec sha256sum {} \; > /tmp/local_checksums.txt
    
    if ! diff /tmp/remote_checksums.txt /tmp/local_checksums.txt > /dev/null; then
        echo "❌ Checksum verification failed!"
        return 1
    fi
    
    echo "✅ MSP transfer completed and verified"
}

# setup_msp_config_yaml() - Create MSP config.yaml
setup_msp_config_yaml() {
    local MSP_PATH=$1
    local ORG_NAME=$2
    
    cat > "$MSP_PATH/config.yaml" << EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: orderer
EOF
}
```

#### docker-utils.sh
**Purpose**: Docker container management
**Key Functions**:
```bash
# check_container_status() - Verify container health
check_container_status() {
    local HOST=$1
    local CONTAINER_NAME=$2
    
    ssh "fabricadmin@$HOST" \
        "docker ps --filter name=$CONTAINER_NAME --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
}

# deploy_container_from_template() - Deploy using template
deploy_container_from_template() {
    local HOST=$1
    local TEMPLATE_FILE=$2
    local OUTPUT_FILE=$3
    local ENV_VARS=$4
    
    # Process template with environment variables
    envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
    
    # Copy to remote host and deploy
    scp "$OUTPUT_FILE" "fabricadmin@$HOST:~/fabric/"
    ssh "fabricadmin@$HOST" \
        "cd ~/fabric && docker-compose -f $(basename $OUTPUT_FILE) up -d"
}

# collect_container_logs() - Gather logs from all containers
collect_container_logs() {
    local HOST=$1
    local OUTPUT_DIR=$2
    
    mkdir -p "$OUTPUT_DIR/$HOST"
    
    # Get list of running containers
    CONTAINERS=$(ssh "fabricadmin@$HOST" "docker ps --format '{{.Names}}'")
    
    for CONTAINER in $CONTAINERS; do
        echo "📋 Collecting logs for $CONTAINER on $HOST"
        ssh "fabricadmin@$HOST" \
            "docker logs $CONTAINER" > "$OUTPUT_DIR/$HOST/${CONTAINER}.log" 2>&1
    done
}
```

#### peer-utils.sh
**Purpose**: Peer node operations
**Key Functions**:
```bash
# setup_peer_environment() - Configure peer environment variables
setup_peer_environment() {
    local ORG_NAME=$1
    local ORG_DOMAIN=$2
    local PEER_ADDRESS=$3
    
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="${ORG_NAME}MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="organizations/peerOrganizations/$ORG_DOMAIN/users/Admin@$ORG_DOMAIN/msp"
    export CORE_PEER_ADDRESS="$PEER_ADDRESS"
}

# query_peer_channels() - List channels joined by peer
query_peer_channels() {
    local PEER_HOST=$1
    local CLI_CONTAINER=$2
    
    ssh "fabricadmin@$PEER_HOST" \
        "docker exec $CLI_CONTAINER peer channel list"
}

# get_peer_height() - Get blockchain height from peer
get_peer_height() {
    local PEER_HOST=$1
    local CLI_CONTAINER=$2
    local CHANNEL_NAME=$3
    
    ssh "fabricadmin@$PEER_HOST" \
        "docker exec $CLI_CONTAINER peer channel getinfo -c $CHANNEL_NAME" \
        | grep -o '"height":[0-9]*' | cut -d':' -f2
}
```

#### demo-utils.sh
**Purpose**: Demo and testing utilities
**Key Functions**:
```bash
# print_zakat_header() - Display demo header
print_zakat_header() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                     ZAKAT CHAINCODE DEMO                     ║
║              Hyperledger Fabric Network Testing              ║
╚═══════════════════════════════════════════════════════════════╝
EOF
}

# generate_zakat_id() - Create unique zakat transaction ID
generate_zakat_id() {
    local PREFIX=$1
    echo "${PREFIX}-$(date +%Y%m%d)-$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')"
}

# generate_donor_name() - Generate random donor name
generate_donor_name() {
    local FIRST_NAMES=("Ahmad" "Fatimah" "Muhammad" "Aisha" "Abdullah" "Khadijah")
    local LAST_NAMES=("Rahman" "Hassan" "Ali" "Ibrahim" "Yusuf" "Zainab")
    
    local FIRST=${FIRST_NAMES[$RANDOM % ${#FIRST_NAMES[@]}]}
    local LAST=${LAST_NAMES[$RANDOM % ${#LAST_NAMES[@]}]}
    echo "$FIRST $LAST"
}

# format_json() - Pretty print JSON output
format_json() {
    local JSON_STRING=$1
    if command -v jq > /dev/null; then
        echo "$JSON_STRING" | jq .
    else
        echo "$JSON_STRING" | python -m json.tool 2>/dev/null || echo "$JSON_STRING"
    fi
}

# chaincode_invoke() - Invoke chaincode with error handling
chaincode_invoke() {
    local PEER_HOST=$1
    local CLI_CONTAINER=$2
    local CHANNEL_NAME=$3
    local CC_NAME=$4
    local FUNCTION=$5
    local ARGS=$6
    local ORDERER_ENDPOINT=$7
    local ORDERER_CA_CERT=$8
    local LOG_FILE=$9
    
    echo "🔄 Invoking $FUNCTION on $CC_NAME..." | tee -a "$LOG_FILE"
    
    ssh "fabricadmin@$PEER_HOST" \
        "docker exec $CLI_CONTAINER peer chaincode invoke \
            -o $ORDERER_ENDPOINT \
            -C $CHANNEL_NAME \
            -n $CC_NAME \
            -c '{\"function\":\"$FUNCTION\",\"Args\":$ARGS}' \
            --tls --cafile $ORDERER_CA_CERT" 2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✅ $FUNCTION completed successfully" | tee -a "$LOG_FILE"
        return 0
    else
        echo "❌ $FUNCTION failed" | tee -a "$LOG_FILE"
        return 1
    fi
}

# chaincode_query() - Query chaincode
chaincode_query() {
    local PEER_HOST=$1
    local CLI_CONTAINER=$2
    local CHANNEL_NAME=$3
    local CC_NAME=$4
    local FUNCTION=$5
    local ARGS=$6
    local LOG_FILE=$7
    
    ssh "fabricadmin@$PEER_HOST" \
        "docker exec $CLI_CONTAINER peer chaincode query \
            -C $CHANNEL_NAME \
            -n $CC_NAME \
            -c '{\"function\":\"$FUNCTION\",\"Args\":$ARGS}'"
}
```

### scripts/config/ Directory Analysis

#### orgs-config.sh
**Purpose**: Central configuration for all organizations
**Key Configuration**:
```bash
#!/bin/bash
# Global Network Configuration

# Domain and Network Settings
export ORDERER_DOMAIN="fabriczakat.local"
export ORG1_DOMAIN="org1.fabriczakat.local"
export ORG2_DOMAIN="org2.fabriczakat.local"

# IP Address Mapping
export ORDERER_IP="10.104.0.3"
export ORG1_IP="10.104.0.2"
export ORG2_IP="10.104.0.4"

# Certificate Authority Configuration
export TLS_CA_PORT="7054"
export ORDERER_CA_PORT="7055"
export ORG1_CA_PORT="7056"
export ORG2_CA_PORT="7057"

# MSP Identifiers
export ORDERER_MSP_ID="OrdererMSP"
export ORG1_MSP_ID="Org1MSP"
export ORG2_MSP_ID="Org2MSP"

# Channel Configuration
export SYSTEM_CHANNEL_NAME="system-channel"
export APPLICATION_CHANNEL_NAME="zakatchannel"

# Chaincode Configuration
export CHAINCODE_NAME="zakat"
export CHAINCODE_VERSION="1.0"
export CHAINCODE_SEQUENCE="1"
export CHAINCODE_POLICY="AND('Org1MSP.member','Org2MSP.member')"

# Docker Container Names
export ORDERER_CONTAINER="orderer.fabriczakat.local"
export ORG1_PEER_CONTAINER="peer0.org1.fabriczakat.local"
export ORG2_PEER_CONTAINER="peer0.org2.fabriczakat.local"
export ORG1_CLI_CONTAINER="cli.org1.fabriczakat.local"
export ORG2_CLI_CONTAINER="cli.org2.fabriczakat.local"

# Paths and Directories
export FABRIC_HOME="$HOME/fabric"
export ORGANIZATIONS_DIR="$FABRIC_HOME/organizations"
export CHANNEL_ARTIFACTS_DIR="$FABRIC_HOME/channel-artifacts"
export CHAINCODE_PACKAGES_DIR="$FABRIC_HOME/chaincode-packages"
export LOGS_DIR="$FABRIC_HOME/logs"

# Security Configuration
export FABRIC_CA_SERVER_TLS_ENABLED="true"
export CORE_PEER_TLS_ENABLED="true"
export ORDERER_GENERAL_TLS_ENABLED="true"

# Logging Configuration
export FABRIC_LOGGING_SPEC="INFO"
export CORE_CHAINCODE_LOGGING_LEVEL="INFO"
export ORDERER_GENERAL_LOGLEVEL="INFO"

# Function to validate configuration
validate_config() {
    echo "🔍 Validating network configuration..."
    
    # Check required directories
    for DIR in "$FABRIC_HOME" "$ORGANIZATIONS_DIR" "$CHANNEL_ARTIFACTS_DIR"; do
        if [ ! -d "$DIR" ]; then
            echo "❌ Directory not found: $DIR"
            return 1
        fi
    done
    
    # Check network connectivity
    for IP in "$ORG1_IP" "$ORG2_IP"; do
        if ! ping -c 1 "$IP" > /dev/null 2>&1; then
            echo "⚠️  Warning: Cannot reach $IP"
        fi
    done
    
    echo "✅ Configuration validation completed"
}

# Function to display current configuration
show_config() {
    cat << EOF
╔═══════════════════════════════════════════════════════════════╗
║                    FABRIC ZAKAT NETWORK CONFIG               ║
╠═══════════════════════════════════════════════════════════════╣
║ Orderer:     $ORDERER_IP ($ORDERER_DOMAIN)              ║
║ Org1 Peer:   $ORG1_IP ($ORG1_DOMAIN)         ║
║ Org2 Peer:   $ORG2_IP ($ORG2_DOMAIN)         ║
║                                                               ║
║ Channel:     $APPLICATION_CHANNEL_NAME                                   ║
║ Chaincode:   $CHAINCODE_NAME v$CHAINCODE_VERSION                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
}
```

### scripts/templates/ Directory Analysis

#### Docker Compose Templates
**Purpose**: Reusable container deployment templates

**docker-compose-peer-template.yaml**:
```yaml
version: '3.7'

services:
  peer0.${ORG_DOMAIN}:
    container_name: peer0.${ORG_DOMAIN}
    image: hyperledger/fabric-peer:2.4.3
    environment:
      - CORE_PEER_ID=peer0.${ORG_DOMAIN}
      - CORE_PEER_ADDRESS=peer0.${ORG_DOMAIN}:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.${ORG_DOMAIN}:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.${OTHER_ORG_DOMAIN}:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.${ORG_DOMAIN}:7051
      - CORE_PEER_LOCALMSPID=${ORG_MSP_ID}
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_default
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp
    volumes:
      - /var/run/:/host/var/run/
      - ./organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/msp:/etc/hyperledger/fabric/msp
      - ./organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls:/etc/hyperledger/fabric/tls
      - peer0.${ORG_DOMAIN}:/var/hyperledger/production
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    ports:
      - 7051:7051
    networks:
      - fabric

  cli.${ORG_DOMAIN}:
    container_name: cli.${ORG_DOMAIN}
    image: hyperledger/fabric-tools:2.4.3
    tty: true
    stdin_open: true
    environment:
      - GOPATH=/opt/gopath
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_ID=cli.${ORG_DOMAIN}
      - CORE_PEER_ADDRESS=peer0.${ORG_DOMAIN}:7051
      - CORE_PEER_LOCALMSPID=${ORG_MSP_ID}
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/ca.crt
      - CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: /bin/bash
    volumes:
      - /var/run/:/host/var/run/
      - .:/opt/gopath/src/github.com/hyperledger/fabric/peer
    depends_on:
      - peer0.${ORG_DOMAIN}
    networks:
      - fabric

volumes:
  peer0.${ORG_DOMAIN}:

networks:
  fabric:
    external:
      name: fabric_default
```

## Part IV: Advanced Configuration Details

### configtx.yaml Deep Dive
```yaml
Organizations:
  - Name: Org1
    ID: Org1MSP
    MSPDir: organizations/peerOrganizations/org1.fabriczakat.local/msp
    Policies:
      Readers:
        Type: Signature
        Rule: OR('Org1MSP.admin', 'Org1MSP.peer', 'Org1MSP.client')
      Writers:
        Type: Signature
        Rule: OR('Org1MSP.admin', 'Org1MSP.client')
      Admins:
        Type: Signature
        Rule: OR('Org1MSP.admin')

# Policy Configuration Analysis:
# - Readers: MSP roles with read access
# - Writers: Entities allowed to submit transactions
# - Admins: Identity management privileges
```

### Docker Compose Network Configuration
```yaml
peer.org1.fabriczakat.local:
  environment:
    - CORE_PEER_ID=peer0.org1.fabriczakat.local
    - CORE_PEER_ADDRESS=peer0.org1.fabriczakat.local:7051
    - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
    - CORE_PEER_CHAINCODEADDRESS=peer0.org1.fabriczakat.local:7052
    - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
    - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.fabriczakat.local:7051
    - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org2.fabriczakat.local:7051

# Networking Breakdown:
# - 7051: Peer gRPC endpoint
# - 7052: Chaincode listener
# - 7053: Peer HTTP endpoint
# - 5984: CouchDB port
```

### Daily Monitoring Checklist
```bash
# Check CA Server Health
docker logs -f ca_server 2>&1 | grep -iE 'error|warning'

# Verify Peer Connectivity
peer channel getinfo -c zakatchannel

# Monitor Chaincode Containers
docker ps -f "name=dev-peer"

# Check Certificate Expiry
openssl x509 -in organizations/peerOrganizations/org1.fabriczakat.local/msp/cacerts/*.pem -noout -dates
```

### Backup Procedure
```bash
# Create MSP Snapshot
tar -czf msp_backup_$(date +%Y%m%d).tar.gz organizations/

# Backup Chaincode Packages
rsync -avz chaincode-packages/ backup-server:/fabric-backups/

# Export Critical Identities
pkcs12 -export -out admin_identity.p12 \
  -inkey organizations/peerOrganizations/org1.fabriczakat.local/users/Admin@org1.fabriczakat.local/msp/keystore/key.pem \
  -in organizations/peerOrganizations/org1.fabriczakat.local/users/Admin@org1.fabriczakat.local/msp/signcerts/cert.pem
```

## Part V: Security Considerations

### Cryptographic Material Lifecycle
```mermaid
stateDiagram-v2
    [*] --> Initialization
    Initialization --> Generation: Generate root CA
    Generation --> Distribution: Deploy certs
    Distribution --> Operation: Normal usage
    Operation --> Renewal: 60 days before expiry
    Renewal --> Distribution: Roll new certs
    Operation --> Revocation: Compromise detected
    Revocation --> Generation: Reissue certs
    Revocation --> [*]: CRL published
    Renewal --> [*]: Graceful retirement
```

#### Lifecycle Management Commands
```bash
# Certificate Renewal
openssl ca -config openssl.cnf -extensions v3_ca \
  -days 365 -notext -md sha384 \
  -keyfile ca/private/cakey.pem \
  -cert ca/certs/cacert.pem \
  -gencrl -out ca/crl/ca.crl.pem

# CRL Verification
openssl crl -in ca.crl.pem -noout -text \
  -CAfile ca-chain.pem
```

### Certificate Management Best Practices
1. TLS Certificate Rotation Procedure
```bash
# Regenerate TLS certificates
./scripts/00-ca-server-tls-init.sh --renew

# Distribute updated certs
./scripts/11-scp-orgs-tls-cert.sh --force-update

# Restart components with new certs
docker-compose -f docker/docker-compose-peer.yaml down
docker-compose -f docker/docker-compose-peer.yaml up -d
```

### Audit Trail Configuration
```bash
# Enable Fabric Operations Logging
export FABRIC_LOGGING_SPEC=DEBUG:cauthdsl,policies,msp,grpc,peer.gossip

# Configure ELK Stack Integration
filebeat modules enable system
filebeat setup --pipelines --modules system
service filebeat start
```

## Part VI: Disaster Recovery Procedures

### Certificate Authority Recovery
1. Restore CA Server:
```bash
# 1. Restore from encrypted backup
gpg --decrypt ca-backup.tar.gz.gpg | tar xz -C /etc/fabric-ca-server

# 2. Regenerate intermediate certificates
fabric-ca-server init --registry.identities.name tempAdmin \
  --registry.identities.pass tempAdminPass \
  --registry.identities.type admin

# 3. Rotate all node identities
./scripts/14-ca-server-orgs-entities.sh --force-renewal
```

### Peer Node Restoration
```bash
# 1. Reconstruct MSP from backup
rsync -avzP backup/peer0.org1/msp/ organizations/peerOrganizations/org1.fabriczakat.local/peers/peer0.org1/msp/

# 2. Rejoin channel with genesis block
peer channel join -b zakatchannel_genesis.block \
  --tls --cafile $ORDERER_CA_CERT

# 3. Reinstall chaincodes
./scripts/23-install-chaincode.sh --force-reinstall
```

### Channel Reconstruction Protocol
```bash
# 1. Fetch config block
peer channel fetch config config_block.pb -o orderer:7050 \
  -c zakatchannel --tls --cafile $ORDERER_CA_CERT

# 2. Convert to editable JSON
configtxlator proto_decode --input config_block.pb --type common.Block \
  | jq .data.data[0].payload.data.config > config.json

# 3. Update consortium settings
jq '.channel_group.groups.Consortiums.groups.ZakatConsortium.values += {"new_param": "value"}' config.json > modified_config.json

# 4. Create config update
configtxlator compute_update --original config.json --updated modified_config.json \
  --channel_id zakatchannel --output config_update.pb

# 5. Sign and submit update
peer channel update -f config_update.pb -c zakatchannel \
  -o orderer:7050 --tls --cafile $ORDERER_CA_CERT
```

## Part VII: Troubleshooting Guide

### Common Errors and Solutions

**Error: MSP Verification Failed**
```log
2025-06-01 09:23:18.543 UTC [msp] validateIdentityAgainstChain -> ERRO 001 
Failed deserializing identity: certificates have expired
```
**Solution**:
```bash
# 1. Check certificate expiration
openssl x509 -in msp/signcerts/cert.pem -noout -dates

# 2. Re-enroll identity
fabric-ca-client reenroll -u https://Admin@org1.fabriczakat.local:adminpw@ca.org1.fabriczakat.local:7054

# 3. Restart affected components
docker restart peer0.org1.fabriczakat.local
```

## Part IX: Execution Flow and Script Dependencies

### Complete Network Setup Sequence
```mermaid
flowchart TD
    A["00: TLS CA Init"] --> B["01: TLS CA Start"]
    B --> C["03: TLS Admin Enroll"]
    C --> D["04: Bootstrap IDs"]
    D --> E["05: Orderer CA Init"]
    E --> F["06: Orderer CA Start"]
    F --> G["08: Orderer CA Enroll"]
    G --> H["09: Orderer Admin"]
    H --> I["10: Orderer Node"]
    I --> J["11: Distribute TLS Cert"]
    J --> K["12: Peer CAs Init"]
    K --> L["13: Peer CA Bootstrap"]
    L --> M["14: Peer Entities"]
    M --> N["16: Gather MSPs"]
    N --> O["17: Genesis Block"]
    O --> P["18: Deploy Orderer"]
    P --> Q["19: Deploy Peers"]
    Q --> R["20: Create Channel"]
    R --> S["21: Anchor Peers"]
    S --> T["22: Package CC"]
    T --> U["23: Install CC"]
    U --> V["24: Approve CC"]
    V --> W["25: Check Readiness"]
    W --> X["26: Commit CC"]
    X --> Y["27: Demo"]
```

### Script Dependencies Matrix
| Script | Dependencies | Outputs | Next Steps |
|--------|-------------|---------|------------|
| 00 | None | TLS CA server config | 01 |
| 01 | 00 | Running TLS CA | 03 |
| 03 | 01 | TLS admin MSP | 04 |
| 04 | 03 | Bootstrap identities | 05, 11 |
| 05 | 04 | Orderer CA config | 06 |
| 06 | 05 | Running Orderer CA | 08 |
| 08 | 06 | Orderer CA admin | 09 |
| 09 | 08 | Orderer admin MSP | 10 |
| 10 | 09 | Orderer node MSP | 11 |
| 11 | 04, 10 | TLS cert distribution | 12 |
| 12 | 11 | Peer CA servers | 13 |
| 13 | 12 | Peer CA bootstrap | 14 |
| 14 | 13 | All peer entities | 16 |
| 16 | 14 | Complete MSP structure | 17 |
| 17 | 16 | Genesis block, channel TX | 18 |
| 18 | 17 | Running orderer | 19 |
| 19 | 18 | Running peers | 20 |
| 20 | 19 | zakatchannel created | 21 |
| 21 | 20 | Anchor peers set | 22 |
| 22 | 21 | Chaincode package | 23 |
| 23 | 22 | Installed chaincode | 24 |
| 24 | 23 | Approved chaincode | 25 |
| 25 | 24 | Readiness verification | 26 |
| 26 | 25 | Committed chaincode | 27 |
| 27 | 26 | Demo transactions | - |

### Critical Checkpoints

#### Checkpoint 1: TLS Infrastructure (After Script 04)
```bash
# Verify TLS CA is operational
curl -sk https://localhost:7054/cainfo | jq .

# Check bootstrap identities
ls -la fabric-ca-client/tls-ca/

# Validate TLS certificate
openssl x509 -in fabric-ca-client/tls-root-cert/tls-ca-cert.pem -noout -text
```

#### Checkpoint 2: Orderer Setup (After Script 10)
```bash
# Verify Orderer CA
curl -sk https://localhost:7055/cainfo | jq .

# Check orderer MSP structure
find organizations/ordererOrganizations/ -name "*.pem" | head -10

# Validate orderer identity
openssl x509 -in organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/signcerts/cert.pem -noout -subject
```

#### Checkpoint 3: Peer Infrastructure (After Script 16)
```bash
# Verify peer MSP completeness
for ORG in org1 org2; do
    echo "=== Checking $ORG MSP ==="
    find organizations/peerOrganizations/$ORG.fabriczakat.local/ -name "*.pem" | wc -l
done

# Test SSH connectivity to peers
for IP in 10.104.0.2 10.104.0.4; do
    ssh -o ConnectTimeout=5 fabricadmin@$IP "echo 'Connection to $IP: OK'"
done
```

#### Checkpoint 4: Network Operational (After Script 21)
```bash
# Verify orderer is running
docker ps | grep orderer.fabriczakat.local

# Check peer containers on remote hosts
ssh fabricadmin@10.104.0.2 "docker ps | grep peer0.org1"
ssh fabricadmin@10.104.0.4 "docker ps | grep peer0.org2"

# Test channel functionality
ssh fabricadmin@10.104.0.2 "docker exec cli.org1.fabriczakat.local peer channel list"
```

### Error Recovery Procedures

#### Script Failure Recovery
```bash
# Generic script failure recovery
recover_from_failure() {
    local FAILED_SCRIPT=$1
    local SCRIPT_NUMBER=$(echo $FAILED_SCRIPT | grep -o '^[0-9]\+')
    
    echo "🔄 Recovering from failure in script $FAILED_SCRIPT"
    
    # Stop related services
    case $SCRIPT_NUMBER in
        "00"|"01"|"02"|"03"|"04")
            ./scripts/02-ca-server-tls-stop.sh
            ;;
        "05"|"06"|"07"|"08"|"09"|"10")
            ./scripts/07-ca-server-orderer-stop.sh
            ;;
        "18")
            docker-compose -f docker/docker-compose-orderer.yaml down
            ;;
        "19")
            ssh fabricadmin@10.104.0.2 "cd ~/fabric && docker-compose down"
            ssh fabricadmin@10.104.0.4 "cd ~/fabric && docker-compose down"
            ;;
    esac
    
    # Clean up artifacts if needed
    if [ $SCRIPT_NUMBER -lt 18 ]; then
        echo "⚠️  Consider running: ./scripts/15-cleanup-orgs-artifacts.sh"
    fi
    
    echo "✅ Recovery preparation complete. Review logs and re-run from script $SCRIPT_NUMBER"
}
```

#### Network Reset Procedure
```bash
# Complete network teardown and reset
network_reset() {
    echo "🚨 DESTRUCTIVE OPERATION: Resetting entire network"
    read -p "Are you sure? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" = "yes" ]; then
        # Stop all services
        ./scripts/02-ca-server-tls-stop.sh
        ./scripts/07-ca-server-orderer-stop.sh
        docker-compose -f docker/docker-compose-orderer.yaml down
        
        # Clean up on peer hosts
        for HOST in 10.104.0.2 10.104.0.4; do
            ssh fabricadmin@$HOST "cd ~/fabric && docker-compose down -v"
            ssh fabricadmin@$HOST "docker system prune -f"
        done
        
        # Remove cryptographic materials
        rm -rf organizations/
        rm -rf fabric-ca-client/
        rm -rf fabric-ca-server-*/
        rm -rf channel-artifacts/*
        rm -rf chaincode-packages/*
        
        echo "💥 Network reset complete. Ready for fresh deployment."
    else
        echo "❌ Operation cancelled."
    fi
}
```

### Performance Monitoring Scripts

#### Network Health Check
```bash
#!/bin/bash
# network-health-check.sh

check_network_health() {
    echo "🏥 Fabric Zakat Network Health Check"
    echo "===================================="
    
    # Check CA servers
    echo "📋 Certificate Authorities:"
    curl -sk https://localhost:7054/cainfo > /dev/null && echo "  ✅ TLS CA" || echo "  ❌ TLS CA"
    curl -sk https://localhost:7055/cainfo > /dev/null && echo "  ✅ Orderer CA" || echo "  ❌ Orderer CA"
    
    # Check containers
    echo "📋 Docker Containers:"
    docker ps --filter "name=orderer.fabriczakat.local" --format "table {{.Names}}\t{{.Status}}" | grep -q "Up" && echo "  ✅ Orderer" || echo "  ❌ Orderer"
    
    for HOST in 10.104.0.2 10.104.0.4; do
        ORG=$([ "$HOST" = "10.104.0.2" ] && echo "Org1" || echo "Org2")
        ssh fabricadmin@$HOST "docker ps --filter 'name=peer0' --format '{{.Status}}'" | grep -q "Up" && echo "  ✅ $ORG Peer" || echo "  ❌ $ORG Peer"
    done
    
    # Check channel status
    echo "📋 Channel Status:"
    CHANNEL_INFO=$(ssh fabricadmin@10.104.0.2 "docker exec cli.org1.fabriczakat.local peer channel getinfo -c zakatchannel" 2>/dev/null)
    if echo "$CHANNEL_INFO" | grep -q "height"; then
        HEIGHT=$(echo "$CHANNEL_INFO" | grep -o '"height":[0-9]*' | cut -d':' -f2)
        echo "  ✅ zakatchannel (Height: $HEIGHT)"
    else
        echo "  ❌ zakatchannel"
    fi
    
    # Check chaincode
    echo "📋 Chaincode Status:"
    CC_STATUS=$(ssh fabricadmin@10.104.0.2 "docker exec cli.org1.fabriczakat.local peer lifecycle chaincode querycommitted -C zakatchannel" 2>/dev/null)
    if echo "$CC_STATUS" | grep -q "zakat"; then
        echo "  ✅ zakat chaincode committed"
    else
        echo "  ❌ zakat chaincode not found"
    fi
    
    echo "===================================="
}

# Run health check
check_network_health
```

### Automated Deployment Script

#### Master Deployment Script
```bash
#!/bin/bash
# deploy-zakat-network.sh - Master deployment script

set -e

echo "🚀 Starting Fabric Zakat Network Deployment"
echo "==========================================="

# Source configuration
source scripts/config/orgs-config.sh

# Validate prerequisites
validate_config

# Phase 1: TLS Infrastructure
echo "📋 Phase 1: TLS Certificate Authority Setup"
for SCRIPT in 00 01 03 04; do
    echo "  🔄 Running script $SCRIPT..."
    ./scripts/${SCRIPT}-*.sh
    [ $? -eq 0 ] && echo "  ✅ Script $SCRIPT completed" || { echo "  ❌ Script $SCRIPT failed"; exit 1; }
done

# Phase 2: Orderer Infrastructure
echo "📋 Phase 2: Orderer Infrastructure Setup"
for SCRIPT in 05 06 08 09 10 11; do
    echo "  🔄 Running script $SCRIPT..."
    ./scripts/${SCRIPT}-*.sh
    [ $? -eq 0 ] && echo "  ✅ Script $SCRIPT completed" || { echo "  ❌ Script $SCRIPT failed"; exit 1; }
done

# Phase 3: Peer Infrastructure
echo "📋 Phase 3: Peer Organization Setup"
for SCRIPT in 12 13 14 16; do
    echo "  🔄 Running script $SCRIPT..."
    ./scripts/${SCRIPT}-*.sh
    [ $? -eq 0 ] && echo "  ✅ Script $SCRIPT completed" || { echo "  ❌ Script $SCRIPT failed"; exit 1; }
done

# Phase 4: Network Deployment
echo "📋 Phase 4: Network Deployment"
for SCRIPT in 17 18 19 20 21; do
    echo "  🔄 Running script $SCRIPT..."
    ./scripts/${SCRIPT}-*.sh
    [ $? -eq 0 ] && echo "  ✅ Script $SCRIPT completed" || { echo "  ❌ Script $SCRIPT failed"; exit 1; }
done

# Phase 5: Chaincode Deployment
echo "📋 Phase 5: Chaincode Lifecycle"
for SCRIPT in 22 23 24 25 26; do
    echo "  🔄 Running script $SCRIPT..."
    ./scripts/${SCRIPT}-*.sh
    [ $? -eq 0 ] && echo "  ✅ Script $SCRIPT completed" || { echo "  ❌ Script $SCRIPT failed"; exit 1; }
done

echo "🎉 Fabric Zakat Network Deployment Complete!"
echo "============================================"
echo "Ready to run: ./scripts/27-zakat-demo.sh"
```

## Conclusion

This comprehensive guide documents all 28 core scripts, 10 helper utilities, configuration files, and templates that comprise the complete Fabric Zakat network infrastructure. 

### Key Achievements:

✅ **Complete Script Coverage**: All 28 scripts (00-27) documented with detailed command breakdowns  
✅ **Helper Utilities**: 10 utility scripts with function-level documentation  
✅ **Configuration Management**: Central configuration system with validation  
✅ **Template System**: Reusable Docker Compose templates  
✅ **Error Recovery**: Comprehensive troubleshooting and recovery procedures  
✅ **Security Implementation**: Certificate lifecycle and cryptographic best practices  
✅ **Operational Procedures**: Monitoring, backup, and disaster recovery  
✅ **Execution Flow**: Script dependencies and deployment automation  

### Documentation Structure:
1. **Phase-by-Phase Script Analysis** (Scripts 00-27)
2. **Network Architecture & Prerequisites**
3. **Chaincode Lifecycle Management**
4. **Helper Scripts & Utilities Reference**
5. **Advanced Configuration Details**
6. **Security Considerations**
7. **Disaster Recovery Procedures**
8. **Troubleshooting Guide**
9. **Execution Flow & Dependencies**

### Network Components Covered:
- 🔐 **TLS Certificate Authority** (Scripts 00-04)
- 🏛️ **Orderer Infrastructure** (Scripts 05-11)
- 🏢 **Peer Organizations** (Scripts 12-16)
- 📡 **Channel Operations** (Scripts 17-21)
- ⚙️ **Chaincode Lifecycle** (Scripts 22-27)
- 🛠️ **Helper Utilities** (10 utility scripts)
- 📋 **Configuration Management** (Central config system)
- 🔧 **Templates & Automation** (Docker Compose templates)

This documentation serves as the **definitive reference** for:
- Setting up and operating the Fabric Zakat network
- Understanding cryptographic operations and security considerations
- Troubleshooting network issues and recovery procedures
- Extending the network with additional organizations or components
- Maintaining and monitoring the blockchain infrastructure

**Total Coverage**: 28 core scripts + 10 helpers + configurations + templates + operational procedures = **Complete Fabric Zakat Network Documentation**
