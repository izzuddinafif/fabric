# Fabric Zakat Network Setup Scripts

This directory contains scripts for setting up a Hyperledger Fabric network for the Zakat application. The scripts are numbered in the order they should be executed.

## Network Architecture

- 1 TLS CA (provides TLS certificates)
- 1 Orderer CA (manages orderer identities)
- 1 Orderer node
- 2 Organizations (Org1, Org2)
- 1 Peer per organization
- 1 Channel (zakatchannel)
- 1 Chaincode (zakat)

## Prerequisites

1. Ubuntu 20.04 VMs (4 machines):
   - Control machine (where scripts are run from)
   - Orderer machine: `10.104.0.3`
   - Org1 machine: `10.104.0.2`
   - Org2 machine: `10.104.0.4`

2. Each machine needs:
   - Docker and Docker Compose
   - Fabric binaries in `$HOME/bin`
   - User `fabricadmin` with sudo access
   - SSH access configured

## Script Categories

### 1. Certificate Authority Setup (00-14)
- **TLS CA** (00-04): Root CA for TLS certificates
- **Orderer CA** (05-10): Manages orderer organization identities
- **Organization CAs** (11-14): Setup and enrollment for Org1 and Org2

### 2. MSP and Channel Setup (15-17)
- MSP organization
- Genesis block creation
- Channel transaction creation

### 3. Network Component Deployment (18-19)
- Orderer deployment
- Peer deployment for each organization

### 4. Channel Operations (20-21)
- Channel creation
- Channel joining
- Anchor peer updates

### 5. Chaincode Operations (22-26)
- Chaincode packaging
- Installation
- Approval
- Commitment

### 6. Application Setup (27)
- Zakat chaincode deployment
- Demo transaction execution

## Execution Flow

### Phase 1: CA Setup and Enrollment
```bash
# TLS CA Setup
./00-ca-server-tls-init.sh      # Initialize TLS CA
./01-ca-server-tls-start.sh     # Start TLS CA
./03-ca-client-tls-enroll.sh    # Enroll TLS CA admin
./04-ca-client-tls-register-enroll-btstrp-id.sh  # Register bootstrap identities

# Orderer CA Setup
./05-ca-server-orderer-init.sh  # Initialize Orderer CA
./06-ca-server-orderer-start.sh # Start Orderer CA
./08-ca-server-orderer-enroll.sh # Enroll CA admin
./09-orderer-admin-enroll-register.sh # Register admin
./10-orderer-node-enroll-register.sh  # Register node

# Organization Setup
./11-scp-orgs-tls-cert.sh       # Distribute TLS certificates
./12-ca-server-orgs-init-start.sh # Initialize org CAs
./13-ca-server-orgs-enroll-btstrp.sh # Enroll bootstrap users
./14-ca-server-orgs-entities.sh # Register and enroll entities
```

### Phase 2: MSP and Genesis Setup
```bash
./15-cleanup-orgs-artifacts.sh   # Clean previous artifacts
./16-gather-distribute-msps.sh   # Collect and organize MSPs
./17-configtxgen-genesis-channel.sh # Generate genesis block
```

### Phase 3: Network Deployment
```bash
./18-deploy-orderer.sh          # Deploy orderer node
./19-deploy-peers-clis.sh       # Deploy peers and CLIs
```

### Phase 4: Channel Setup
```bash
./20-channel-create-join.sh     # Create and join channel
./21-anchor-peer-update.sh      # Update anchor peers
```

### Phase 5: Chaincode Deployment
```bash
./22-package-chaincode.sh       # Package the chaincode
./23-install-chaincode.sh       # Install on peers
./24-approve-chaincode.sh       # Approve chaincode
./25-check-commit-readiness.sh  # Verify readiness
./26-commit-chaincode.sh        # Commit chaincode
```

### Phase 6: Application
```bash
./27-zakat-demo.sh             # Run the demo application
```

## Helper Scripts and Utilities

The `helper/` directory contains utility functions used across multiple scripts:
- `chaincode-utils.sh`: Chaincode operations
- `channel-utils.sh`: Channel management
- `configtx-utils.sh`: Configuration transactions
- `create-config-yaml.sh`: MSP configuration
- `docker-utils.sh`: Docker operations
- `msp-utils.sh`: MSP management
- `peer-utils.sh`: Peer operations
- `ssh-utils.sh`: Remote execution
- `setup-hosts.sh`: Network hostname resolution

## Directory Structure

```
scripts/
├── config/             # Configuration files
├── helper/             # Utility scripts
├── templates/          # Template files
└── README.md          # This file
```

## Network Management

### Starting the Network
```bash
# Start all CA servers
./ca-servers-docker-start.sh

# Deploy components (after CA setup)
./18-deploy-orderer.sh start
./19-deploy-peers-clis.sh start
```

### Stopping the Network
```bash
# Stop components
./18-deploy-orderer.sh stop
./19-deploy-peers-clis.sh stop

# Stop all CA servers
./ca-servers-docker-stop.sh
```

### Changing VPS Machines
If you need to move to new VPS machines:
1. Update IPs in `scripts/config/orgs-config.sh`
2. Run `helper/setup-hosts.sh` to update hostnames
3. Follow the setup process from the beginning

## Troubleshooting

Common issues and solutions:

1. **CA Server Connection Failed**
   - Check if CA server is running
   - Verify ports are not blocked
   - Check TLS certificates

2. **MSP Enrollment Failed**
   - Verify CA server is accessible
   - Check enrollment credentials
   - Ensure proper directory permissions

3. **Chaincode Operations Failed**
   - Check peer logs
   - Verify endorsement policy
   - Check connection parameters

4. **Channel Operations Failed**
   - Verify orderer is running
   - Check channel creation rights
   - Verify MSP configurations

## Maintenance

- Monitor disk space on all machines
- Regularly check CA server logs
- Backup MSP directories and certificates
- Keep track of chaincode versions

## Security Notes

- Protect private keys and certificates
- Use secure passwords for CA admin accounts
- Regularly update access credentials
- Monitor system logs for unauthorized access
- Keep Fabric binaries and Docker images updated

## Support

For issues or questions:
1. Check the script logs in `logs/` directory
2. Review the specific component logs
3. Check Docker container logs
4. Verify network connectivity
5. Check system resources
