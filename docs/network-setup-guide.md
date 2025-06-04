# Hyperledger Fabric Network Setup: Detailed Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Network Architecture](#network-architecture)
3. [Infrastructure Setup](#infrastructure-setup)
4. [TLS CA Setup](#tls-ca-setup)
5. [Orderer CA Setup](#orderer-ca-setup)
6. [Organization CA Setup](#organization-ca-setup)
7. [MSP Configuration](#msp-configuration)
8. [Network Bootstrap](#network-bootstrap)
9. [Channel Configuration](#channel-configuration)
10. [Chaincode Deployment](#chaincode-deployment)
11. [Network Verification](#network-verification)

## 1. Introduction

This guide provides a detailed walkthrough of setting up a production-grade Hyperledger Fabric network for the Zakat application. The network uses multiple Certificate Authorities (CAs) for enhanced security and follows Fabric's recommended practices for production deployments.

### Network Purpose
- Process and track Zakat (Islamic charity) transactions
- Maintain transparency in fund distribution
- Ensure compliance with Shariah laws
- Create auditable records of all transactions

### Setup Philosophy
- Security-first approach with separate CAs
- Clear separation of concerns
- Distributed architecture
- Automated deployment scripts

## 2. Network Architecture

### Components Overview
```
Network Structure
├── Certificate Authorities
│   ├── TLS CA (Port 7054)
│   ├── Orderer CA (Port 7055)
│   ├── Org1 CA (Port 7054)
│   └── Org2 CA (Port 7054)
├── Orderer
│   └── orderer.fabriczakat.local
├── Organizations
│   ├── Org1
│   │   └── peer.org1.fabriczakat.local
│   └── Org2
│       └── peer.org2.fabriczakat.local
└── Channel
    └── zakatchannel
```

### Machine Distribution
```
Infrastructure Layout
├── Control Machine (Operations Center)
├── Orderer Machine (10.104.0.3)
│   ├── TLS CA
│   ├── Orderer CA
│   └── Orderer Node
├── Org1 Machine (10.104.0.2)
│   ├── Org1 CA
│   └── Org1 Peer
└── Org2 Machine (10.104.0.4)
    ├── Org2 CA
    └── Org2 Peer
```

## 3. Infrastructure Setup

### Prerequisites Installation
```bash
# On each machine
apt-get update && apt-get upgrade -y
apt-get install -y docker.io docker-compose curl
usermod -aG docker fabricadmin

# Install Fabric binaries
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0
```

### SSH Configuration
```bash
# Generate SSH key on control machine
ssh-keygen -t ed25519 -f ~/.ssh/fabric_key

# Copy key to each machine
ssh-copy-id -i ~/.ssh/fabric_key.pub fabricadmin@10.104.0.3
ssh-copy-id -i ~/.ssh/fabric_key.pub fabricadmin@10.104.0.2
ssh-copy-id -i ~/.ssh/fabric_key.pub fabricadmin@10.104.0.4
```

## 4. TLS CA Setup

### Step 1: Initialize TLS CA
```bash
./00-ca-server-tls-init.sh
```
This script:
- Creates CA directory structure
- Configures TLS CA settings
- Prepares crypto material

What's happening:
1. Creates base directory: `~/fabric/fabric-ca-server-tls`
2. Generates CA configuration file
3. Sets up MSP structure
4. Configures CSR settings for TLS certificates

### Step 2: Start TLS CA
```bash
./01-ca-server-tls-start.sh
```
Process:
1. Verifies ports are available
2. Configures TLS settings
3. Starts CA server in background
4. Verifies server is responding

### Step 3: TLS Admin Enrollment
```bash
./03-ca-client-tls-enroll.sh
```
Actions:
1. Enrolls bootstrap admin identity
2. Generates admin MSP
3. Stores TLS certificates

### Step 4: Register Bootstrap Identities
```bash
./04-ca-client-tls-register-enroll-btstrp-id.sh
```
This registers:
- Orderer CA's TLS certificates
- Org1 CA's TLS certificates
- Org2 CA's TLS certificates

## 5. Orderer CA Setup

### Step 1: Initialize Orderer CA
```bash
./05-ca-server-orderer-init.sh
```
Sets up:
- Orderer CA directory structure
- CA configuration
- Bootstrap identity

### Step 2: Start Orderer CA
```bash
./06-ca-server-orderer-start.sh
```
Process:
1. Configures ports and TLS
2. Starts CA server
3. Verifies operation

### Step 3: Enroll Bootstrap Identity
```bash
./08-ca-server-orderer-enroll.sh
```
Creates:
- Bootstrap MSP
- Signing certificates
- Private keys

### Step 4: Register Admin and Node
```bash
./09-orderer-admin-enroll-register.sh
./10-orderer-node-enroll-register.sh
```
Establishes:
- Admin identity for management
- Node identity for orderer operation
- TLS certificates for secure communication

## 6. Organization CA Setup

### Step 1: Distribute TLS Certificates
```bash
./11-scp-orgs-tls-cert.sh
```
Copies:
- TLS CA certificates to org machines
- Bootstrap credentials

### Step 2: Initialize Organization CAs
```bash
./12-ca-server-orgs-init-start.sh
```
For each organization:
1. Creates CA directory structure
2. Configures CA settings
3. Starts CA server

### Step 3: Enroll Bootstrap Users
```bash
./13-ca-server-orgs-enroll-btstrp.sh
```
Process:
1. Enrolls CA admin
2. Generates admin certificates
3. Sets up MSP structure

### Step 4: Register Organization Entities
```bash
./14-ca-server-orgs-entities.sh
```
Creates identities for:
- Organization admins
- Peer nodes
- TLS certificates

## 7. MSP Configuration

### Step 1: Clean Previous Artifacts
```bash
./15-cleanup-orgs-artifacts.sh
```
Removes:
- Old MSP directories
- Previous certificates
- Stale configurations

### Step 2: Gather and Distribute MSPs
```bash
./16-gather-distribute-msps.sh
```
Process:
1. Collects all MSPs
2. Organizes directory structure
3. Distributes to appropriate machines

### Step 3: Generate Genesis Block
```bash
./17-configtxgen-genesis-channel.sh
```
Creates:
- System channel genesis block
- Channel configuration
- Organization definitions

## 8. Network Bootstrap

### Step 1: Deploy Orderer
```bash
./18-deploy-orderer.sh
```
Process:
1. Creates orderer directory structure
2. Configures orderer settings
3. Starts orderer container
4. Verifies operation

### Step 2: Deploy Peers
```bash
./19-deploy-peers-clis.sh
```
For each organization:
1. Creates peer directory structure
2. Configures peer settings
3. Starts peer container
4. Deploys CLI container

## 9. Channel Configuration

### Step 1: Create and Join Channel
```bash
./20-channel-create-join.sh
```
Process:
1. Creates channel transaction
2. Submits to orderer
3. Each peer joins channel

### Step 2: Update Anchor Peers
```bash
./21-anchor-peer-update.sh
```
For each organization:
1. Creates anchor peer update
2. Submits to channel
3. Updates channel configuration

## 10. Chaincode Deployment

### Step 1: Package Chaincode
```bash
./22-package-chaincode.sh
```
Process:
1. Prepares chaincode files
2. Creates deployment package
3. Calculates package ID

### Step 2: Install Chaincode
```bash
./23-install-chaincode.sh
```
On each peer:
1. Transfers chaincode package
2. Installs package
3. Verifies installation

### Step 3: Approve and Commit
```bash
./24-approve-chaincode.sh
./25-check-commit-readiness.sh
./26-commit-chaincode.sh
```
Process:
1. Organizations approve chaincode
2. Check readiness status
3. Commit to channel
4. Initialize chaincode

## 11. Network Verification

### Step 1: Run Demo Application
```bash
./27-zakat-demo.sh
```
Tests:
1. Channel access
2. Chaincode invocation
3. Transaction processing
4. Query operations

### Step 2: Verify Components
Checklist:
- All CAs running and accessible
- Orderer processing transactions
- Peers endorsing transactions
- Channel communication working
- Chaincode executing properly

### Step 3: Monitor Performance
Tools:
- Docker logs
- Fabric metrics
- System monitoring
- Transaction throughput

## Conclusion

The network setup uses a structured approach with clear separation of responsibilities:
- TLS CA for secure communications
- Orderer CA for ordering service
- Organization CAs for member management
- MSP for identity management
- Channel for business logic isolation
- Chaincode for business rules

This setup provides:
- High security through CA separation
- Clear audit trails
- Scalable architecture
- Maintainable configuration
- Production-ready deployment

Remember to:
- Regularly backup certificates
- Monitor system resources
- Update security configurations
- Maintain access controls
- Document any modifications
