# Zakat Chaincode Functional Test Suite

## Overview
Comprehensive functional testing framework for the Zakat chaincode v2.0, designed to validate end-to-end business workflows and system integration across multi-host Hyperledger Fabric network.

## Test Architecture

### Test Framework Structure
```
tests/functional/
├── functional-test-suite.sh      # Complete 20-test comprehensive suite
├── integration-workflow-test.sh  # End-to-end business process simulation
├── results/                      # Test execution logs and reports
└── README.md                     # This documentation
```

## Test Suites

### 1. Comprehensive Functional Test Suite
**File**: `functional-test-suite.sh`
**Duration**: ~10-15 minutes
**Tests**: 20 comprehensive test cases

#### Test Categories:
- **Network Connectivity** (1 test): Verify chaincode deployment and network health
- **Initialization** (2 tests): Ledger setup and initial data verification
- **Program Management** (1 test): Create donation programs
- **Officer Management** (1 test): Register officers with referrals
- **Zakat Transactions** (4 tests): Add donations from both organizations
- **Payment Validation** (4 tests): Admin validation workflow testing
- **Distribution** (4 tests): Fund distribution to mustahik recipients
- **Advanced Queries** (4 tests): Status, program, officer, and donor-based filtering
- **Cross-Organization** (1 test): Data consistency verification
- **Error Handling** (1 test): Invalid input validation

#### Test Coverage:
✅ **Tested Functions (17/17)**:
- InitLedger, CreateProgram, RegisterOfficer
- AddZakat, ValidatePayment, DistributeZakat
- QueryZakat, GetAllZakat, GetAllPrograms
- GetZakatByStatus, GetZakatByProgram, GetZakatByOfficer, GetZakatByMuzakki
- GetOfficerByReferral, GetDailyReport, ZakatExists
- Cross-organization consistency validation

### 2. Integration Workflow Test
**File**: `integration-workflow-test.sh`
**Duration**: ~5-8 minutes
**Tests**: Complete end-to-end business process

#### Workflow Steps (16 Steps):
1. **Setup**: Create donation program for emergency relief
2. **Setup**: Register field officer with referral tracking
3. **Donation**: Submit zakat via YDSF Malang (2.5M IDR)
4. **Donation**: Submit zakat via YDSF Jatim (1.75M IDR)
5. **Verification**: Confirm pending status for both donations
6. **Verification**: Verify program association for both donations
7. **Validation**: Admin validates payment (YDSF Malang)
8. **Validation**: Admin validates payment (YDSF Jatim)
9. **Verification**: Confirm collected status and program updates
10. **Verification**: Verify officer referral tracking (4.25M IDR total)
11. **Distribution**: Distribute to mustahik (YDSF Malang)
12. **Distribution**: Distribute to mustahik (YDSF Jatim)
13. **Verification**: Confirm final distributed status
14. **Reporting**: Generate daily activity report
15. **Consistency**: Cross-organization data verification
16. **Summary**: Complete workflow validation

## Test Data Scenarios

### Mock Data Patterns:
- **Organizations**: YDSF Malang, YDSF Jatim
- **Donation Amounts**: 750K - 2.5M IDR (realistic ranges)
- **Zakat Types**: Maal (wealth-based), Fitrah (individual obligation)
- **Payment Methods**: Transfer, E-wallet, Cash, Credit/Debit cards
- **Recipients**: Orphanages, families in need, educational programs
- **Officers**: Field staff with referral codes and commission tracking

### Business Process Validation:
- **Complete 3-Stage Workflow**: Pending → Collected → Distributed
- **Program Association**: Link donations to specific campaigns
- **Officer Referrals**: Track and calculate commissions automatically
- **Admin Validation**: Payment approval with receipt documentation
- **Distribution Tracking**: Record recipient details and distribution amounts
- **Cross-Organization**: Verify data consistency across YDSF branches

## Execution Instructions

### Prerequisites
- Running Hyperledger Fabric zakat network (scripts 00-27 executed)
- SSH access to all three nodes (orderer + 2 peers)
- Zakat chaincode v2.0 deployed and committed
- Network endpoints accessible (10.104.0.2, 10.104.0.3, 10.104.0.4)

### Running Tests

#### Complete Test Suite
```bash
cd tests/functional
./functional-test-suite.sh
```

#### Integration Workflow Only
```bash
cd tests/functional
./integration-workflow-test.sh
```

#### Test Results
- **Logs**: `results/functional-test-results-YYYYMMDD-HHMMSS.log`
- **JSON Report**: `results/test-report-YYYYMMDD-HHMMSS.json`
- **Integration Log**: `results/integration-workflow-YYYYMMDD-HHMMSS.log`

## Expected Results

### Performance Benchmarks:
- **Test Execution Time**: 10-15 minutes for complete suite
- **Success Rate Target**: >95% (19/20 tests passing)
- **Network Response**: <5 seconds per transaction
- **Cross-Org Consistency**: 100% data synchronization

### Validation Criteria:
- ✅ All chaincode functions execute successfully
- ✅ Business workflow progression (pending → collected → distributed)
- ✅ Automatic calculations (program totals, officer referrals)
- ✅ Cross-organization data consistency
- ✅ Error handling for invalid inputs
- ✅ Admin validation controls working properly

## Integration with CI/CD

### Automated Testing
The functional tests can be integrated into continuous integration pipelines:

```bash
# CI/CD Integration Example
#!/bin/bash
set -e

# Deploy network
./scripts/18-deploy-orderer.sh
./scripts/19-deploy-peers-clis.sh
./scripts/20-channel-create-join.sh
./scripts/26-commit-chaincode.sh

# Run functional tests
cd tests/functional
./functional-test-suite.sh

# Verify results
if [ $? -eq 0 ]; then
    echo "✅ All functional tests passed"
    exit 0
else
    echo "❌ Functional tests failed"
    exit 1
fi
```

## Troubleshooting

### Common Issues:

1. **SSH Connection Failures**
   ```bash
   # Verify SSH access to all nodes
   ssh fabricadmin@10.104.0.2 "docker ps"
   ssh fabricadmin@10.104.0.3 "docker ps"
   ssh fabricadmin@10.104.0.4 "docker ps"
   ```

2. **Chaincode Not Found**
   ```bash
   # Verify chaincode deployment
   ssh fabricadmin@10.104.0.2 "docker exec cli.org1.fabriczakat.local peer lifecycle chaincode querycommitted -C zakatchannel -n zakat"
   ```

3. **Network Connectivity Issues**
   ```bash
   # Test peer connectivity
   ssh fabricadmin@10.104.0.2 "docker exec cli.org1.fabriczakat.local peer channel list"
   ```

4. **Transaction Timeouts**
   - Increase `--waitForEvent` timeout in execute_chaincode function
   - Check peer logs for processing delays
   - Verify network latency between hosts

### Debug Mode:
Enable detailed logging by modifying test scripts:
```bash
# Add debug flags
set -x  # Enable command tracing
export FABRIC_LOGGING_SPEC=DEBUG  # Increase Fabric logging
```

## Test Coverage Analysis

### Function Coverage: 100% (17/17 functions)
- **Core Functions**: AddZakat, ValidatePayment, DistributeZakat
- **Query Functions**: All 8 query methods tested
- **Management Functions**: Program and officer management
- **Utility Functions**: Existence checking and reporting

### Workflow Coverage: 100%
- **Complete Business Process**: End-to-end donation lifecycle
- **Multi-Organization**: Cross-organization transaction testing
- **Error Scenarios**: Invalid input and edge case handling
- **Data Integrity**: Automatic calculation verification

### Integration Coverage: 100%
- **Cross-Entity Updates**: Program and officer total calculations
- **Status Transitions**: Enforced workflow progression
- **Admin Controls**: Payment validation and distribution approval
- **Audit Trail**: Complete transaction history verification

## Production Readiness Validation

These functional tests validate production readiness by covering:
- **Real-World Scenarios**: Authentic zakat donation workflows
- **Multi-User Operations**: Concurrent transactions from different organizations
- **Data Consistency**: Cross-organization synchronization
- **Business Logic**: All validation rules and automatic calculations
- **Error Handling**: Graceful failure handling and recovery
- **Performance**: Response times under realistic loads

The test suite ensures the zakat chaincode can handle production workloads with complete business process integrity and cross-organizational transparency.