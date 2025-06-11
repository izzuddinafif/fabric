#!/bin/bash
# Script 28: Automated Performance Testing Execution
# Runs comprehensive performance and stress testing for zakat network
# Follows pattern of scripts 00-27 for integration with deployment pipeline

set -e

# Source common functions if available
if [ -f "$(dirname "$0")/helper/common.sh" ]; then
    source "$(dirname "$0")/helper/common.sh"
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/28-run-performance-tests.log"

# Test Configuration
TESTS_DIR="$PROJECT_ROOT/tests"
CALIPER_DIR="$TESTS_DIR/caliper"
FUNCTIONAL_DIR="$TESTS_DIR/functional"
STRESS_DIR="$TESTS_DIR/stress"

# Ensure log directory exists
mkdir -p "$LOG_DIR"
> "$LOG_FILE"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_header() {
    local title="$1"
    local width=80
    local line=$(printf '%*s' "$width" | tr ' ' '=')
    echo -e "\n${BOLD}${BLUE}${line}${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}${BLUE}   $title${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}${BLUE}${line}${NC}\n" | tee -a "$LOG_FILE"
}

print_section() {
    local title="$1"
    echo -e "\n${BOLD}${YELLOW}=== $title ===${NC}" | tee -a "$LOG_FILE"
}

# Verify network is running
verify_network_status() {
    log "Verifying zakat network status..."
    
    # Check if orderer is running (localhost since this is the orderer node)
    if ! docker ps --filter name=orderer --format '{{.Status}}' | grep -q "Up"; then
        log "❌ Orderer is not running. Please run scripts 00-27 first."
        return 1
    fi
    
    # Check if peers are running
    if ! ssh fabricadmin@10.104.0.2 "docker ps --filter name=peer --format '{{.Status}}'" | grep -q "Up"; then
        log "❌ Org1 peer is not running. Please run scripts 00-27 first."
        return 1
    fi
    
    if ! ssh fabricadmin@10.104.0.4 "docker ps --filter name=peer --format '{{.Status}}'" | grep -q "Up"; then
        log "❌ Org2 peer is not running. Please run scripts 00-27 first."
        return 1
    fi
    
    # Verify chaincode is committed
    if ! ssh fabricadmin@10.104.0.2 "docker exec cli.org1.fabriczakat.local peer lifecycle chaincode querycommitted -C zakatchannel -n zakat" | grep -q "Version: 2.0"; then
        log "❌ Zakat chaincode v2.0 is not committed. Please run script 26 first."
        return 1
    fi
    
    log "✅ Network status verified - all components running"
    return 0
}

# Pre-test network health check
pre_test_health_check() {
    log "Performing pre-test network health check..."
    
    # Test basic chaincode functionality
    if ssh fabricadmin@10.104.0.2 "docker exec cli.org1.fabriczakat.local peer chaincode query -C zakatchannel -n zakat -c '{\"function\":\"GetAllPrograms\",\"Args\":[]}'" >/dev/null 2>&1; then
        log "✅ Basic chaincode functionality verified"
    else
        log "❌ Basic chaincode functionality test failed"
        return 1
    fi
    
    # Check available resources
    log "Checking system resources..."
    ssh fabricadmin@10.104.0.2 "free -h | grep Mem" | tee -a "$LOG_FILE"
    ssh fabricadmin@10.104.0.3 "free -h | grep Mem" | tee -a "$LOG_FILE"
    ssh fabricadmin@10.104.0.4 "free -h | grep Mem" | tee -a "$LOG_FILE"
    
    return 0
}

# Run Hyperledger Caliper performance tests
run_caliper_tests() {
    print_section "Hyperledger Caliper Performance Testing"
    
    if [ ! -d "$CALIPER_DIR" ]; then
        log "❌ Caliper test directory not found: $CALIPER_DIR"
        return 1
    fi
    
    log "Starting Hyperledger Caliper performance tests..."
    log "Target: 10-50 TPS for zakat operations"
    
    cd "$CALIPER_DIR"
    
    # Check if Caliper is installed
    if ! command -v npx >/dev/null 2>&1; then
        log "Installing Node.js and Caliper dependencies..."
        # Note: In production, this should be pre-installed
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        npm install --only=prod @hyperledger/caliper-cli@0.5.0
    fi
    
    # Run Caliper benchmark
    log "Executing Caliper benchmark with 4 test rounds..."
    
    if npx caliper launch manager --caliper-workspace ./ --caliper-networkconfig caliper-config.yaml --caliper-benchconfig caliper-config.yaml --caliper-flow-only-test 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Caliper performance tests completed successfully"
        
        # Check if report was generated
        if [ -f "report.html" ]; then
            log "📊 Performance report generated: $CALIPER_DIR/report.html"
        fi
        
        return 0
    else
        log "❌ Caliper performance tests failed"
        return 1
    fi
}

# Run functional test suite
run_functional_tests() {
    print_section "Comprehensive Functional Test Suite"
    
    if [ ! -f "$FUNCTIONAL_DIR/functional-test-suite.sh" ]; then
        log "❌ Functional test suite not found: $FUNCTIONAL_DIR/functional-test-suite.sh"
        return 1
    fi
    
    log "Starting comprehensive functional test suite..."
    log "Testing all 17 chaincode functions with mock data"
    
    cd "$FUNCTIONAL_DIR"
    
    if ./functional-test-suite.sh 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Functional test suite completed successfully"
        return 0
    else
        log "❌ Functional test suite failed"
        return 1
    fi
}

# Run integration workflow tests
run_integration_tests() {
    print_section "Integration Workflow Testing"
    
    if [ ! -f "$FUNCTIONAL_DIR/integration-workflow-test.sh" ]; then
        log "❌ Integration workflow test not found: $FUNCTIONAL_DIR/integration-workflow-test.sh"
        return 1
    fi
    
    log "Starting end-to-end integration workflow test..."
    log "Simulating complete zakat business process"
    
    cd "$FUNCTIONAL_DIR"
    
    if ./integration-workflow-test.sh 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Integration workflow test completed successfully"
        return 0
    else
        log "❌ Integration workflow test failed"
        return 1
    fi
}

# Run stress tests
run_stress_tests() {
    print_section "Network Resilience & Stress Testing"
    
    if [ ! -d "$STRESS_DIR" ]; then
        log "❌ Stress test directory not found: $STRESS_DIR"
        return 1
    fi
    
    cd "$STRESS_DIR"
    
    local stress_results=0
    
    # Network resilience tests
    if [ -f "network-resilience-test.sh" ]; then
        log "Starting network resilience tests..."
        if ./network-resilience-test.sh 2>&1 | tee -a "$LOG_FILE"; then
            log "✅ Network resilience tests passed"
        else
            log "❌ Network resilience tests failed"
            stress_results=1
        fi
    else
        log "⚠️  Network resilience test not found, skipping..."
    fi
    
    # High volume stress tests
    if [ -f "high-volume-stress-test.sh" ]; then
        log "Starting high volume stress tests..."
        if ./high-volume-stress-test.sh 2>&1 | tee -a "$LOG_FILE"; then
            log "✅ High volume stress tests passed"
        else
            log "❌ High volume stress tests failed"
            stress_results=1
        fi
    else
        log "⚠️  High volume stress test not found, skipping..."
    fi
    
    return $stress_results
}

# Post-test network health check
post_test_health_check() {
    log "Performing post-test network health check..."
    
    # Verify all containers are still running
    local failed_components=0
    
    if ! ssh fabricadmin@10.104.0.3 "docker ps --filter name=orderer --format '{{.Status}}'" | grep -q "Up"; then
        log "⚠️  Orderer may have issues after testing"
        failed_components=$((failed_components + 1))
    fi
    
    if ! ssh fabricadmin@10.104.0.2 "docker ps --filter name=peer --format '{{.Status}}'" | grep -q "Up"; then
        log "⚠️  Org1 peer may have issues after testing"
        failed_components=$((failed_components + 1))
    fi
    
    if ! ssh fabricadmin@10.104.0.4 "docker ps --filter name=peer --format '{{.Status}}'" | grep -q "Up"; then
        log "⚠️  Org2 peer may have issues after testing"
        failed_components=$((failed_components + 1))
    fi
    
    # Test basic functionality
    if ssh fabricadmin@10.104.0.2 "docker exec cli.org1.fabriczakat.local peer chaincode query -C zakatchannel -n zakat -c '{\"function\":\"GetAllPrograms\",\"Args\":[]}'" >/dev/null 2>&1; then
        log "✅ Post-test chaincode functionality verified"
    else
        log "⚠️  Post-test chaincode functionality may be impaired"
        failed_components=$((failed_components + 1))
    fi
    
    if [ $failed_components -eq 0 ]; then
        log "✅ Post-test network health check passed"
        return 0
    else
        log "⚠️  Post-test health check detected $failed_components issue(s)"
        return 1
    fi
}

# Generate comprehensive test report
generate_test_report() {
    local start_time="$1"
    local end_time="$2"
    local total_tests="$3"
    local passed_tests="$4"
    
    local duration=$((end_time - start_time))
    local success_rate=$(echo "scale=1; $passed_tests * 100 / $total_tests" | bc -l)
    
    local report_file="$LOG_DIR/performance-test-summary-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "test_execution_summary": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_seconds": $duration,
    "total_test_suites": $total_tests,
    "passed_test_suites": $passed_tests,
    "failed_test_suites": $((total_tests - passed_tests)),
    "success_rate": "${success_rate}%"
  },
  "test_suites": {
    "caliper_performance": {
      "description": "Hyperledger Caliper TPS benchmarking",
      "target": "10-50 TPS for zakat operations",
      "status": "$caliper_status"
    },
    "functional_tests": {
      "description": "20-test comprehensive functional suite",
      "coverage": "17/17 chaincode functions",
      "status": "$functional_status"
    },
    "integration_workflow": {
      "description": "End-to-end business process simulation",
      "workflow": "16-step complete zakat lifecycle",
      "status": "$integration_status"
    },
    "stress_tests": {
      "description": "Network resilience and high-volume testing",
      "scenarios": "Peer failures, load spikes, recovery",
      "status": "$stress_status"
    }
  },
  "network_configuration": {
    "channel": "zakatchannel",
    "chaincode": "zakat v2.0",
    "organizations": ["Org1MSP (YDSF Malang)", "Org2MSP (YDSF Jatim)"],
    "nodes": ["10.104.0.2", "10.104.0.3", "10.104.0.4"]
  },
  "recommendations": {
    "production_readiness": "$production_readiness",
    "performance_status": "$performance_assessment",
    "next_steps": "Review individual test suite logs for detailed analysis"
  }
}
EOF
    
    log "📋 Comprehensive test report generated: $report_file"
}

# Main execution function
main() {
    local start_time=$(date +%s)
    
    print_header "AUTOMATED PERFORMANCE TESTING EXECUTION - SCRIPT 28"
    
    log "Starting automated performance testing for zakat network"
    log "Execution timestamp: $(date)"
    log "Log file: $LOG_FILE"
    
    # Test tracking variables
    local total_test_suites=4
    local passed_test_suites=0
    
    # Test status variables for report
    caliper_status="FAILED"
    functional_status="FAILED"
    integration_status="FAILED"
    stress_status="FAILED"
    
    # Verify prerequisites
    if ! verify_network_status; then
        log "❌ Network verification failed. Cannot proceed with testing."
        exit 1
    fi
    
    if ! pre_test_health_check; then
        log "❌ Pre-test health check failed. Cannot proceed with testing."
        exit 1
    fi
    
    # Execute test suites
    log "🚀 Beginning comprehensive performance testing..."
    
    # Caliper Performance Tests
    if run_caliper_tests; then
        passed_test_suites=$((passed_test_suites + 1))
        caliper_status="PASSED"
    fi
    
    # Functional Test Suite
    if run_functional_tests; then
        passed_test_suites=$((passed_test_suites + 1))
        functional_status="PASSED"
    fi
    
    # Integration Workflow Tests
    if run_integration_tests; then
        passed_test_suites=$((passed_test_suites + 1))
        integration_status="PASSED"
    fi
    
    # Stress Tests
    if run_stress_tests; then
        passed_test_suites=$((passed_test_suites + 1))
        stress_status="PASSED"
    fi
    
    # Post-test verification
    post_test_health_check
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Determine production readiness
    if [ $passed_test_suites -eq $total_test_suites ]; then
        production_readiness="READY"
        performance_assessment="EXCELLENT"
    elif [ $passed_test_suites -ge 3 ]; then
        production_readiness="MOSTLY_READY"
        performance_assessment="GOOD"
    elif [ $passed_test_suites -ge 2 ]; then
        production_readiness="NEEDS_IMPROVEMENT"
        performance_assessment="ACCEPTABLE"
    else
        production_readiness="NOT_READY"
        performance_assessment="POOR"
    fi
    
    # Generate comprehensive report
    generate_test_report "$start_time" "$end_time" "$total_test_suites" "$passed_test_suites"
    
    # Final results
    print_header "PERFORMANCE TESTING EXECUTION COMPLETE"
    
    log "📊 Test Execution Summary:"
    log "   Total Duration: ${total_duration} seconds ($(echo "scale=1; $total_duration / 60" | bc -l) minutes)"
    log "   Test Suites Passed: $passed_test_suites/$total_test_suites"
    log "   Success Rate: $(echo "scale=1; $passed_test_suites * 100 / $total_test_suites" | bc -l)%"
    log ""
    log "📋 Individual Test Results:"
    log "   Caliper Performance: $caliper_status"
    log "   Functional Tests: $functional_status"
    log "   Integration Workflow: $integration_status"
    log "   Stress Tests: $stress_status"
    log ""
    log "🎯 Production Readiness Assessment: $production_readiness"
    log "⚡ Performance Assessment: $performance_assessment"
    
    # Archive results
    local archive_dir="$LOG_DIR/performance-test-archive"
    mkdir -p "$archive_dir"
    
    # Copy all test results to archive
    if [ -d "$CALIPER_DIR" ]; then
        cp -r "$CALIPER_DIR/reports" "$archive_dir/caliper-reports-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    fi
    
    if [ -d "$FUNCTIONAL_DIR/results" ]; then
        cp -r "$FUNCTIONAL_DIR/results" "$archive_dir/functional-results-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    fi
    
    if [ -d "$STRESS_DIR/results" ]; then
        cp -r "$STRESS_DIR/results" "$archive_dir/stress-results-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    fi
    
    log "📁 Test results archived to: $archive_dir"
    
    # Exit with appropriate code
    if [ $passed_test_suites -eq $total_test_suites ]; then
        echo -e "${GREEN}🎉 ALL PERFORMANCE TESTS PASSED!${NC}" | tee -a "$LOG_FILE"
        echo -e "${GREEN}✅ Zakat network is production-ready${NC}" | tee -a "$LOG_FILE"
        exit 0
    elif [ $passed_test_suites -ge 2 ]; then
        echo -e "${YELLOW}⚠️  PARTIAL SUCCESS - SOME TESTS FAILED${NC}" | tee -a "$LOG_FILE"
        echo -e "${YELLOW}📋 Review failed test logs for improvement areas${NC}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "${RED}❌ PERFORMANCE TESTING FAILED${NC}" | tee -a "$LOG_FILE"
        echo -e "${RED}🔧 Significant issues detected - network needs attention${NC}" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"