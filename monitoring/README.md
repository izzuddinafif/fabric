# Hyperledger Fabric Monitoring Stack for Zakat Network

## Overview
This monitoring stack provides comprehensive observability for the Hyperledger Fabric zakat donation network using Prometheus and Grafana. It tracks network health, performance metrics, and business-specific zakat transaction patterns.

## Architecture
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboards  
- **Pushgateway**: Custom metrics ingestion
- **Node Exporter**: System resource monitoring
- **cAdvisor**: Container resource monitoring

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Running Hyperledger Fabric zakat network
- Network endpoints accessible from monitoring host

### Deployment
```bash
cd monitoring
docker-compose -f docker-compose-monitoring.yaml up -d
```

### Access URLs
- **Grafana**: http://localhost:3000 (admin/zakatadmin123)
- **Prometheus**: http://localhost:9090  
- **Pushgateway**: http://localhost:9091
- **Node Exporter**: http://localhost:9100
- **cAdvisor**: http://localhost:8080

## Monitored Components

### Hyperledger Fabric Metrics
- **Orderer**: 10.104.0.3:8443 (Prometheus metrics endpoint)
- **Org1 Peer**: 10.104.0.2:9443 (Prometheus metrics endpoint)  
- **Org2 Peer**: 10.104.0.4:9443 (Prometheus metrics endpoint)
- **CouchDB Org1**: 10.104.0.2:5984 (Database metrics)
- **CouchDB Org2**: 10.104.0.4:5984 (Database metrics)

### System Metrics
- **Node Exporter**: CPU, memory, disk, network metrics
- **cAdvisor**: Container resource utilization
- **Custom Business Metrics**: Zakat transaction patterns

## Dashboards

### 1. Hyperledger Fabric Zakat Network Overview
**Import ID**: 10892 (Modified for zakat network)
- Transaction throughput (TPS)
- Blockchain height across peers
- Proposal duration (latency)
- Zakat chaincode invocation rates

### 2. Zakat Business Metrics Dashboard
- Donations submitted per hour
- Payments validated per hour
- Pending validation queue
- Validation rate percentage
- Transaction type breakdown (AddZakat, ValidatePayment, DistributeZakat)
- Query operation patterns

## Alerting Rules

### Network Health Alerts
- **FabricPeerDown**: Peer node unavailable > 30s
- **FabricOrdererDown**: Orderer node unavailable > 30s
- **CouchDBDown**: Database unavailable > 1 minute

### Performance Alerts  
- **FabricHighLatency**: 95th percentile latency > 5s
- **FabricLowThroughput**: Transaction rate < 1 TPS for 5 minutes
- **FabricBlockCreationSlow**: No new blocks for 10 minutes

### Business Logic Alerts
- **ZakatHighPendingVolume**: >100 pending validations for 30 minutes
- **ZakatValidationRate**: Validation rate < 50% of submission rate

### System Resource Alerts
- **HighCPUUsage**: CPU > 80% for 5 minutes
- **HighMemoryUsage**: Memory > 90% for 5 minutes  
- **LowDiskSpace**: Disk usage > 85%

## Key Metrics

### Fabric Network Metrics
```promql
# Transaction throughput
rate(fabric_ledger_transaction_count[5m])

# Proposal latency
fabric_proposal_duration{quantile="0.95"}

# Blockchain height
fabric_ledger_blockchain_height

# Chaincode invocations
rate(fabric_chaincode_invoke_total{chaincode="zakat"}[5m])
```

### Zakat Business Metrics
```promql
# Hourly donation submissions
sum(increase(fabric_chaincode_invoke_total{chaincode="zakat", method="AddZakat"}[1h]))

# Validation rate
(sum(increase(fabric_chaincode_invoke_total{chaincode="zakat", method="ValidatePayment"}[1h])) / 
 sum(increase(fabric_chaincode_invoke_total{chaincode="zakat", method="AddZakat"}[1h]))) * 100

# Pending validations
sum(increase(fabric_chaincode_invoke_total{chaincode="zakat", method="AddZakat"}[1h])) - 
sum(increase(fabric_chaincode_invoke_total{chaincode="zakat", method="ValidatePayment"}[1h]))
```

## Configuration

### Network Endpoints
Update `prometheus/prometheus.yml` with correct IP addresses:
```yaml
- job_name: 'fabric-orderer'
  static_configs:
    - targets: ['10.104.0.3:8443']

- job_name: 'fabric-peer-org1'  
  static_configs:
    - targets: ['10.104.0.2:9443']
```

### Multi-Host Deployment
For distributed monitoring across multiple hosts:
1. Deploy node-exporter on each Fabric host
2. Update prometheus.yml with remote endpoints
3. Configure network access between monitoring and Fabric hosts

## Data Retention
- **Prometheus**: 200 hours (configurable in docker-compose)
- **Grafana**: Persistent dashboards and data sources
- **Metrics**: 15-second collection interval

## Security Considerations
- Change default Grafana admin password
- Configure Prometheus authentication if exposed
- Restrict network access to monitoring endpoints
- Use TLS certificates for production deployment

## Troubleshooting

### Common Issues
1. **Metrics not appearing**: Check Fabric node endpoints and firewall rules
2. **Grafana connection failed**: Verify Prometheus service is running
3. **High resource usage**: Adjust scrape intervals and retention periods
4. **Missing zakat metrics**: Ensure chaincode name matches configuration

### Debug Commands
```bash
# Check service status
docker-compose -f docker-compose-monitoring.yaml ps

# View logs
docker-compose -f docker-compose-monitoring.yaml logs prometheus
docker-compose -f docker-compose-monitoring.yaml logs grafana

# Test metric endpoints
curl http://10.104.0.3:8443/metrics
curl http://10.104.0.2:9443/metrics
```

## Performance Monitoring
Expected metrics for zakat network performance:
- **Target TPS**: 10-50 transactions per second
- **Latency**: < 2-5 seconds for transaction completion
- **Resource Usage**: Monitor for 80% CPU/memory thresholds
- **Storage Growth**: Track blockchain size and database storage

## Customization
- Add custom business metrics via Pushgateway
- Create additional dashboards for specific zakat program analysis
- Configure custom alerting rules for donation thresholds
- Integrate with external notification systems (email, Slack, etc.)

This monitoring stack provides production-ready observability for the zakat blockchain network, enabling proactive monitoring and performance optimization.