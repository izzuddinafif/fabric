# Hyperledger Fabric Zakat Network: Complete Technical Guide

## Introduction

This guide provides detailed technical instructions for setting up a production-grade Hyperledger Fabric network for Zakat management. We'll cover every command, configuration, and MSP structure in detail.

## Table of Contents

1. [Infrastructure Setup](#1-infrastructure-setup)
2. [Certificate Authority Setup](#2-certificate-authority-setup)
3. [MSP Configuration](#3-msp-configuration)
4. [Network Bootstrap](#4-network-bootstrap)
5. [Channel Configuration](#5-channel-configuration)
6. [Chaincode Deployment](#6-chaincode-deployment)

## 1. Infrastructure Setup

### Machine Requirements
```
Control Node (10.104.0.1):
  Ubuntu 20.04 LTS
  4 CPU cores
  8 GB RAM
  100 GB storage
  Network: 1 Gbps

Orderer Node (10.104.0.3):
  Ubuntu 20.04 LTS
  4 CPU cores
  8 GB RAM
  100 GB storage
  Network: 1 Gbps

Org1 Node (10.104.0.2):otepad
  Ubuntu 20.04 LTS
  4 CPU cores
  8 GB RAM
  100 GB storage
  Network: 1 Gbps

Org2 Node (10.104.0.4):
  Ubuntu 20.04 LTS
  4 CPU cores
  8 GB RAM
  100 GB storage
  Network: 1 Gbps
```

### Prerequisites Installation

On all machines:
```bash
# System updates
sudo apt-get update && sudo apt-get upgrade -y

# Docker installation
sudo apt-get install -y docker.io docker-compose
sudo usermod -aG docker fabricadmin
sudo systemctl enable docker
sudo systemctl start docker

# Fabric binaries installation
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0
cp bin/* $HOME/bin/
rm -rf bin config
```

### Network Configuration

Create /etc/hosts entries:
```bash
# Add to /etc/hosts on all machines
10.104.0.3 orderer.fabriczakat.local ca.orderer.fabriczakat.local tls.fabriczakat.local
10.104.0.2 peer0.org1.fabriczakat.local ca.org1.fabriczakat.local
10.104.0.4 peer0.org2.fabriczakat.local ca.org2.fabriczakat.local
```

## 2. Certificate Authority Setup

### 2.1 TLS CA Configuration

Create TLS CA configuration:
```bash
# Create directory structure
mkdir -p $HOME/fabric/fabric-ca-server-tls
cd $HOME/fabric/fabric-ca-server-tls

# Create CA configuration
cat > fabric-ca-server-config.yaml << EOF
port: 7054
debug: false
csr:
  cn: tls-ca
  names:
    - C: ID
      ST: East Java
      L: Surabaya
      O: YDSF
  hosts:
    - localhost
    - tls.fabriczakat.local
tls:
  enabled: false
ca:
  name: tls-ca
signing:
  profiles:
    tls:
      usage:
        - signing
        - key encipherment
        - server auth
        - client auth
      expiry: 8760h
EOF

# Initialize TLS CA
fabric-ca-server init -b tls-admin:tls-adminpw
```

Start TLS CA:
```bash
# Start CA server in background
fabric-ca-server start -b tls-admin:tls-adminpw
```

### 2.2 Enroll TLS Admin

```bash
# Create directory structure
mkdir -p $HOME/fabric/fabric-ca-client/tls-ca/tlsadmin/msp

# Set environment
export FABRIC_CA_CLIENT_HOME=$HOME/fabric/fabric-ca-client

# Enroll TLS admin
fabric-ca-client enroll -d \
  -u https://tls-admin:tls-adminpw@tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir tls-ca/tlsadmin/msp
```

### 2.3 Register Bootstrap Identities

Register CA TLS identities:
```bash
# Register Orderer CA's TLS identity
fabric-ca-client register -d \
  --id.name rcaadmin-orderer \
  --id.secret ordererpw \
  -u https://tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir tls-ca/tlsadmin/msp

# Register Org1 CA's TLS identity
fabric-ca-client register -d \
  --id.name rcaadmin-org1 \
  --id.secret org1pw \
  -u https://tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir tls-ca/tlsadmin/msp

# Register Org2 CA's TLS identity
fabric-ca-client register -d \
  --id.name rcaadmin-org2 \
  --id.secret org2pw \
  -u https://tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir tls-ca/tlsadmin/msp
```

## 3. MSP Configuration

### 3.1 MSP Directory Structure

```
organizations/
├── ordererOrganizations/
│   └── fabriczakat.local/
│       ├── msp/                          # Orderer org MSP
│       │   ├── cacerts/                  # Orderer CA cert
│       │   ├── tlscacerts/              # TLS CA cert
│       │   └── config.yaml              # MSP config
│       │
│       ├── orderers/
│       │   └── orderer.fabriczakat.local/
│       │       ├── msp/                 # Orderer node MSP
│       │       │   ├── cacerts/
│       │       │   ├── keystore/
│       │       │   ├── signcerts/
│       │       │   └── tlscacerts/
│       │       └── tls/                 # TLS material
│       │           ├── ca.crt
│       │           ├── server.crt
│       │           └── server.key
│       │
│       └── users/
│           └── Admin@fabriczakat.local/
│               └── msp/                 # Admin MSP
│
└── peerOrganizations/
    ├── org1.fabriczakat.local/
    │   ├── msp/                        # Org1 MSP
    │   ├── peers/
    │   │   └── peer0.org1.fabriczakat.local/
    │   │       ├── msp/
    │   │       └── tls/
    │   └── users/
    │       └── Admin@org1.fabriczakat.local/
    │           └── msp/
    │
    └── org2.fabriczakat.local/
        ├── msp/                        # Org2 MSP
        ├── peers/
        │   └── peer0.org2.fabriczakat.local/
        │       ├── msp/
        │       └── tls/
        └── users/
            └── Admin@org2.fabriczakat.local/
                └── msp/
```

### 3.2 Orderer MSP Setup

Create Orderer CA configuration:
```bash
mkdir -p $HOME/fabric/fabric-ca-server-orderer
cd $HOME/fabric/fabric-ca-server-orderer

cat > fabric-ca-server-config.yaml << EOF
port: 7055
debug: false
tls:
  enabled: true
  certfile: tls/cert.pem
  keyfile: tls/key.pem
ca:
  name: orderer-ca
csr:
  cn: orderer-ca
  names:
    - C: ID
      ST: East Java
      L: Surabaya
      O: YDSF
  hosts:
    - localhost
    - ca.orderer.fabriczakat.local
signing:
  default:
    usage:
      - digital signature
    expiry: 8760h
EOF

# Initialize Orderer CA
fabric-ca-server init -b btstrp-orderer:btstrp-ordererpw
```

### 3.3 Organization MSP Setup

For each organization (org1, org2):
```bash
# Create CA directory
mkdir -p $HOME/fabric/fabric-ca-server-org${ORG_NUM}
cd $HOME/fabric/fabric-ca-server-org${ORG_NUM}

# Create CA configuration
cat > fabric-ca-server-config.yaml << EOF
port: 7054
debug: false
tls:
  enabled: true
  certfile: tls/cert.pem
  keyfile: tls/key.pem
ca:
  name: org${ORG_NUM}-ca
csr:
  cn: org${ORG_NUM}-ca
  names:
    - C: ID
      ST: East Java
      L: Surabaya
      O: YDSF
  hosts:
    - localhost
    - ca.org${ORG_NUM}.fabriczakat.local
signing:
  default:
    usage:
      - digital signature
    expiry: 8760h
EOF

# Initialize Organization CA
fabric-ca-server init -b btstrp-org${ORG_NUM}:btstrp-org${ORG_NUM}pw
```

## 4. Network Bootstrap

### 4.1 Genesis Block Creation

```bash
# Create configtx.yaml
configtxgen -profile TwoOrgsOrdererGenesis \
  -channelID system-channel \
  -outputBlock genesis.block

# Create channel transaction
configtxgen -profile TwoOrgsChannel \
  -outputCreateChannelTx zakatchannel.tx \
  -channelID zakatchannel
```

### 4.2 Start Orderer

```bash
# Create orderer.yaml
cat > orderer.yaml << EOF
General:
  ListenAddress: 0.0.0.0
  ListenPort: 7050
  TLS:
    Enabled: true
    PrivateKey: tls/server.key
    Certificate: tls/server.crt
    RootCAs:
      - tls/ca.crt
    ClientAuthRequired: false

FileLedger:
  Location: /var/hyperledger/production/orderer

Kafka:
  Verbose: false
  TLS:
    Enabled: false
    
Debug:
  BroadcastTraceDir: ""
  DeliverTraceDir: ""
EOF

# Start orderer
orderer
```

### 4.3 Start Peers

For each organization:
```bash
# Create core.yaml
cat > core.yaml << EOF
peer:
  id: peer0.org${ORG_NUM}.fabriczakat.local
  networkId: dev
  listenAddress: 0.0.0.0:7051
  chaincodeListenAddress: 0.0.0.0:7052
  address: peer0.org${ORG_NUM}.fabriczakat.local:7051
  tls:
    enabled: true
    cert:
      file: tls/server.crt
    key:
      file: tls/server.key
    rootcert:
      file: tls/ca.crt
EOF

# Start peer
peer node start
```

## 5. Channel Configuration

### 5.1 Create Channel

```bash
# Create channel
peer channel create \
  -o orderer.fabriczakat.local:7050 \
  -c zakatchannel \
  -f zakatchannel.tx \
  --tls \
  --cafile $ORDERER_CA

# Join channel
peer channel join -b zakatchannel.block
```

### 5.2 Update Anchor Peers

For each organization:
```bash
# Create anchor peer update transaction
configtxgen -profile TwoOrgsChannel \
  -outputAnchorPeersUpdate Org${ORG_NUM}MSPanchors.tx \
  -channelID zakatchannel \
  -asOrg Org${ORG_NUM}MSP

# Submit anchor peer update
peer channel update \
  -o orderer.fabriczakat.local:7050 \
  -c zakatchannel \
  -f Org${ORG_NUM}MSPanchors.tx \
  --tls \
  --cafile $ORDERER_CA
```

## 6. Chaincode Deployment

### 6.1 Package Chaincode

```bash
# Create chaincode package
peer lifecycle chaincode package zakat.tar.gz \
  --path chaincode/zakat/ \
  --lang golang \
  --label zakat_1.0
```

### 6.2 Install and Approve

On each peer:
```bash
# Install chaincode
peer lifecycle chaincode install zakat.tar.gz

# Query installed chaincode
peer lifecycle chaincode queryinstalled

# Approve chaincode
peer lifecycle chaincode approveformyorg \
  -o orderer.fabriczakat.local:7050 \
  --channelID zakatchannel \
  --name zakat \
  --version 1.0 \
  --package-id $CC_PACKAGE_ID \
  --sequence 1 \
  --tls \
  --cafile $ORDERER_CA
```

### 6.3 Commit Chaincode

```bash
# Commit chaincode definition
peer lifecycle chaincode commit \
  -o orderer.fabriczakat.local:7050 \
  --channelID zakatchannel \
  --name zakat \
  --version 1.0 \
  --sequence 1 \
  --tls \
  --cafile $ORDERER_CA \
  --peerAddresses peer0.org1.fabriczakat.local:7051 \
  --tlsRootCertFiles $ORG1_TLS_ROOTCERT \
  --peerAddresses peer0.org2.fabriczakat.local:7051 \
  --tlsRootCertFiles $ORG2_TLS_ROOTCERT
```

## Security Considerations

### Private Key Protection
```bash
# Set correct permissions
chmod 600 **/keystore/*
chown -R fabricadmin:fabricadmin organizations/
```

### Certificate Management
```bash
# Backup certificates
tar czf certs-backup.tar.gz \
  organizations/*/*/msp/signcerts \
  organizations/*/*/msp/keystore
```

### Access Control
```bash
# Set directory permissions
find organizations/ -type d -exec chmod 750 {} \;
find organizations/ -type f -exec chmod 640 {} \;
```

## Maintenance

### Certificate Renewal
Monitor expiration dates:
```bash
openssl x509 -in cert.pem -text -noout | grep "Not After"
```

### Log Management
```bash
# Rotate logs
cat > /etc/logrotate.d/hyperledger << EOF
/var/log/fabriclogs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 fabricadmin fabricadmin
}
EOF
```

### Backup Strategy
```bash
# Backup script
#!/bin/bash
BACKUP_DIR="/backup/fabric"
DATE=$(date +%Y%m%d)

# Backup certificates
tar czf $BACKUP_DIR/certs-$DATE.tar.gz organizations/

# Backup ledger data
tar czf $BACKUP_DIR/ledger-$DATE.tar.gz \
  /var/hyperledger/production/

# Backup configurations
tar czf $BACKUP_DIR/config-$DATE.tar.gz config/
```

### Health Monitoring
```bash
# Check component status
docker ps --format "table {{.Names}}\t{{.Status}}"
curl -k https://localhost:7054/metrics
