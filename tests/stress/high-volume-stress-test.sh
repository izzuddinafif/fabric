#!/bin/bash
# High Volume Stress Test - Final Consolidated Version
# Tests network performance with concurrent transactions, validation bursts, and query loads

set -e

# Configuration
CHANNEL_NAME="zakatchannel"
CC_NAME="zakat"

ORG1_CLI="cli.org1.fabriczakat.local"
ORG2_CLI="cli.org2.fabriczakat.local"
ORG1_IP="10.104.0.2"
ORG2_IP="10.104.0.4"

LOG_DIR="$HOME/fabric/tests/stress/results"
LOG_FILE="$LOG_DIR/stress-test-$(date +%Y%m%d-%H%M%S).log"
METRICS_CSV="$LOG_DIR/stress-metrics-$(date +%Y%m%d-%H%M%S).csv"
mkdir -p $LOG_DIR
> $LOG_FILE

# Test Configuration - Increased for better TPS
CONCURRENT_TRANSACTIONS=20
VALIDATION_BURST_SIZE=8
QUERY_LOAD_SIZE=25
MAX_CONCURRENT_PROCESSES=10

# Monitoring Integration
PUSHGATEWAY_URL="http://localhost:9091"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v bc >/dev/null 2>&1; then
        missing_deps+=("bc")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "❌ Missing dependencies: ${missing_deps[*]}"
        log "   Install with: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log "✅ All dependencies available"
}

# Initialize metrics collection
init_metrics() {
    echo "timestamp,test_phase,operation_type,duration_seconds,status,details,tps" > "$METRICS_CSV"
    log "📊 Metrics collection initialized: $METRICS_CSV"
}

# Record metric
record_metric() {
    local phase="$1"
    local operation="$2"
    local duration="$3"
    local status="$4"
    local details="$5"
    local tps="$6"
    local timestamp=$(date +%s)
    
    echo "$timestamp,$phase,$operation,$duration,$status,$details,$tps" >> "$METRICS_CSV"
    
    # Push to Prometheus if available
    if curl -s "$PUSHGATEWAY_URL/metrics" >/dev/null 2>&1; then
        cat << EOF | curl -s -X POST "$PUSHGATEWAY_URL/metrics/job/zakat_stress_test/instance/$(hostname)" --data-binary @- || true
# HELP stress_test_operation_duration_seconds Duration of stress test operations
# TYPE stress_test_operation_duration_seconds gauge
stress_test_operation_duration_seconds{phase="$phase",operation="$operation",status="$status"} $duration
# HELP stress_test_operations_per_second Operations per second achieved
# TYPE stress_test_operations_per_second gauge
stress_test_operations_per_second{phase="$phase",operation="$operation"} $tps
EOF
    fi
}

# Execute chaincode with proper JSON escaping
execute_chaincode() {
    local org_cli="$1"
    local function="$2"
    local args="$3"
    local is_query="${4:-false}"
    local org_ip
    
    if [[ "$org_cli" == *"org1"* ]]; then
        org_ip="$ORG1_IP"
    else
        org_ip="$ORG2_IP"
    fi
    
    if [ "$is_query" = "true" ]; then
        # For queries - simpler command
        ssh fabricadmin@$org_ip "docker exec $org_cli peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"$function\",\"Args\":[$args]}'" 2>&1
    else
        # For invokes - with multi-peer endorsement
        ssh fabricadmin@$org_ip "docker exec $org_cli peer chaincode invoke -o orderer.fabriczakat.local:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org1.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org2.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"$function\",\"Args\":[$args]}' --waitForEvent" 2>&1
    fi
}

# Generate random donor names
get_random_donor() {
    local donors=(
        "Ahmad Kurniawan" "Siti Rahayu" "Budi Santoso" "Fatimah Zahra"
        "Muhammad Rizki" "Dewi Sartika" "Andi Wijaya" "Nurul Hidayah"
    )
    echo "${donors[$((RANDOM % ${#donors[@]}))]}"
}

# Create test transaction
create_zakat_transaction() {
    local tx_suffix="$1"
    local org_choice="${2:-org1}"
    local random_num=$((RANDOM % 9999))
    
    local org_cli="$ORG1_CLI"
    local org_code="MLG"
    local organization="YDSF Malang"
    
    if [ "$org_choice" = "org2" ]; then
        org_cli="$ORG2_CLI"
        org_code="JTM"
        organization="YDSF Jatim"
    fi
    
    # Fixed zakat ID format
    local zakat_id="ZKT-YDSF-$org_code-$(date +%Y%m)-$(printf "%04d" $random_num)"
    local muzakki=$(get_random_donor)
    local amount=$((500000 + RANDOM % 1500000))
    local types=("maal" "fitrah")
    local zakat_type="${types[$((RANDOM % 2))]}"
    local methods=("transfer" "ewallet" "cash")
    local payment_method="${methods[$((RANDOM % 3))]}"
    
    # Prepare args properly quoted
    local args="\"$zakat_id\",\"PROG-2024-0001\",\"$muzakki\",\"$amount\",\"$zakat_type\",\"$payment_method\",\"$organization\",\"REF001\""
    
    local start_time=$(date +%s.%N)
    
    result=$(execute_chaincode "$org_cli" "AddZakat" "$args" 2>&1)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    if echo "$result" | grep -q "Chaincode invoke successful"; then
        echo "$zakat_id,$duration,SUCCESS"
        record_metric "transaction_creation" "AddZakat" "$duration" "SUCCESS" "$org_choice:$zakat_id" "0"
        return 0
    else
        echo "$zakat_id,$duration,FAILED"
        record_metric "transaction_creation" "AddZakat" "$duration" "FAILED" "$org_choice:error" "0"
        return 1
    fi
}

# STRESS TEST 1: Concurrent Transaction Creation
test_concurrent_transactions() {
    log "=== STRESS TEST 1: Concurrent Transaction Creation ($CONCURRENT_TRANSACTIONS transactions) ==="
    
    local pids=()
    local results_file="/tmp/stress_results_$$"
    > $results_file
    
    local start_time=$(date +%s)
    
    # Create transactions concurrently
    for i in $(seq 1 $CONCURRENT_TRANSACTIONS); do
        local org_choice="org1"
        if [ $((i % 2)) -eq 0 ]; then
            org_choice="org2"
        fi
        
        (
            result=$(create_zakat_transaction "ST$i" "$org_choice")
            echo "$result" >> $results_file
        ) &
        
        pids+=($!)
        
        # Limit concurrent processes
        if [ ${#pids[@]} -ge $MAX_CONCURRENT_PROCESSES ]; then
            wait ${pids[0]}
            pids=("${pids[@]:1}")
        fi
        
        # Small delay to avoid overwhelming - reduced for better TPS
        sleep 0.1
    done
    
    # Wait for all transactions
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Analyze results
    local success_count=$(grep -c "SUCCESS" $results_file 2>/dev/null || echo "0")
    local failed_count=$(grep -c "FAILED" $results_file 2>/dev/null || echo "0")
    local avg_response_time=$(awk -F',' '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' $results_file 2>/dev/null)
    local effective_tps=$(echo "scale=2; $success_count / $total_duration" | bc -l)
    
    log "Concurrent Transaction Results:"
    log "  Total Duration: ${total_duration}s"
    log "  Successful: $success_count"
    log "  Failed: $failed_count"
    log "  Average Response Time: ${avg_response_time}s"
    log "  Effective TPS: $effective_tps"
    
    # Store successful transactions for validation tests - clean transaction IDs
    SUCCESSFUL_TRANSACTIONS_FILE="/tmp/successful_transactions_$$"
    grep "SUCCESS" $results_file 2>/dev/null | cut -d',' -f1 | grep -o 'ZKT-[A-Z-]*-[0-9]*-[0-9]*' > "$SUCCESSFUL_TRANSACTIONS_FILE" || touch "$SUCCESSFUL_TRANSACTIONS_FILE"
    
    rm -f $results_file
    
    if [ $success_count -ge $((CONCURRENT_TRANSACTIONS * 60 / 100)) ]; then
        log "✅ Concurrent transaction test PASSED (>60% success rate)"
        return 0
    else
        log "❌ Concurrent transaction test FAILED (<60% success rate)"
        return 1
    fi
}

# Validate payment
validate_payment() {
    local zakat_id="$1"
    local org_choice="$2"
    
    local org_cli="$ORG1_CLI"
    if [ "$org_choice" = "org2" ]; then
        org_cli="$ORG2_CLI"
    fi
    
    local receipt_number="RCP-STRESS-$(date +%s)-$((RANDOM % 9999))"
    local validated_by="StressTestAdmin"
    
    local args="\"$zakat_id\",\"$receipt_number\",\"$validated_by\""
    
    local start_time=$(date +%s.%N)
    
    result=$(execute_chaincode "$org_cli" "ValidatePayment" "$args" 2>&1)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    if echo "$result" | grep -q "Chaincode invoke successful"; then
        echo "$zakat_id,$duration,SUCCESS"
        return 0
    else
        echo "$zakat_id,$duration,FAILED"
        return 1
    fi
}

# STRESS TEST 2: Validation Burst Load
test_validation_burst() {
    log "=== STRESS TEST 2: Payment Validation Burst Load ==="
    
    if [ ! -f "$SUCCESSFUL_TRANSACTIONS_FILE" ]; then
        log "❌ No successful transactions available for validation test"
        return 1
    fi
    
    local transactions=($(head -n $VALIDATION_BURST_SIZE "$SUCCESSFUL_TRANSACTIONS_FILE"))
    local num_transactions=${#transactions[@]}
    
    if [ $num_transactions -eq 0 ]; then
        log "❌ No transactions available for validation"
        return 1
    fi
    
    log "Starting validation burst for $num_transactions transactions..."
    
    local pids=()
    local validation_results="/tmp/validation_results_$$"
    > $validation_results
    
    local start_time=$(date +%s)
    
    # Launch concurrent validations
    for i in "${!transactions[@]}"; do
        local tx_id="${transactions[$i]}"
        
        if [ $((i % 2)) -eq 0 ]; then
            org_choice="org1"
        else
            org_choice="org2"
        fi
        
        (
            result=$(validate_payment "$tx_id" "$org_choice")
            echo "$result" >> $validation_results
        ) &
        
        pids+=($!)
        
        # Limit concurrent processes
        if [ ${#pids[@]} -ge $MAX_CONCURRENT_PROCESSES ]; then
            wait ${pids[0]}
            pids=("${pids[@]:1}")
        fi
        
        sleep 0.5
    done
    
    # Wait for all validations
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Analyze validation results
    local success_count=$(grep -c "SUCCESS" $validation_results 2>/dev/null || echo "0")
    local failed_count=$(grep -c "FAILED" $validation_results 2>/dev/null || echo "0")
    local avg_response_time=$(awk -F',' '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' $validation_results 2>/dev/null)
    local validation_tps=$(echo "scale=2; $success_count / $total_duration" | bc -l)
    
    log "Validation Burst Results:"
    log "  Total Duration: ${total_duration}s"
    log "  Successful: $success_count"
    log "  Failed: $failed_count"
    log "  Average Response Time: ${avg_response_time}s"
    log "  Validation TPS: $validation_tps"
    
    rm -f $validation_results
    
    if [ $success_count -ge $((num_transactions * 50 / 100)) ]; then
        log "✅ Validation burst test PASSED (>50% success rate)"
        return 0
    else
        log "❌ Validation burst test FAILED (<50% success rate)"
        return 1
    fi
}

# Execute query operations
execute_query_load() {
    local query_type="$1"
    local start_time=$(date +%s.%N)
    
    case $query_type in
        "status")
            result=$(execute_chaincode "$ORG1_CLI" "GetZakatByStatus" "\"pending\"" "true" 2>&1)
            ;;
        "program")
            result=$(execute_chaincode "$ORG2_CLI" "GetZakatByProgram" "\"PROG-2024-0001\"" "true" 2>&1)
            ;;
        "all")
            result=$(execute_chaincode "$ORG1_CLI" "GetAllZakat" "" "true" 2>&1)
            ;;
    esac
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    if [[ -n "$result" && ! "$result" =~ "error" && ! "$result" =~ "Error" ]]; then
        echo "$query_type,$duration,SUCCESS"
        return 0
    else
        echo "$query_type,$duration,FAILED"
        return 1
    fi
}

# STRESS TEST 3: Query Performance Under Load
test_query_performance() {
    log "=== STRESS TEST 3: Query Performance Under Load ($QUERY_LOAD_SIZE queries) ==="
    
    local query_types=("status" "program" "all")
    local pids=()
    local query_results="/tmp/query_results_$$"
    > $query_results
    
    local start_time=$(date +%s)
    
    # Launch concurrent queries
    for i in $(seq 1 $QUERY_LOAD_SIZE); do
        local query_type="${query_types[$((RANDOM % 3))]}"
        
        (
            result=$(execute_query_load "$query_type")
            echo "$result" >> $query_results
        ) &
        
        pids+=($!)
        
        # Limit concurrent processes
        if [ ${#pids[@]} -ge $MAX_CONCURRENT_PROCESSES ]; then
            wait ${pids[0]}
            pids=("${pids[@]:1}")
        fi
        
        sleep 0.2
    done
    
    # Wait for all queries
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Analyze query results
    local success_count=$(grep -c "SUCCESS" $query_results 2>/dev/null || echo "0")
    local failed_count=$(grep -c "FAILED" $query_results 2>/dev/null || echo "0")
    local avg_response_time=$(awk -F',' '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' $query_results 2>/dev/null)
    local query_tps=$(echo "scale=2; $success_count / $total_duration" | bc -l)
    
    log "Query Performance Results:"
    log "  Total Duration: ${total_duration}s"
    log "  Successful: $success_count"
    log "  Failed: $failed_count"
    log "  Average Response Time: ${avg_response_time}s"
    log "  Query TPS: $query_tps"
    
    rm -f $query_results
    
    if [ $success_count -ge $((QUERY_LOAD_SIZE * 70 / 100)) ]; then
        log "✅ Query performance test PASSED (>70% success rate)"
        return 0
    else
        log "❌ Query performance test FAILED (<70% success rate)"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f "/tmp/successful_transactions_$$"
    rm -f "/tmp/stress_results_$$"
    rm -f "/tmp/validation_results_$$"
    rm -f "/tmp/query_results_$$"
}

# Check monitoring integration
check_monitoring_integration() {
    if curl -s "$PUSHGATEWAY_URL/metrics" >/dev/null 2>&1; then
        log "✅ Prometheus Pushgateway accessible - real-time metrics enabled"
        log "   View metrics: http://localhost:3000"
        return 0
    else
        log "⚠️  Prometheus Pushgateway not accessible - metrics stored locally only"
        return 1
    fi
}

# Main execution
main() {
    log "🚀 Starting High Volume Stress Test Suite"
    log "Testing zakat network performance with concurrent operations"
    
    # Check dependencies
    check_dependencies
    
    # Initialize features
    init_metrics
    check_monitoring_integration
    
    local passed_stress_tests=0
    
    # Record test suite start
    record_metric "test_suite" "start" "0" "STARTED" "stress_testing" "0"
    
    # Run stress tests
    if test_concurrent_transactions; then
        passed_stress_tests=$((passed_stress_tests + 1))
    fi
    
    if test_validation_burst; then
        passed_stress_tests=$((passed_stress_tests + 1))
    fi
    
    if test_query_performance; then
        passed_stress_tests=$((passed_stress_tests + 1))
    fi
    
    # Record test suite completion
    record_metric "test_suite" "complete" "0" "FINISHED" "total_passed:$passed_stress_tests" "0"
    
    # Results summary
    echo -e "\n${BOLD}=== HIGH VOLUME STRESS TEST RESULTS ===${NC}" | tee -a $LOG_FILE
    log "📊 Final Results:"
    log "  Tests Passed: $passed_stress_tests/3"
    log "  Success Rate: $(echo "scale=1; $passed_stress_tests * 100 / 3" | bc -l)%"
    log ""
    log "📁 Metrics collected: $METRICS_CSV"
    log "📈 Monitoring: $(check_monitoring_integration >/dev/null 2>&1 && echo "Enabled" || echo "Local only")"
    
    if [ $passed_stress_tests -eq 3 ]; then
        echo -e "${GREEN}🎉 ALL STRESS TESTS PASSED!${NC}" | tee -a $LOG_FILE
        echo -e "${GREEN}Network demonstrates excellent performance under high load.${NC}" | tee -a $LOG_FILE
        exit 0
    else
        echo -e "${RED}❌ SOME STRESS TESTS FAILED${NC}" | tee -a $LOG_FILE
        echo -e "${RED}Review detailed metrics for performance optimization opportunities.${NC}" | tee -a $LOG_FILE
        exit 1
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Execute main function
main "$@"