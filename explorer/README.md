# Hyperledger Explorer for Zakat Network

## Overview
Hyperledger Explorer provides a web-based blockchain browser for the zakat donation network. It offers real-time visualization of blocks, transactions, chaincode invocations, and network topology with full transparency for zakat operations.

## Features
- **Blockchain Visualization**: Real-time block and transaction browsing
- **Transaction Details**: Complete zakat transaction history with full metadata
- **Chaincode Operations**: Track zakat chaincode invocations and performance
- **Network Topology**: Visual representation of orderer and peer nodes
- **Search Functionality**: Find transactions, blocks, and chaincode by various criteria
- **Channel Information**: zakatchannel monitoring and statistics

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Running Hyperledger Fabric zakat network
- Network access to orderer and peer nodes

### Deployment
```bash
cd explorer
docker-compose -f docker-compose-explorer.yaml up -d
```

### Access
- **Web Interface**: http://localhost:8090
- **Default Network**: zakat-network (auto-configured)

## Configuration

### Network Configuration
The explorer is pre-configured for the zakat network:
- **Channel**: zakatchannel
- **Organizations**: Org1MSP (YDSF Malang), Org2MSP (YDSF Jatim)
- **Peers**: 
  - peer.org1.fabriczakat.local (10.104.0.2:7051)
  - peer.org2.fabriczakat.local (10.104.0.4:7051)
- **Orderer**: orderer.fabriczakat.local (10.104.0.3:7050)

### Connection Profile
Located at `connection-profile/zakat-network.json`, this file defines:
- Network topology and endpoints
- Organization MSP configurations
- Channel membership
- TLS and authentication settings

## Multi-Host Setup
For the distributed 3-node deployment:
1. Explorer connects to remote peers via IP addresses
2. Admin certificates mounted from host organizations directory
3. Network endpoints configured for cross-host communication

## Database
- **PostgreSQL**: Stores blockchain data and metadata
- **Automatic Setup**: Database initialized on first run
- **Persistent Storage**: Data retained across container restarts

## Monitoring Capabilities

### Transaction Tracking
- **Zakat Donations**: Track AddZakat transactions with full donor details
- **Payment Validations**: Monitor ValidatePayment admin operations
- **Distributions**: View DistributeZakat operations to mustahik recipients
- **Query Operations**: Observe read operations and reporting queries

### Block Analysis
- **Block Details**: View block headers, transaction counts, and timestamps
- **Transaction Flow**: Trace individual transactions through the workflow
- **Chaincode Performance**: Monitor zakat chaincode execution times

### Network Health
- **Peer Status**: Real-time peer connectivity and synchronization
- **Channel Activity**: zakatchannel transaction throughput and patterns
- **Network Topology**: Visual representation of network participants

## Zakat-Specific Features

### Business Process Visualization
- **Donation Workflow**: Pending → Collected → Distributed status tracking
- **Program Association**: Link transactions to donation programs
- **Officer Referrals**: Track referral codes and commission calculations
- **Organization Breakdown**: YDSF Malang vs YDSF Jatim transaction distribution

### Transparency Features
- **Public Accountability**: All zakat transactions visible to stakeholders
- **Audit Trail**: Complete immutable record of all operations
- **Program Tracking**: Monitor donation program progress and distributions
- **Receipt Verification**: Link transactions to receipt numbers

## Search and Filtering

### Search Capabilities
- **Transaction ID**: Find specific zakat transactions (ZKT-YDSF-MLG-*)
- **Block Number**: Navigate to specific blocks
- **Organization**: Filter by YDSF Malang or YDSF Jatim
- **Chaincode**: Focus on zakat chaincode operations
- **Time Range**: Filter transactions by date/time periods

### Advanced Filters
- **Transaction Type**: AddZakat, ValidatePayment, DistributeZakat
- **Status**: Pending, Collected, Distributed
- **Amount Range**: Filter by donation amounts
- **Program Association**: View program-specific transactions

## Performance Metrics
Explorer provides insights into:
- **Transaction Volume**: Daily/hourly zakat transaction counts
- **Processing Time**: Average time from submission to validation
- **Network Utilization**: Block creation frequency and transaction density
- **Chaincode Performance**: Execution times for zakat operations

## Security Considerations
- **Read-Only Access**: Explorer provides view-only blockchain access
- **No Authentication**: Currently configured for development/testing
- **Network Isolation**: Runs in dedicated Docker network
- **Certificate Management**: Uses admin certificates for blockchain access

## Troubleshooting

### Common Issues
1. **Connection Failed**: Verify peer and orderer endpoints are accessible
2. **No Data Displayed**: Check if zakat network is running and accessible
3. **Database Errors**: Ensure PostgreSQL container is healthy
4. **Certificate Issues**: Verify admin certificate paths in connection profile

### Debug Commands
```bash
# Check service status
docker-compose -f docker-compose-explorer.yaml ps

# View logs
docker-compose -f docker-compose-explorer.yaml logs explorer
docker-compose -f docker-compose-explorer.yaml logs explorerdb

# Restart services
docker-compose -f docker-compose-explorer.yaml restart explorer

# Check database connectivity
docker exec explorerdb.fabriczakat.local pg_isready
```

### Network Connectivity
```bash
# Test peer connectivity from explorer container
docker exec explorer.fabriczakat.local nc -zv 10.104.0.2 7051
docker exec explorer.fabriczakat.local nc -zv 10.104.0.4 7051
docker exec explorer.fabriczakat.local nc -zv 10.104.0.3 7050
```

## Integration with Monitoring
Explorer complements the Prometheus/Grafana monitoring stack:
- **Explorer**: Transaction-level detail and blockchain browsing
- **Prometheus**: Performance metrics and alerting
- **Grafana**: Business intelligence and trend analysis

## Production Considerations
For production deployment:
1. Enable authentication and access controls
2. Configure TLS certificates for secure communication
3. Set up backup procedures for PostgreSQL database
4. Implement network security policies
5. Configure reverse proxy for external access

## Data Insights
Explorer enables analysis of:
- **Donation Patterns**: Peak submission times and amounts
- **Processing Efficiency**: Time from donation to validation
- **Geographic Distribution**: Org1 vs Org2 transaction volumes
- **Program Performance**: Most successful donation campaigns
- **Officer Effectiveness**: Referral performance tracking

This blockchain explorer provides complete transparency and accountability for the zakat donation system, enabling stakeholders to verify all transactions and monitor system performance in real-time.