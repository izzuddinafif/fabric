#!/bin/bash
# Network Resilience Test - Final Consolidated Version
# Tests network failure recovery scenarios with peer failures and container restarts

set -e

# Configuration
CHANNEL_NAME="zakatchannel"
CC_NAME="zakat"

ORG1_CLI="cli.org1.fabriczakat.local"
ORG2_CLI="cli.org2.fabriczakat.local"
ORG1_IP="10.104.0.2"
ORG2_IP="10.104.0.4"
ORDERER_IP="10.104.0.3"

LOG_DIR="$HOME/fabric/tests/stress/results"
LOG_FILE="$LOG_DIR/resilience-test-$(date +%Y%m%d-%H%M%S).log"
METRICS_CSV="$LOG_DIR/resilience-metrics-$(date +%Y%m%d-%H%M%S).csv"
mkdir -p $LOG_DIR
> $LOG_FILE

# Monitoring integration
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
    
    if ! command -v timeout >/dev/null 2>&1; then
        log "⚠️  timeout command not available - using basic timing"
        USE_TIMEOUT=false
    else
        USE_TIMEOUT=true
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "❌ Missing dependencies: ${missing_deps[*]}"
        log "   Install with: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log "✅ All dependencies available"
}

# Initialize resilience metrics tracking
init_resilience_metrics() {
    echo "timestamp,scenario,operation,duration_seconds,status,details,recovery_time" > "$METRICS_CSV"
    log "📊 Resilience metrics collection initialized: $METRICS_CSV"
}

# Record resilience metric
record_resilience_metric() {
    local scenario="$1"
    local operation="$2"
    local duration="$3"
    local status="$4"
    local details="$5"
    local recovery_time="$6"
    local timestamp=$(date +%s)
    
    echo "$timestamp,$scenario,$operation,$duration,$status,$details,$recovery_time" >> "$METRICS_CSV"
    
    # Push to Prometheus if available
    if curl -s "$PUSHGATEWAY_URL/metrics" >/dev/null 2>&1; then
        cat << EOF | curl -s -X POST "$PUSHGATEWAY_URL/metrics/job/zakat_resilience_test/instance/$(hostname)" --data-binary @- || true
# HELP resilience_test_operation_duration_seconds Duration of resilience test operations
# TYPE resilience_test_operation_duration_seconds gauge
resilience_test_operation_duration_seconds{scenario="$scenario",operation="$operation",status="$status"} $duration
# HELP resilience_test_recovery_time_seconds Time to recover from failure
# TYPE resilience_test_recovery_time_seconds gauge
resilience_test_recovery_time_seconds{scenario="$scenario",operation="$operation"} $recovery_time
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
        if [ "$USE_TIMEOUT" = "true" ]; then
            timeout 30 ssh fabricadmin@$org_ip "docker exec $org_cli peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"$function\",\"Args\":[$args]}'" 2>&1
        else
            ssh fabricadmin@$org_ip "docker exec $org_cli peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"$function\",\"Args\":[$args]}'" 2>&1
        fi
    else
        # For invokes - with multi-peer endorsement
        if [ "$USE_TIMEOUT" = "true" ]; then
            timeout 60 ssh fabricadmin@$org_ip "docker exec $org_cli peer chaincode invoke -o orderer.fabriczakat.local:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org1.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org2.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"$function\",\"Args\":[$args]}' --waitForEvent" 2>&1
        else
            ssh fabricadmin@$org_ip "docker exec $org_cli peer chaincode invoke -o orderer.fabriczakat.local:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org1.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org2.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"$function\",\"Args\":[$args]}' --waitForEvent" 2>&1
        fi
    fi
}

# Enhanced network health check
check_network_health() {
    local scenario="$1"
    local start_time=$(date +%s.%N)
    
    log "🔍 Checking network health for: $scenario"
    
    local failed_components=0
    local health_details=""
    
    # Test Org1 connectivity
    if [ "$USE_TIMEOUT" = "true" ]; then
        if timeout 20 ssh fabricadmin@$ORG1_IP "docker exec $ORG1_CLI peer channel list" >/dev/null 2>&1; then
            health_details="${health_details}org1:healthy,"
            log "✅ Org1 peer: HEALTHY"
        else
            failed_components=$((failed_components + 1))
            health_details="${health_details}org1:failed,"
            log "❌ Org1 peer: FAILED"
        fi
    else
        if ssh fabricadmin@$ORG1_IP "docker exec $ORG1_CLI peer channel list" >/dev/null 2>&1; then
            health_details="${health_details}org1:healthy,"
            log "✅ Org1 peer: HEALTHY"
        else
            failed_components=$((failed_components + 1))
            health_details="${health_details}org1:failed,"
            log "❌ Org1 peer: FAILED"
        fi
    fi
    
    # Test Org2 connectivity
    if [ "$USE_TIMEOUT" = "true" ]; then
        if timeout 20 ssh fabricadmin@$ORG2_IP "docker exec $ORG2_CLI peer channel list" >/dev/null 2>&1; then
            health_details="${health_details}org2:healthy,"
            log "✅ Org2 peer: HEALTHY"
        else
            failed_components=$((failed_components + 1))
            health_details="${health_details}org2:failed,"
            log "❌ Org2 peer: FAILED"
        fi
    else
        if ssh fabricadmin@$ORG2_IP "docker exec $ORG2_CLI peer channel list" >/dev/null 2>&1; then
            health_details="${health_details}org2:healthy,"
            log "✅ Org2 peer: HEALTHY"
        else
            failed_components=$((failed_components + 1))
            health_details="${health_details}org2:failed,"
            log "❌ Org2 peer: FAILED"
        fi
    fi
    
    # Test Orderer connectivity (localhost)
    if docker ps --filter name=orderer --format '{{.Status}}' | grep -q "Up"; then
        health_details="${health_details}orderer:healthy"
        log "✅ Orderer: HEALTHY"
    else
        failed_components=$((failed_components + 1))
        health_details="${health_details}orderer:failed"
        log "❌ Orderer: FAILED"
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    local status="HEALTHY"
    if [ $failed_components -gt 0 ]; then
        status="DEGRADED"
    fi
    
    # Record health check metrics
    record_resilience_metric "$scenario" "health_check" "$duration" "$status" "$health_details" "0"
    
    log "📊 Network Health Summary:"
    log "  Failed Components: $failed_components"
    log "  Health Check Duration: ${duration}s"
    log "  Status: $status"
    
    return $failed_components
}

# Create test transaction
create_test_transaction() {
    local org_cli="$1"
    local tx_suffix="$2"
    local timestamp=$(date +%s)
    local random_num=$((RANDOM % 9999))
    
    # Fixed zakat ID format
    local zakat_id="ZKT-YDSF-MLG-$(date +%Y%m)-$(printf "%04d" $((timestamp % 10000 + random_num % 1000)))"
    local muzakki="Resilience Test User $tx_suffix"
    local amount="750000"
    
    # Prepare args properly quoted
    local args="\"$zakat_id\",\"PROG-2024-0001\",\"$muzakki\",\"$amount\",\"maal\",\"transfer\",\"YDSF Malang\",\"REF001\""
    
    log "📝 Creating test transaction: $zakat_id"
    
    local result
    result=$(execute_chaincode "$org_cli" "AddZakat" "$args" false)
    
    if echo "$result" | grep -q "Chaincode invoke successful"; then
        log "✅ Transaction created successfully: $zakat_id"
        echo "$zakat_id"
        return 0
    else
        log "❌ Failed to create transaction: $zakat_id"
        log "   Error: $result"
        return 1
    fi
}

# Improved transaction verification
verify_transaction_consistency() {
    local zakat_id="$1"
    
    # Clean the zakat_id by extracting just the ZKT-* part
    zakat_id=$(echo "$zakat_id" | grep -o 'ZKT-[A-Z-]*-[0-9]*-[0-9]*' | head -1)
    
    log "🔍 Verifying transaction consistency: $zakat_id"
    
    # Add small delay for blockchain propagation
    sleep 2
    
    # Query from Org1
    local result1
    result1=$(ssh fabricadmin@$ORG1_IP "docker exec $ORG1_CLI peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"QueryZakat\",\"Args\":[\"$zakat_id\"]}'" 2>&1)
    
    # Query from Org2  
    local result2
    result2=$(ssh fabricadmin@$ORG2_IP "docker exec $ORG2_CLI peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"QueryZakat\",\"Args\":[\"$zakat_id\"]}'" 2>&1)
    
    # Check if both queries returned valid JSON
    if echo "$result1" | jq . >/dev/null 2>&1 && echo "$result2" | jq . >/dev/null 2>&1; then
        # Extract ID from JSON responses for validation
        local id1=$(echo "$result1" | jq -r '.ID' 2>/dev/null || echo "")
        local id2=$(echo "$result2" | jq -r '.ID' 2>/dev/null || echo "")
        
        if [[ "$id1" == "$zakat_id" && "$id2" == "$zakat_id" ]]; then
            log "✅ Transaction consistency verified: $zakat_id"
            return 0
        else
            log "❌ Transaction data inconsistent between orgs"
            log "   Org1 ID: $id1, Org2 ID: $id2, Expected: $zakat_id"
            return 1
        fi
    else
        log "❌ Query failed or returned invalid response"
        log "   Org1 result: ${result1:0:100}..."
        log "   Org2 result: ${result2:0:100}..."
        return 1
    fi
}

# Wait for container to be fully ready
wait_for_container_ready() {
    local container_name="$1"
    local host_ip="$2"
    local max_wait="${3:-60}"
    
    log "⏳ Waiting for $container_name to be ready..."
    
    local count=0
    while [ $count -lt $max_wait ]; do
        if ssh fabricadmin@$host_ip "docker ps --filter name=$container_name --format '{{.Status}}'" | grep -q "Up"; then
            # Container is up, wait a bit more for full readiness
            sleep 10
            log "✅ $container_name is ready"
            return 0
        fi
        sleep 2
        count=$((count + 2))
    done
    
    log "❌ $container_name failed to become ready within ${max_wait}s"
    return 1
}

# SCENARIO 1: Peer Failure Recovery Test
test_peer_failure_recovery() {
    log "=== SCENARIO 1: Peer Failure Recovery Test ==="
    local scenario_start=$(date +%s)
    
    # Create baseline transaction
    log "📝 Creating baseline transaction before peer failure..."
    local baseline_tx
    baseline_tx=$(create_test_transaction "$ORG1_CLI" "BL")
    
    if [ $? -ne 0 ]; then
        log "❌ Failed to create baseline transaction"
        return 1
    fi
    
    # Verify baseline transaction works
    log "🔍 Verifying baseline transaction..."
    if ! verify_transaction_consistency "$baseline_tx"; then
        log "❌ Baseline transaction verification failed"
        return 1
    fi
    
    # Stop Org1 peer
    log "🛑 Stopping Org1 peer to simulate failure..."
    ssh fabricadmin@$ORG1_IP "docker stop peer.org1.fabriczakat.local" >/dev/null 2>&1
    
    sleep 15
    
    # Try to create transaction with Org1 down (should fail due to endorsement policy)
    log "🧪 Testing operations with Org1 peer down (expected to fail)..."
    local failure_tx
    failure_tx=$(create_test_transaction "$ORG2_CLI" "FL" 2>/dev/null || echo "EXPECTED_FAILURE")
    
    if [[ "$failure_tx" == "EXPECTED_FAILURE" ]]; then
        log "✅ Expected failure confirmed - endorsement policy working correctly"
    else
        log "⚠️  Unexpected success during peer failure"
    fi
    
    # Restart Org1 peer
    log "🔄 Restarting Org1 peer..."
    local recovery_start=$(date +%s)
    ssh fabricadmin@$ORG1_IP "docker start peer.org1.fabriczakat.local" >/dev/null 2>&1
    
    # Wait for peer to be fully ready
    if ! wait_for_container_ready "peer.org1.fabriczakat.local" "$ORG1_IP" 90; then
        log "❌ Peer failed to restart properly"
        return 1
    fi
    
    local recovery_end=$(date +%s)
    local recovery_time=$((recovery_end - recovery_start))
    
    # Create post-recovery transaction
    log "📝 Creating post-recovery transaction..."
    local post_recovery_tx
    post_recovery_tx=$(create_test_transaction "$ORG1_CLI" "PR")
    
    if [ $? -eq 0 ]; then
        # Verify both transactions
        log "🔍 Verifying data consistency after peer recovery..."
        if verify_transaction_consistency "$baseline_tx" && verify_transaction_consistency "$post_recovery_tx"; then
            local scenario_end=$(date +%s)
            local scenario_duration=$((scenario_end - scenario_start))
            record_resilience_metric "peer_failure_recovery" "complete_scenario" "$scenario_duration" "SUCCESS" "baseline:$baseline_tx,post_recovery:$post_recovery_tx" "$recovery_time"
            log "✅ Peer failure recovery test PASSED"
            log "   Recovery time: ${recovery_time}s"
            log "   Total scenario time: ${scenario_duration}s"
            return 0
        else
            log "❌ Peer failure recovery test FAILED - consistency check failed"
            return 1
        fi
    else
        log "❌ Peer failure recovery test FAILED - could not create post-recovery transaction"
        return 1
    fi
}

# SCENARIO 2: Container Restart Impact Test
test_container_restart_impact() {
    log "=== SCENARIO 2: Container Restart Impact Test ==="
    local scenario_start=$(date +%s)
    
    # Create pre-restart transaction
    log "📝 Creating pre-restart transaction..."
    local pre_restart_tx
    pre_restart_tx=$(create_test_transaction "$ORG1_CLI" "CR")
    
    if [ $? -ne 0 ]; then
        log "❌ Failed to create pre-restart transaction"
        return 1
    fi
    
    # Verify pre-restart transaction
    if ! verify_transaction_consistency "$pre_restart_tx"; then
        log "❌ Pre-restart transaction verification failed"
        return 1
    fi
    
    # Restart Org2 peer
    log "🔄 Restarting Org2 peer container..."
    local restart_start=$(date +%s)
    ssh fabricadmin@$ORG2_IP "docker restart peer.org2.fabriczakat.local" >/dev/null 2>&1
    
    # Wait for peer to be fully ready
    if ! wait_for_container_ready "peer.org2.fabriczakat.local" "$ORG2_IP" 90; then
        log "❌ Peer failed to restart properly"
        return 1
    fi
    
    local restart_end=$(date +%s)
    local restart_time=$((restart_end - restart_start))
    
    # Test transaction creation after restart
    log "📝 Testing transaction creation after container restart..."
    
    # Add extra wait time for peer to fully sync after restart
    log "⏳ Allowing extra time for peer sync after restart..."
    sleep 5
    
    local post_restart_tx
    post_restart_tx=$(create_test_transaction "$ORG1_CLI" "AR")
    
    if [ $? -eq 0 ]; then
        # Verify both transactions
        log "🔍 Verifying transaction consistency..."
        if verify_transaction_consistency "$pre_restart_tx" && verify_transaction_consistency "$post_restart_tx"; then
            local scenario_end=$(date +%s)
            local scenario_duration=$((scenario_end - scenario_start))
            record_resilience_metric "container_restart" "complete_scenario" "$scenario_duration" "SUCCESS" "pre_restart:$pre_restart_tx,post_restart:$post_restart_tx" "$restart_time"
            log "✅ Container restart impact test PASSED"
            log "   Restart time: ${restart_time}s"
            log "   Total scenario time: ${scenario_duration}s"
            return 0
        else
            log "❌ Container restart impact test FAILED - consistency check failed"
            return 1
        fi
    else
        log "❌ Container restart impact test FAILED - could not create post-restart transaction"
        return 1
    fi
}

# SCENARIO 3: Network Stress Test
test_network_stress() {
    log "=== SCENARIO 3: Network Stress Test ==="
    local scenario_start=$(date +%s)
    
    log "🚀 Starting network stress test with multiple transactions..."
    
    # Create multiple transactions to stress the network
    local transaction_ids=()
    local success_count=0
    local total_transactions=4
    
    for i in $(seq 1 $total_transactions); do
        log "Creating transaction $i/$total_transactions..."
        
        # Alternate between orgs
        local org_cli="$ORG1_CLI"
        if [ $((i % 2)) -eq 0 ]; then
            org_cli="$ORG2_CLI"
        fi
        
        local tx_id
        tx_id=$(create_test_transaction "$org_cli" "ST$i")
        if [ $? -eq 0 ]; then
            transaction_ids+=("$tx_id")
            success_count=$((success_count + 1))
            log "✅ Transaction $i created: $tx_id"
        else
            log "❌ Transaction $i failed"
        fi
        
        # Small delay between transactions
        sleep 3
    done
    
    log "📊 Transaction creation complete: $success_count/$total_transactions successful"
    
    # Verify all successful transactions
    log "🔍 Verifying all transactions for consistency..."
    local verified_count=0
    
    for tx_id in "${transaction_ids[@]}"; do
        if verify_transaction_consistency "$tx_id"; then
            verified_count=$((verified_count + 1))
            log "✅ Verified: $tx_id"
        else
            log "❌ Verification failed: $tx_id"
        fi
        sleep 2
    done
    
    local scenario_end=$(date +%s)
    local scenario_duration=$((scenario_end - scenario_start))
    
    log "📊 Network stress test results:"
    log "  Transactions created: $success_count/$total_transactions"
    log "  Transactions verified: $verified_count/$success_count"
    log "  Total duration: ${scenario_duration}s"
    
    # Consider test successful if at least 75% of transactions work
    local success_threshold=$((total_transactions * 75 / 100))
    
    if [ $verified_count -ge $success_threshold ]; then
        record_resilience_metric "network_stress" "complete_scenario" "$scenario_duration" "SUCCESS" "verified:$verified_count,total:$total_transactions" "0"
        log "✅ Network stress test PASSED ($verified_count/$total_transactions transactions verified)"
        return 0
    else
        record_resilience_metric "network_stress" "complete_scenario" "$scenario_duration" "FAILED" "verified:$verified_count,total:$total_transactions" "0"
        log "❌ Network stress test FAILED (only $verified_count/$total_transactions transactions verified)"
        return 1
    fi
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
    local start_time=$(date +%s)
    
    log "🚀 Starting Network Resilience Test Suite"
    log "Testing 3-node multi-host Hyperledger Fabric zakat network resilience"
    
    # Check dependencies
    check_dependencies
    
    # Initialize features
    init_resilience_metrics
    check_monitoring_integration
    
    # Record test suite start
    record_resilience_metric "test_suite" "start" "0" "STARTED" "resilience_testing" "0"
    
    # Initial network health check
    if check_network_health "Initial" && [ $? -eq 0 ]; then
        log "✅ Initial network health check passed"
    else
        log "⚠️  Initial network health check shows some issues, but continuing..."
    fi
    
    local total_tests=3
    local passed_tests=0
    
    # Run resilience tests
    log "\n🧪 Starting resilience test scenarios..."
    
    if test_peer_failure_recovery; then
        passed_tests=$((passed_tests + 1))
    fi
    
    if test_container_restart_impact; then
        passed_tests=$((passed_tests + 1))
    fi
    
    if test_network_stress; then
        passed_tests=$((passed_tests + 1))
    fi
    
    # Final network health check
    log "\n🔍 Performing final network health check..."
    sleep 10
    if check_network_health "Final" && [ $? -eq 0 ]; then
        log "✅ Final network health check passed"
    else
        log "⚠️  Final network health check shows some issues"
    fi
    
    local end_time=$(date +%s)
    local test_duration=$((end_time - start_time))
    
    # Record test suite completion
    record_resilience_metric "test_suite" "complete" "$test_duration" "FINISHED" "total_passed:$passed_tests" "0"
    
    # Results summary
    echo -e "\n${BOLD}=== NETWORK RESILIENCE TEST RESULTS ===${NC}" | tee -a $LOG_FILE
    log "📊 Final Results:"
    log "  Tests Passed: $passed_tests/$total_tests"
    log "  Success Rate: $(echo "scale=1; $passed_tests * 100 / $total_tests" | bc -l)%"
    log "  Total Test Duration: ${test_duration}s"
    log ""
    log "📁 Metrics collected: $METRICS_CSV"
    log "📈 Monitoring: $(check_monitoring_integration >/dev/null 2>&1 && echo "Enabled" || echo "Local only")"
    
    if [ $passed_tests -eq $total_tests ]; then
        echo -e "${GREEN}🎉 ALL RESILIENCE TESTS PASSED!${NC}" | tee -a $LOG_FILE
        echo -e "${GREEN}Network demonstrates excellent resilience and recovery capabilities.${NC}" | tee -a $LOG_FILE
        exit 0
    elif [ $passed_tests -ge $((total_tests * 60 / 100)) ]; then
        echo -e "${YELLOW}⚡ MOST RESILIENCE TESTS PASSED${NC}" | tee -a $LOG_FILE
        echo -e "${YELLOW}Network shows good resilience with some areas for improvement.${NC}" | tee -a $LOG_FILE
        exit 0
    else
        echo -e "${RED}❌ RESILIENCE TESTS NEED IMPROVEMENT${NC}" | tee -a $LOG_FILE
        echo -e "${RED}Review detailed metrics for network optimization opportunities.${NC}" | tee -a $LOG_FILE
        exit 1
    fi
}

# Execute main function
main "$@"