#!/bin/bash
# Test script to figure out correct JSON escaping for multi-layer shell execution
# This will test different escaping patterns to find what works

# Don't exit on errors during tests - we want to test all patterns
set +e

# Configuration
CHANNEL_NAME="zakatchannel"
CC_NAME="zakat"
ORG1_IP="10.104.0.2"
ORG1_CLI_CONTAINER="cli.org1.fabriczakat.local"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test results tracking
declare -a successful_patterns=()
declare -a failed_patterns=()
test_count=0
success_count=0

# Log file
LOG_FILE="$HOME/fabric/logs/json-escaping-test.log"
mkdir -p "$(dirname "$LOG_FILE")"
> "$LOG_FILE" # Clear previous log

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ $test_count -eq 0 ]; then
        echo -e "\n${RED}Script failed before running any tests. Check log: $LOG_FILE${NC}"
    fi
}
trap cleanup EXIT

echo -e "${BOLD}${BLUE}=== JSON Escaping Test Script ===${NC}\n"
log "Starting JSON escaping test script"

# Function to test a command pattern with enhanced error handling
test_pattern() {
    local pattern_name="$1"
    local cmd="$2"
    local timeout=${3:-30}
    
    test_count=$((test_count + 1))
    
    echo -e "${BOLD}${YELLOW}Testing Pattern $test_count: $pattern_name${NC}"
    echo -e "Command: ${BLUE}$cmd${NC}\n"
    log "Testing Pattern $test_count: $pattern_name"
    log "Command: $cmd"
    
    # Build the full remote command
    local full_remote_cmd="docker exec $ORG1_CLI_CONTAINER bash -c '$cmd'"
    echo -e "Full remote command:"
    echo -e "${BLUE}$full_remote_cmd${NC}\n"
    log "Full remote command: $full_remote_cmd"
    
    # Test SSH connectivity first
    if ! ssh -o ConnectTimeout=5 fabricadmin@$ORG1_IP "echo 'SSH test'" >/dev/null 2>&1; then
        echo -e "${RED}❌ FAILED - SSH connectivity issue${NC}"
        echo -e "Cannot connect to $ORG1_IP\n"
        log "FAILED - SSH connectivity issue to $ORG1_IP"
        failed_patterns+=("$pattern_name (SSH failure)")
        return 1
    fi
    
    # Test container existence
    if ! ssh fabricadmin@$ORG1_IP "docker ps --filter name=^/${ORG1_CLI_CONTAINER}\$ --format '{{.Names}}'" 2>/dev/null | grep -q "$ORG1_CLI_CONTAINER"; then
        echo -e "${RED}❌ FAILED - Container not found${NC}"
        echo -e "Container $ORG1_CLI_CONTAINER not running on $ORG1_IP\n"
        log "FAILED - Container $ORG1_CLI_CONTAINER not found on $ORG1_IP"
        failed_patterns+=("$pattern_name (Container not found)")
        return 1
    fi
    
    # Run the actual command with timeout
    local result
    local exit_code
    if result=$(timeout $timeout ssh fabricadmin@$ORG1_IP "$full_remote_cmd" 2>&1); then
        exit_code=$?
    else
        exit_code=$?
    fi
    
    # Check for timeout
    if [ $exit_code -eq 124 ]; then
        echo -e "${RED}❌ FAILED - Command timed out after $timeout seconds${NC}"
        echo -e "Command may be hanging\n"
        log "FAILED - Command timed out after $timeout seconds"
        failed_patterns+=("$pattern_name (Timeout)")
        return 124
    fi
    
    # Analyze the result - schema mismatch error means JSON was parsed successfully
    if [ $exit_code -eq 0 ] && echo "$result" | grep -q -v "Error:"; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
        echo -e "Exit Code: $exit_code"
        echo -e "Output Preview: $(echo "$result" | head -3 | tr '\n' ' ')..."
        echo -e "Full Output logged to: $LOG_FILE\n"
        log "SUCCESS - Exit code: $exit_code"
        log "Output: $result"
        successful_patterns+=("$pattern_name")
        success_count=$((success_count + 1))
        return 0
    elif echo "$result" | grep -q "Error handling success response. Value did not match schema"; then
        echo -e "${GREEN}✅ JSON SUCCESS (Schema Issue)${NC}"
        echo -e "Exit Code: $exit_code"
        echo -e "JSON was parsed correctly, but chaincode returned schema validation error (old data format)"
        echo -e "This is expected behavior and the JSON escaping is working properly\n"
        log "JSON SUCCESS - Schema validation error detected (expected for old data)"
        log "Output: $result"
        successful_patterns+=("$pattern_name (JSON parsed successfully)")
        success_count=$((success_count + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        echo -e "Exit Code: $exit_code"
        if echo "$result" | grep -q "Error:"; then
            echo -e "Error detected in output:"
            echo "$result" | grep "Error:" | head -2
        else
            echo -e "Output Preview: $(echo "$result" | head -2 | tr '\n' ' ')..."
        fi
        echo -e "Full output logged to: $LOG_FILE\n"
        log "FAILED - Exit code: $exit_code"
        log "Output: $result"
        failed_patterns+=("$pattern_name")
        return 1
    fi
}

# Verify network connectivity before starting tests
echo -e "${YELLOW}Verifying test environment...${NC}"
log "Verifying test environment"

if ! ssh -o ConnectTimeout=10 fabricadmin@$ORG1_IP "echo 'Initial connectivity test'" >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to $ORG1_IP via SSH${NC}"
    echo -e "Please check network connectivity and SSH access."
    log "FATAL - Cannot connect to $ORG1_IP via SSH"
    exit 1
fi

if ! ssh fabricadmin@$ORG1_IP "docker ps --filter name=^/${ORG1_CLI_CONTAINER}\$ --format '{{.Names}}'" 2>/dev/null | grep -q "$ORG1_CLI_CONTAINER"; then
    echo -e "${RED}❌ Container $ORG1_CLI_CONTAINER not found or not running on $ORG1_IP${NC}"
    echo -e "Available containers:"
    ssh fabricadmin@$ORG1_IP "docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>/dev/null || echo "Failed to list containers"
    log "FATAL - Container $ORG1_CLI_CONTAINER not found on $ORG1_IP"
    exit 1
fi

echo -e "${GREEN}✅ Environment verified${NC}"
echo -e "${BLUE}Testing different JSON escaping patterns for peer chaincode query...${NC}\n"
log "Environment verified, starting tests"

# Test Pattern 1: Double quotes with escaping (current failing approach)
test_pattern "Double quotes with backslash escaping" \
    'peer chaincode query -C zakatchannel -n zakat -c "{\"function\":\"GetAllZakat\",\"Args\":[]}"'

echo -e "---\n"

# Test Pattern 2: Single quotes around JSON with escaped quotes
test_pattern "Single quotes with escaped JSON quotes" \
    "peer chaincode query -C zakatchannel -n zakat -c '{\"function\":\"GetAllZakat\",\"Args\":[]}'"

echo -e "---\n"

# Test Pattern 3: Single quotes with clean JSON (most promising)
test_pattern "Single quotes with clean JSON" \
    'peer chaincode query -C zakatchannel -n zakat -c '\''{"function":"GetAllZakat","Args":[]}'\'''

echo -e "---\n"

# Test Pattern 4: Variable assignment approach
echo -e "${YELLOW}Setting up Pattern 4: Variable assignment...${NC}"
JSON_QUERY='{"function":"GetAllZakat","Args":[]}'
test_pattern "Variable assignment approach" \
    "peer chaincode query -C zakatchannel -n zakat -c '$JSON_QUERY'"

echo -e "---\n"

# Test Pattern 5: Triple escaping (current demo script approach)
test_pattern "Triple escaping (current failing approach)" \
    'peer chaincode query -C zakatchannel -n zakat -c "{\\\"function\\\":\\\"GetAllZakat\\\",\\\"Args\\\":[]}"'

echo -e "---\n"

# Test Pattern 6: Alternative single quote approach
test_pattern "Alternative single quote with double quotes" \
    'peer chaincode query -C zakatchannel -n zakat -c '"'"'{"function":"GetAllZakat","Args":[]}'"'"''

# Generate test summary
echo -e "\n${BOLD}${BLUE}=== TEST SUMMARY ===${NC}\n"
log "Test Summary - Total: $test_count, Success: $success_count, Failed: $((test_count - success_count))"

echo -e "${BOLD}Tests Run: $test_count${NC}"
echo -e "${BOLD}Successful: $success_count${NC}"
echo -e "${BOLD}Failed: $((test_count - success_count))${NC}\n"

if [ ${#successful_patterns[@]} -gt 0 ]; then
    echo -e "${BOLD}${GREEN}✅ SUCCESSFUL PATTERNS:${NC}"
    for i in "${!successful_patterns[@]}"; do
        echo -e "  $((i+1)). ${successful_patterns[i]}"
        log "Successful pattern: ${successful_patterns[i]}"
    done
    echo -e "\n${BOLD}${GREEN}RECOMMENDATION: Use the first successful pattern in your demo script.${NC}"
    echo -e "${GREEN}These patterns will work for fixing the JSON escaping issue.${NC}\n"
else
    echo -e "${BOLD}${RED}❌ NO SUCCESSFUL PATTERNS FOUND${NC}"
    echo -e "${RED}All test patterns failed. Check the log file for detailed errors: $LOG_FILE${NC}"
    log "ERROR - No successful patterns found"
fi

if [ ${#failed_patterns[@]} -gt 0 ]; then
    echo -e "${BOLD}${RED}❌ FAILED PATTERNS:${NC}"
    for i in "${!failed_patterns[@]}"; do
        echo -e "  $((i+1)). ${failed_patterns[i]}"
        log "Failed pattern: ${failed_patterns[i]}"
    done
    echo ""
fi

echo -e "${BLUE}Full test log available at: $LOG_FILE${NC}"
echo -e "${BLUE}Use the successful pattern(s) to fix the demo script.${NC}"

log "Test script completed"
