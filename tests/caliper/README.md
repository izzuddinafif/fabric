# Zakat Chaincode Performance Testing with Hyperledger Caliper

## Overview
This directory contains Hyperledger Caliper performance testing configurations for the Zakat chaincode. The tests simulate realistic donation scenarios with mock data to evaluate system performance and capacity.

## Performance Targets
- **Target TPS**: 10-50 transactions per second
- **Network**: Multi-host setup (Orderer + 2 Orgs)
- **Test Data**: Mock zakat donations and operations

## Test Structure

### Test Rounds
1. **AddZakat - Gradual Load**: 5→25 TPS increasing load for donation submissions
2. **ValidatePayment - Admin Operations**: 10 TPS steady load for payment validations  
3. **QueryOperations - Read Performance**: 50 TPS for various query operations
4. **MixedWorkload - Realistic Scenario**: Mixed operations with varying load patterns

### Workload Modules
- `addZakat.js`: Tests donation submission performance
- `validatePayment.js`: Tests admin payment validation workflow
- `queryOperations.js`: Tests read operations (GetAllZakat, GetZakatByStatus, etc.)
- `mixedOperations.js`: Realistic mixed workload (40% adds, 20% validations, 40% queries)

## Setup and Installation

### Prerequisites
- Node.js 14+ and npm 6+
- Running Hyperledger Fabric zakat network
- Network must be accessible from test machine

### Installation
```bash
cd tests/caliper
npm run install
npm run bind
```

### Configuration
1. **Network Configuration**: Update `network-config.yaml` with correct paths and endpoints
2. **Connection Profiles**: Verify `connection-profiles/` contain correct network details
3. **Test Parameters**: Modify `caliper-config.yaml` for custom test scenarios

## Running Tests

### Full Test Suite
```bash
npm test
```

### Individual Test Rounds
```bash
# Test specific round
npx caliper launch manager --caliper-workspace ./ \
  --caliper-networkconfig network-config.yaml \
  --caliper-benchconfig caliper-config.yaml \
  --caliper-flow-only-test \
  --caliper-fabric-gateway-enabled
```

### Custom Test Configuration
Modify `caliper-config.yaml` to adjust:
- Transaction numbers per round
- Rate control (TPS patterns)
- Test duration and worker counts
- Workload arguments

## Mock Data Scenarios

### Test Data Includes:
- **Organizations**: YDSF Malang, YDSF Jatim
- **Donation Amounts**: 100K - 2.5M IDR
- **Zakat Types**: Maal, Fitrah
- **Payment Methods**: Transfer, E-wallet, Cash
- **Programs**: Educational support, healthcare, family assistance
- **Officers**: Referral tracking with commission calculations

### Sample Transaction Flow:
1. Submit donation (AddZakat) → Pending status
2. Admin validates payment (ValidatePayment) → Collected status  
3. Query operations for reporting and analytics
4. Mixed operations simulating real usage patterns

## Expected Results

### Performance Baselines:
- **AddZakat**: Target 20-30 TPS sustained
- **ValidatePayment**: Target 10-15 TPS (admin operations)
- **Query Operations**: Target 40-50 TPS (read-heavy)
- **Mixed Workload**: Target 25-35 TPS overall

### Monitoring:
- Resource utilization (CPU, Memory, Network)
- Prometheus metrics collection
- Transaction latency and throughput
- Error rates and success ratios

## Troubleshooting

### Common Issues:
1. **Network Connectivity**: Verify peer and orderer endpoints in connection profiles
2. **Certificate Paths**: Ensure MSP certificates are correctly referenced
3. **Chaincode Deployment**: Confirm zakat chaincode is installed and committed
4. **Resource Limits**: Monitor system resources during high-load tests

### Debug Mode:
```bash
export CALIPER_LOGGING_LEVELS='{"debug": "info"}'
npm test
```

## Results Analysis
- Test reports generated in `caliper-workspace/` directory
- HTML reports with detailed metrics and graphs
- Resource monitoring data for capacity planning
- Performance baselines for production deployment planning

## Production Considerations
- Current tests use mock data - production deployment requires real transaction data
- Network capacity planning based on test results
- Monitoring and alerting setup using Prometheus metrics
- Scalability assessment for multi-organization deployment