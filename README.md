# Zakat Network - Hyperledger Fabric

A Hyperledger Fabric network for managing zakat collection and distribution.

## System Requirements

### For All Machines
- Operating System: Ubuntu 20.04 LTS or higher
- Docker Engine: 20.10.x or higher
- Docker Compose: v2.0.0 or higher
- User: `fabricadmin` with sudo privileges
- SSH access configured between machines

### Software Versions
- Hyperledger Fabric: 2.5.0
- Fabric CA: 1.5.7
- Go: 1.20.x
- Node.js: 18.x (for applications)

## Network Architecture

### Certificate Authorities
Each component runs in its own Docker container on its respective host:

- TLS CA (on Orderer machine)
  - Port: 7054
  - Container: ca_tls.fabriczakat.local

- Orderer CA (on Orderer machine)
  - Port: 7054
  - Container: ca_orderer.fabriczakat.local

- Org1 CA (on Org1 machine)
  - Port: 7054
  - Container: ca_org1.fabriczakat.local

- Org2 CA (on Org2 machine)
  - Port: 7054
  - Container: ca_org2.fabriczakat.local

### Organization Setup
- Orderer Organization
  - Host: orderer.fabriczakat.local (10.104.0.3)
  - Services: 
    - Orderer Node
    - TLS CA (7054)
    - Orderer CA (7054)

- Org1 (YDSF Malang)
  - Host: org1.fabriczakat.local (10.104.0.2)
  - Services:
    - Peer Node
    - Organization CA (7054)

- Org2 (YDSF Surabaya)
  - Host: org2.fabriczakat.local (10.104.0.4)
  - Services:
    - Peer Node
    - Organization CA (7054)

## Setup Instructions

1. Install Prerequisites
```bash
# On each machine
./scripts/install-prerequisites.sh
```

2. Configure Network
```bash
# On control machine
./scripts/config/setup-network-config.sh
```

3. Start CA Services
```bash
# On control machine - this deploys all CAs to their respective hosts
./scripts/ca-servers-docker-start.sh
```

4. Generate Certificates
```bash
# Register and enroll participants
./scripts/03-ca-client-tls-enroll.sh
./scripts/04-ca-client-tls-register-enroll-btstrp-id.sh
# ... continue with other enrollment scripts
```

5. Deploy Network Components
```bash
# Deploy orderer
./scripts/18-deploy-orderer.sh

# Deploy peers
./scripts/19-deploy-peers-clis.sh

# Create and configure channel
./scripts/20-channel-create-join.sh
./scripts/21-anchor-peer-update.sh
```

6. Deploy Chaincode
```bash
./scripts/22-package-chaincode.sh
# ... continue with chaincode deployment scripts
```

## Directory Structure
```
.
├── chaincode/          # Chaincode source
├── config/            # Network configuration files
├── docker/            # Docker Compose files
├── fabric/            # Generated artifacts
├── scripts/           # Setup and management scripts
└── README.md         # This file
```

## Important Notes

### Docker Containers
- Each CA runs in its own container on its respective host machine
- All CAs use port 7054 (possible because they're on different machines)
- Each container has its own configuration and TLS setup
- Container names follow the pattern: ca_<type>.fabriczakat.local

### Security
- TLS is enabled for all communications
- Each CA uses separate credentials
- MSP certificates are properly distributed
- CAs on different machines for better security

### Troubleshooting
- Check Docker logs: `docker logs <container-name>`
- Check CA logs: `docker logs ca_<type>.fabriczakat.local`
- Use scripts/ca-servers-docker-stop.sh to stop all CAs
- Verify network connectivity between machines
- Check firewall rules allow port 7054

## License
This project is licensed under the Apache-2.0 License.
