#!/bin/bash
# Comprehensive Functional Test Suite for Zakat Chaincode
# Based on script 27 pattern with enhanced coverage for all zakat workflows

set -e

# --- Configuration ---
CHANNEL_NAME="zakatchannel"
CC_NAME="zakat"
CC_VERSION="2.0"

# Org Details
ORG1_NAME="Org1"
ORG1_DOMAIN="org1.fabriczakat.local"
ORG1_IP="10.104.0.2"
ORG1_MSP="Org1MSP"
ORG1_CLI_CONTAINER="cli.${ORG1_DOMAIN}"

ORG2_NAME="Org2"
ORG2_DOMAIN="org2.fabriczakat.local"
ORG2_IP="10.104.0.4"
ORG2_MSP="Org2MSP"
ORG2_CLI_CONTAINER="cli.${ORG2_DOMAIN}"

# Orderer Details
ORDERER_IP="10.104.0.3"
ORDERER_CONTAINER="orderer.fabriczakat.local"

# Test Results
LOG_DIR="$HOME/fabric/tests/functional/results"
LOG_FILE="$LOG_DIR/functional-test-results-$(date +%Y%m%d-%H%M%S).log"
REPORT_FILE="$LOG_DIR/test-report-$(date +%Y%m%d-%H%M%S).json"
mkdir -p $LOG_DIR
> $LOG_FILE

# Test Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TEST_RESULTS=()

# --- Formatting & Helpers ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

print_header() {
    local title=$1
    local width=80
    local line=$(printf '%*s' "$width" | tr ' ' '=')
    echo -e "\n${BOLD}${line}${NC}" | tee -a $LOG_FILE
    echo -e "${BOLD}${BLUE}   $title${NC}" | tee -a $LOG_FILE
    echo -e "${BOLD}${line}${NC}\n" | tee -a $LOG_FILE
}

# Test execution function
run_test() {
    local test_name="$1"
    local test_function="$2"
    local expected_result="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log "Running Test $TOTAL_TESTS: $test_name"
    
    start_time=$(date +%s)
    
    if eval $test_function; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo -e "${GREEN}✅ PASS${NC}: $test_name (${duration}s)" | tee -a $LOG_FILE
        TEST_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"PASS\",\"duration\":$duration}")
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo -e "${RED}❌ FAIL${NC}: $test_name (${duration}s)" | tee -a $LOG_FILE
        TEST_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"FAIL\",\"duration\":$duration}")
    fi
}

# Execute chaincode invoke/query
execute_chaincode() {
    local org_cli="$1"
    local function="$2"
    local args="$3"
    local is_query="${4:-false}"
    
    local cmd_type="invoke"
    if [ "$is_query" = "true" ]; then
        cmd_type="query"
    fi
    
    if [ "$cmd_type" = "invoke" ]; then
        ssh fabricadmin@$(get_org_ip $org_cli) "docker exec $org_cli bash -c \"peer chaincode $cmd_type -o orderer.fabriczakat.local:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem -C $CHANNEL_NAME -n $CC_NAME -c '{\\\"function\\\":\\\"$function\\\",\\\"Args\\\":[$args]}' --waitForEvent\"" 2>&1
    else
        ssh fabricadmin@$(get_org_ip $org_cli) "docker exec $org_cli bash -c \"peer chaincode $cmd_type -C $CHANNEL_NAME -n $CC_NAME -c '{\\\"function\\\":\\\"$function\\\",\\\"Args\\\":[$args]}'\"" 2>&1
    fi
}

get_org_ip() {
    local cli_container="$1"
    if [[ "$cli_container" == *"org1"* ]]; then
        echo "$ORG1_IP"
    else
        echo "$ORG2_IP"
    fi
}

# --- TEST FUNCTIONS ---

# Test 1: Verify network connectivity and chaincode deployment
test_network_connectivity() {
    log "Verifying network connectivity and chaincode status..."
    
    # Check Org1 CLI
    ssh fabricadmin@$ORG1_IP "docker exec $ORG1_CLI_CONTAINER bash -c 'peer lifecycle chaincode querycommitted -C $CHANNEL_NAME -n $CC_NAME'" >/dev/null 2>&1 && \
    
    # Check Org2 CLI  
    ssh fabricadmin@$ORG2_IP "docker exec $ORG2_CLI_CONTAINER bash -c 'peer lifecycle chaincode querycommitted -C $CHANNEL_NAME -n $CC_NAME'" >/dev/null 2>&1
}

# Test 2: Initialize ledger (idempotent test)
test_init_ledger() {
    log "Testing InitLedger function..."
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "InitLedger" "")
    echo "$result" | grep -q "successfully" || echo "$result" | grep -q "already initialized"
}

# Test 3: Query initial programs
test_query_programs() {
    log "Testing GetAllPrograms query..."
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "GetAllPrograms" "" "true")
    echo "$result" | grep -q "PROG-2024-0001" && echo "$result" | grep -q "Bantuan Pendidikan Anak Yatim"
}

# Test 4: Create new donation program
test_create_program() {
    log "Testing CreateProgram function..."
    
    local prog_id="PROG-2024-0100"
    local prog_name="Test Program Functional"
    local description="Program for functional testing"
    local target="5000000"
    local start_date="2024-06-01T00:00:00Z"
    local end_date="2024-12-31T23:59:59Z"
    local created_by="TestAdmin"
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "CreateProgram" "\"$prog_id\",\"$prog_name\",\"$description\",\"$target\",\"$start_date\",\"$end_date\",\"$created_by\"")
    echo "$result" | grep -q "successfully" || ! echo "$result" | grep -q "error"
}

# Test 5: Register new officer
test_register_officer() {
    log "Testing RegisterOfficer function..."
    
    local officer_id="OFF-2024-0100"
    local officer_name="Test Officer Functional"
    local referral_code="TESTREF100"
    
    result=$(execute_chaincode "$ORG2_CLI_CONTAINER" "RegisterOfficer" "\"$officer_id\",\"$officer_name\",\"$referral_code\"")
    echo "$result" | grep -q "successfully" || ! echo "$result" | grep -q "error"
}

# Test 6: Add Zakat donation (Org1)
test_add_zakat_org1() {
    log "Testing AddZakat function (Org1)..."
    
    local zakat_id="ZKT-YDSF-MLG-$(date +%Y%m)-0100"
    local program_id="PROG-2024-0001"
    local muzakki="Functional Test Donor 1"
    local amount="1000000"
    local zakat_type="maal"
    local payment_method="transfer"
    local organization="YDSF Malang"
    local referral_code="REF001"
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "AddZakat" "\"$zakat_id\",\"$program_id\",\"$muzakki\",\"$amount\",\"$zakat_type\",\"$payment_method\",\"$organization\",\"$referral_code\"")
    echo "$result" | grep -q "successfully" || ! echo "$result" | grep -q "error"
    
    # Store for later tests
    export TEST_ZAKAT_ID_1="$zakat_id"
}

# Test 7: Add Zakat donation (Org2)  
test_add_zakat_org2() {
    log "Testing AddZakat function (Org2)..."
    
    local zakat_id="ZKT-YDSF-JTM-$(date +%Y%m)-0100"
    local program_id="PROG-2024-0100"
    local muzakki="Functional Test Donor 2"
    local amount="750000"
    local zakat_type="fitrah"
    local payment_method="ewallet"
    local organization="YDSF Jatim"
    local referral_code="TESTREF100"
    
    result=$(execute_chaincode "$ORG2_CLI_CONTAINER" "AddZakat" "\"$zakat_id\",\"$program_id\",\"$muzakki\",\"$amount\",\"$zakat_type\",\"$payment_method\",\"$organization\",\"$referral_code\"")
    echo "$result" | grep -q "successfully" || ! echo "$result" | grep -q "error"
    
    # Store for later tests
    export TEST_ZAKAT_ID_2="$zakat_id"
}

# Test 8: Query pending zakat
test_query_pending_zakat() {
    log "Testing GetZakatByStatus query (pending)..."
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "GetZakatByStatus" "\"pending\"" "true")
    echo "$result" | grep -q "$TEST_ZAKAT_ID_1" && echo "$result" | grep -q "$TEST_ZAKAT_ID_2"
}

# Test 9: Validate payment (Org1)
test_validate_payment_org1() {
    log "Testing ValidatePayment function (Org1)..."
    
    local receipt_number="RCP-TEST-$(date +%s)-001"
    local validated_by="TestAdmin1"
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "ValidatePayment" "\"$TEST_ZAKAT_ID_1\",\"$receipt_number\",\"$validated_by\"")
    echo "$result" | grep -q "successfully" || ! echo "$result" | grep -q "error"
}

# Test 10: Validate payment (Org2)
test_validate_payment_org2() {
    log "Testing ValidatePayment function (Org2)..."
    
    local receipt_number="RCP-TEST-$(date +%s)-002"
    local validated_by="TestAdmin2"
    
    result=$(execute_chaincode "$ORG2_CLI_CONTAINER" "ValidatePayment" "\"$TEST_ZAKAT_ID_2\",\"$receipt_number\",\"$validated_by\"")
    echo "$result" | grep -q "successfully" || ! echo "$result" | grep -q "error"
}

# Test 11: Query collected zakat
test_query_collected_zakat() {
    log "Testing GetZakatByStatus query (collected)..."
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "GetZakatByStatus" "\"collected\"" "true")
    echo "$result" | grep -q "$TEST_ZAKAT_ID_1" && echo "$result" | grep -q "$TEST_ZAKAT_ID_2"
}

# Test 12: Distribute zakat (Org1)
test_distribute_zakat_org1() {
    log "Testing DistributeZakat function (Org1)..."
    
    local mustahik="Test Mustahik 1"
    local distribution_amount="1000000"
    local distribution_timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "DistributeZakat" "\"$TEST_ZAKAT_ID_1\",\"$mustahik\",\"$distribution_amount\",\"$distribution_timestamp\"")
    echo "$result" | grep -q "successfully" || ! echo "$result" | grep -q "error"
}

# Test 13: Distribute zakat (Org2)
test_distribute_zakat_org2() {
    log "Testing DistributeZakat function (Org2)..."
    
    local mustahik="Test Mustahik 2"
    local distribution_amount="750000"
    local distribution_timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    result=$(execute_chaincode "$ORG2_CLI_CONTAINER" "DistributeZakat" "\"$TEST_ZAKAT_ID_2\",\"$mustahik\",\"$distribution_amount\",\"$distribution_timestamp\"")
    echo "$result" | grep -q "successfully" || ! echo "$result" | grep -q "error"
}

# Test 14: Query distributed zakat
test_query_distributed_zakat() {
    log "Testing GetZakatByStatus query (distributed)..."
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "GetZakatByStatus" "\"distributed\"" "true")
    echo "$result" | grep -q "$TEST_ZAKAT_ID_1" && echo "$result" | grep -q "$TEST_ZAKAT_ID_2"
}

# Test 15: Query by program
test_query_by_program() {
    log "Testing GetZakatByProgram query..."
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "GetZakatByProgram" "\"PROG-2024-0001\"" "true")
    echo "$result" | grep -q "$TEST_ZAKAT_ID_1"
}

# Test 16: Query by officer
test_query_by_officer() {
    log "Testing GetZakatByOfficer query..."
    
    result=$(execute_chaincode "$ORG2_CLI_CONTAINER" "GetZakatByOfficer" "\"TESTREF100\"" "true")
    echo "$result" | grep -q "$TEST_ZAKAT_ID_2"
}

# Test 17: Query by muzakki
test_query_by_muzakki() {
    log "Testing GetZakatByMuzakki query..."
    
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "GetZakatByMuzakki" "\"Functional Test Donor 1\"" "true")
    echo "$result" | grep -q "$TEST_ZAKAT_ID_1"
}

# Test 18: Daily report
test_daily_report() {
    log "Testing GetDailyReport function..."
    
    local report_date=$(date +%Y-%m-%d)
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "GetDailyReport" "\"$report_date\"" "true")
    echo "$result" | grep -q "totalAmount" && echo "$result" | grep -q "transactionCount"
}

# Test 19: Cross-organization consistency
test_cross_org_consistency() {
    log "Testing cross-organization data consistency..."
    
    # Query same data from both orgs
    result1=$(execute_chaincode "$ORG1_CLI_CONTAINER" "GetAllZakat" "" "true")
    result2=$(execute_chaincode "$ORG2_CLI_CONTAINER" "GetAllZakat" "" "true")
    
    # Check if both return same transaction count
    count1=$(echo "$result1" | jq '. | length' 2>/dev/null || echo "0")
    count2=$(echo "$result2" | jq '. | length' 2>/dev/null || echo "0")
    
    [ "$count1" = "$count2" ] && [ "$count1" -gt "0" ]
}

# Test 20: Error handling
test_error_handling() {
    log "Testing error handling with invalid inputs..."
    
    # Try to add zakat with invalid ID format
    result=$(execute_chaincode "$ORG1_CLI_CONTAINER" "AddZakat" "\"INVALID-ID\",\"\",\"Test\",\"100000\",\"maal\",\"transfer\",\"YDSF Malang\",\"\"" 2>&1)
    echo "$result" | grep -q "error" || echo "$result" | grep -q "invalid"
}

# Generate test report
generate_report() {
    log "Generating test report..."
    
    local test_array=$(IFS=,; echo "${TEST_RESULTS[*]}")
    
    cat > "$REPORT_FILE" << EOF
{
  "test_suite": "Zakat Chaincode Functional Tests",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "summary": {
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "success_rate": "$(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%"
  },
  "test_results": [
    $test_array
  ]
}
EOF
    
    log "Test report saved to: $REPORT_FILE"
}

# --- MAIN EXECUTION ---

print_header "ZAKAT CHAINCODE FUNCTIONAL TEST SUITE"

log "Starting comprehensive functional test suite..."
log "Test results will be saved to: $LOG_FILE"

# Execute all tests
run_test "Network Connectivity" "test_network_connectivity"
run_test "Initialize Ledger" "test_init_ledger"
run_test "Query Programs" "test_query_programs"
run_test "Create Program" "test_create_program"
run_test "Register Officer" "test_register_officer"
run_test "Add Zakat (Org1)" "test_add_zakat_org1"
run_test "Add Zakat (Org2)" "test_add_zakat_org2"
run_test "Query Pending Zakat" "test_query_pending_zakat"
run_test "Validate Payment (Org1)" "test_validate_payment_org1"
run_test "Validate Payment (Org2)" "test_validate_payment_org2"
run_test "Query Collected Zakat" "test_query_collected_zakat"
run_test "Distribute Zakat (Org1)" "test_distribute_zakat_org1"
run_test "Distribute Zakat (Org2)" "test_distribute_zakat_org2"
run_test "Query Distributed Zakat" "test_query_distributed_zakat"
run_test "Query by Program" "test_query_by_program"
run_test "Query by Officer" "test_query_by_officer"
run_test "Query by Muzakki" "test_query_by_muzakki"
run_test "Daily Report" "test_daily_report"
run_test "Cross-Org Consistency" "test_cross_org_consistency"
run_test "Error Handling" "test_error_handling"

# Generate final report
generate_report

print_header "TEST SUITE COMPLETE"

log "Final Results:"
log "  Total Tests: $TOTAL_TESTS"
log "  Passed: $PASSED_TESTS"
log "  Failed: $FAILED_TESTS"
log "  Success Rate: $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}" | tee -a $LOG_FILE
    exit 0
else
    echo -e "${RED}❌ $FAILED_TESTS TESTS FAILED${NC}" | tee -a $LOG_FILE
    exit 1
fi