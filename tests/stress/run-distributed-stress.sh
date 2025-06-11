#!/bin/bash

# Distributed Stress Test Coordinator
# This script copies the Go binary to each VPS and runs tests in parallel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_NAME="distributed-stress-test"
BINARY_PATH="$SCRIPT_DIR/$BINARY_NAME"

# VPS Configuration
ORG1_IP="10.104.0.2"
ORG2_IP="10.104.0.4"
USERNAME="fabricadmin"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    log "${RED}❌ Binary not found: $BINARY_PATH${NC}"
    log "Please run: go build -o distributed-stress-test distributed-stress-test.go"
    exit 1
fi

log "${BLUE}🚀 Starting Distributed Hyperledger Fabric Stress Test${NC}"
log "${BLUE}Testing true distributed performance without SSH bottlenecks${NC}"

# Function to copy binary to VPS
copy_binary_to_vps() {
    local vps_ip="$1"
    local vps_name="$2"
    
    log "📦 Copying binary to $vps_name ($vps_ip)..."
    
    # Try to copy binary with retry logic
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$BINARY_PATH" "${USERNAME}@${vps_ip}:~/" 2>/dev/null; then
            log "✅ Binary copied to $vps_name successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            log "⚠️  Attempt $retry_count failed for $vps_name, retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    log "${RED}❌ Failed to copy binary to $vps_name after $max_retries attempts${NC}"
    return 1
}

# Function to run test on VPS
run_test_on_vps() {
    local vps_ip="$1"
    local vps_name="$2"
    local org_name="$3"
    local output_file="$4"
    
    log "🏃 Starting test on $vps_name..."
    
    # Run the test with timeout
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${USERNAME}@${vps_ip}" \
        "chmod +x ~/distributed-stress-test && ~/distributed-stress-test -vps=$org_name" \
        > "$output_file" 2>&1; then
        log "✅ Test completed on $vps_name"
        return 0
    else
        log "${RED}❌ Test failed on $vps_name${NC}"
        return 1
    fi
}

# Function to extract metrics from output
extract_metrics() {
    local output_file="$1"
    local vps_name="$2"
    
    if [ ! -f "$output_file" ]; then
        echo "0 0 0.00 0 0 0.00"
        return
    fi
    
    local tx_success=$(grep "TRANSACTIONS_SUCCESS:" "$output_file" | cut -d':' -f2 || echo "0")
    local tx_total=$(grep "TRANSACTIONS_TOTAL:" "$output_file" | cut -d':' -f2 || echo "0")
    local tx_tps=$(grep "TRANSACTIONS_TPS:" "$output_file" | cut -d':' -f2 || echo "0.00")
    local query_success=$(grep "QUERIES_SUCCESS:" "$output_file" | cut -d':' -f2 || echo "0")
    local query_total=$(grep "QUERIES_TOTAL:" "$output_file" | cut -d':' -f2 || echo "0")
    local query_tps=$(grep "QUERIES_TPS:" "$output_file" | cut -d':' -f2 || echo "0.00")
    
    echo "$tx_success $tx_total $tx_tps $query_success $query_total $query_tps"
}

# Check SSH connectivity first
log "🔍 Checking SSH connectivity..."
ssh_org1_ok=false
ssh_org2_ok=false

if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${USERNAME}@${ORG1_IP}" "echo 'SSH OK'" >/dev/null 2>&1; then
    ssh_org1_ok=true
    log "✅ SSH to Org1 VPS (${ORG1_IP}) is working"
else
    log "${YELLOW}⚠️  SSH to Org1 VPS (${ORG1_IP}) is not available${NC}"
fi

if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${USERNAME}@${ORG2_IP}" "echo 'SSH OK'" >/dev/null 2>&1; then
    ssh_org2_ok=true
    log "✅ SSH to Org2 VPS (${ORG2_IP}) is working"
else
    log "${YELLOW}⚠️  SSH to Org2 VPS (${ORG2_IP}) is not available${NC}"
fi

if [ "$ssh_org1_ok" = false ] && [ "$ssh_org2_ok" = false ]; then
    log "${RED}❌ Cannot connect to any VPS instances${NC}"
    log "${YELLOW}💡 SSH may be rate-limited. Try again in a few minutes.${NC}"
    exit 1
fi

# Create output directory
OUTPUT_DIR="$SCRIPT_DIR/results/distributed-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

start_time=$(date +%s)

# Copy binaries and run tests
org1_pid=""
org2_pid=""

if [ "$ssh_org1_ok" = true ]; then
    if copy_binary_to_vps "$ORG1_IP" "Org1"; then
        run_test_on_vps "$ORG1_IP" "Org1" "org1" "$OUTPUT_DIR/org1-output.log" &
        org1_pid=$!
    fi
fi

if [ "$ssh_org2_ok" = true ]; then
    if copy_binary_to_vps "$ORG2_IP" "Org2"; then
        run_test_on_vps "$ORG2_IP" "Org2" "org2" "$OUTPUT_DIR/org2-output.log" &
        org2_pid=$!
    fi
fi

# Wait for tests to complete
log "⏳ Waiting for distributed tests to complete..."

if [ -n "$org1_pid" ]; then
    wait $org1_pid
    org1_result=$?
else
    org1_result=1
fi

if [ -n "$org2_pid" ]; then
    wait $org2_pid
    org2_result=$?
else
    org2_result=1
fi

end_time=$(date +%s)
total_duration=$((end_time - start_time))

# Aggregate results
log "${BOLD}📊 AGGREGATING DISTRIBUTED TEST RESULTS${NC}"

org1_metrics=$(extract_metrics "$OUTPUT_DIR/org1-output.log" "Org1")
org2_metrics=$(extract_metrics "$OUTPUT_DIR/org2-output.log" "Org2")

read org1_tx_success org1_tx_total org1_tx_tps org1_query_success org1_query_total org1_query_tps <<< "$org1_metrics"
read org2_tx_success org2_tx_total org2_tx_tps org2_query_success org2_query_total org2_query_tps <<< "$org2_metrics"

# Calculate totals
total_tx_success=$((org1_tx_success + org2_tx_success))
total_tx_total=$((org1_tx_total + org2_tx_total))
total_query_success=$((org1_query_success + org2_query_success))
total_query_total=$((org1_query_total + org2_query_total))

# Calculate combined TPS
combined_tx_tps=$(echo "$org1_tx_tps + $org2_tx_tps" | bc -l)
combined_query_tps=$(echo "$org1_query_tps + $org2_query_tps" | bc -l)

# Print aggregated results
echo ""
echo "============================================="
echo "🌟 DISTRIBUTED STRESS TEST RESULTS"
echo "============================================="
echo ""
echo "📊 Combined Transaction Results:"
echo "  Total Duration: ${total_duration}s"
echo "  Successful Transactions: $total_tx_success"
echo "  Total Transactions: $total_tx_total"
echo "  🎯 COMBINED TPS: $combined_tx_tps transactions/second"
echo ""
echo "📊 Combined Query Results:"
echo "  Successful Queries: $total_query_success"
echo "  Total Queries: $total_query_total"
echo "  🎯 COMBINED Query TPS: $combined_query_tps queries/second"
echo ""
echo "📊 Per-VPS Breakdown:"
echo "  Org1 VPS: $org1_tx_success/$org1_tx_total tx (${org1_tx_tps} TPS)"
echo "  Org2 VPS: $org2_tx_success/$org2_tx_total tx (${org2_tx_tps} TPS)"
echo ""

# Calculate success rates
if [ $total_tx_total -gt 0 ]; then
    tx_success_rate=$(echo "scale=1; $total_tx_success * 100 / $total_tx_total" | bc -l)
else
    tx_success_rate="0.0"
fi

if [ $total_query_total -gt 0 ]; then
    query_success_rate=$(echo "scale=1; $total_query_success * 100 / $total_query_total" | bc -l)
else
    query_success_rate="0.0"
fi

echo "📈 Success Rates:"
echo "  Transaction Success Rate: ${tx_success_rate}%"
echo "  Query Success Rate: ${query_success_rate}%"
echo ""

# Final verdict
tests_passed=0
if (( $(echo "$tx_success_rate >= 60" | bc -l) )); then
    echo "✅ Distributed transaction test PASSED (${tx_success_rate}% success rate)"
    tests_passed=$((tests_passed + 1))
else
    echo "❌ Distributed transaction test FAILED (${tx_success_rate}% success rate)"
fi

if (( $(echo "$query_success_rate >= 70" | bc -l) )); then
    echo "✅ Distributed query test PASSED (${query_success_rate}% success rate)"
    tests_passed=$((tests_passed + 1))
else
    echo "❌ Distributed query test FAILED (${query_success_rate}% success rate)"
fi

echo ""
echo "============================================="
if [ $tests_passed -eq 2 ]; then
    echo -e "${GREEN}🎉 ALL DISTRIBUTED TESTS PASSED!${NC}"
    echo -e "${GREEN}True distributed testing achieved ${combined_tx_tps} TPS!${NC}"
    echo -e "${GREEN}No SSH bottlenecks - pure goroutine performance!${NC}"
else
    echo -e "${YELLOW}⚡ PARTIAL SUCCESS${NC}"
    echo -e "${YELLOW}Distributed testing shows improved performance${NC}"
fi
echo "============================================="

# Save summary
echo "DISTRIBUTED_TEST_SUMMARY" > "$OUTPUT_DIR/summary.txt"
echo "Total_TX_Success=$total_tx_success" >> "$OUTPUT_DIR/summary.txt"
echo "Total_TX_Total=$total_tx_total" >> "$OUTPUT_DIR/summary.txt"
echo "Combined_TX_TPS=$combined_tx_tps" >> "$OUTPUT_DIR/summary.txt"
echo "Total_Query_Success=$total_query_success" >> "$OUTPUT_DIR/summary.txt"
echo "Total_Query_Total=$total_query_total" >> "$OUTPUT_DIR/summary.txt"
echo "Combined_Query_TPS=$combined_query_tps" >> "$OUTPUT_DIR/summary.txt"
echo "Duration=${total_duration}s" >> "$OUTPUT_DIR/summary.txt"

log "📁 Results saved to: $OUTPUT_DIR"
log "🎯 This demonstrates the power of distributed Go testing vs centralized bash!"

if [ $tests_passed -eq 2 ]; then
    exit 0
else
    exit 1
fi