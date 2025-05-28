#!/bin/bash
# Script 27: Zakat Chaincode Demo (Adapted for Multi-Host CLI Execution)
# This script demonstrates the Zakat chaincode functionality via SSH into CLI containers.

set -e # Exit on error
# set -x # Enable detailed command tracing (Removed for cleaner output)

# --- Configuration ---
CHANNEL_NAME="zakatchannel"
CC_NAME="zakat"
CC_VERSION="1.0" # Used for logging consistency
SEQUENCE="1"     # Used for logging consistency

# Org Details
ORG1_NAME="Org1"
ORG1_DOMAIN="org1.fabriczakat.local"
ORG1_IP="10.104.0.2"
ORG1_MSP="Org1MSP"
ORG1_CLI_CONTAINER="cli.${ORG1_DOMAIN}"
ORG1_PEER_CONTAINER="peer.${ORG1_DOMAIN}"

ORG2_NAME="Org2"
ORG2_DOMAIN="org2.fabriczakat.local"
ORG2_IP="10.104.0.4"
ORG2_MSP="Org2MSP"
ORG2_CLI_CONTAINER="cli.${ORG2_DOMAIN}"
ORG2_PEER_CONTAINER="peer.${ORG2_DOMAIN}"

# Orderer Details
ORDERER_IP="10.104.0.3"
ORDERER_DOMAIN="fabriczakat.local"
ORDERER_CONTAINER="orderer.fabriczakat.local"
ORDERER_ADDRESS="orderer.fabriczakat.local:7050"
# Path inside CLI container
ORDERER_CA_CERT_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"

# Peer Details for Endorsement (as seen from CLI containers)
# Paths inside CLI container
PEER_ADDRESS_ORG1="peer.${ORG1_DOMAIN}:7051"
PEER_TLS_ROOTCERT_ORG1_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG1_DOMAIN}/peers/peer.${ORG1_DOMAIN}/tls/ca.crt"
PEER_ADDRESS_ORG2="peer.${ORG2_DOMAIN}:7051"
PEER_TLS_ROOTCERT_ORG2_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${ORG2_DOMAIN}/peers/peer.${ORG2_DOMAIN}/tls/ca.crt"

# Log file on the Orderer machine
LOG_DIR="$HOME/fabric/logs"
LOG_FILE="$LOG_DIR/27-zakat-demo.log"
mkdir -p $LOG_DIR
> $LOG_FILE # Clear previous log

# --- Formatting & Helpers ---

# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'
UNDERLINE='\033[4m'

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Function to display section header
print_header() {
  local title=$1
  local width=80
  local line=$(printf '%*s' "$width" | tr ' ' '=')
  echo -e "\n${BOLD}${line}${NC}" | tee -a $LOG_FILE
  echo -e "${BOLD}${BLUE}   $title${NC}" | tee -a $LOG_FILE
  echo -e "${BOLD}${line}${NC}\n" | tee -a $LOG_FILE
}

# Function to check if a container is running on local or remote host
check_container() {
    local host=$1
    local container=$2
    # Escape dots in container name for grep
    local escaped_container=$(echo "$container" | sed 's/\./\\./g')
    local status

    # Check if this is a local check (current host)
    if [ "$host" = "10.104.0.3" ] || [ "$host" = "localhost" ] || [ "$host" = "127.0.0.1" ]; then
        # Local check
        status=$(docker ps --filter name=^/${escaped_container}\$ --format '{{.Status}}' | grep -v '^$')
        if [ -n "$status" ]; then
            log "Container $container status (local): $status"
            return 0
        else
            log "Container $container not found or not running (local)"
            log "Current containers (local):"
            docker ps --format 'table {{.Names}}\t{{.Status}}' >> $LOG_FILE
            return 1
        fi
    else
        # Remote check
        status=$(ssh fabricadmin@$host "docker ps --filter name=^/${escaped_container}\$ --format '{{.Status}}'" 2>/dev/null | grep -v '^$')
        if [ -n "$status" ]; then
            log "Container $container status (on $host): $status"
            return 0
        else
            log "Container $container not found or not running on $host"
            log "Current containers on $host:"
            ssh fabricadmin@$host "docker ps --format 'table {{.Names}}\t{{.Status}}'" >> $LOG_FILE
            return 1
        fi
    fi
}

# Function to wait for container readiness
wait_for_container() {
    local host=$1
    local container=$2
    local max_retries=30
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if check_container "$host" "$container"; then
            return 0
        fi
        retry=$((retry+1))
        sleep 2
    done
    return 1
}

# Function to verify network components are running
verify_network() {
    log "Verifying network components..."

    # Check Orderer
    log "Checking orderer container on $ORDERER_IP..."
    if ! check_container "$ORDERER_IP" "$ORDERER_CONTAINER"; then
        log "⛔ Error: Orderer container '$ORDERER_CONTAINER' not running on $ORDERER_IP"
        log "Container status:"
        ssh fabricadmin@$ORDERER_IP "docker ps -a --filter name=$ORDERER_CONTAINER" >> $LOG_FILE
        exit 1
    fi
    log "✅ Orderer is running"

    # Check Org1 Peer and CLI
    log "Checking Org1 containers on $ORG1_IP..."
    if ! check_container "$ORG1_IP" "$ORG1_PEER_CONTAINER"; then
        log "⛔ Error: Org1 peer container '$ORG1_PEER_CONTAINER' not running on $ORG1_IP"
        log "Container status:"
        ssh fabricadmin@$ORG1_IP "docker ps -a --filter name=$ORG1_PEER_CONTAINER" >> $LOG_FILE
        exit 1
    fi
    if ! check_container "$ORG1_IP" "$ORG1_CLI_CONTAINER"; then
        log "⛔ Error: Org1 CLI container '$ORG1_CLI_CONTAINER' not running on $ORG1_IP"
        log "Container status:"
        ssh fabricadmin@$ORG1_IP "docker ps -a --filter name=$ORG1_CLI_CONTAINER" >> $LOG_FILE
        exit 1
    fi
    log "✅ Org1 peer and CLI are running"

    # Check Org2 Peer and CLI
    log "Checking Org2 containers on $ORG2_IP..."
    if ! check_container "$ORG2_IP" "$ORG2_PEER_CONTAINER"; then
        log "⛔ Error: Org2 peer container '$ORG2_PEER_CONTAINER' not running on $ORG2_IP"
        log "Container status:"
        ssh fabricadmin@$ORG2_IP "docker ps -a --filter name=$ORG2_PEER_CONTAINER" >> $LOG_FILE
        exit 1
    fi
    if ! check_container "$ORG2_IP" "$ORG2_CLI_CONTAINER"; then
        log "⛔ Error: Org2 CLI container '$ORG2_CLI_CONTAINER' not running on $ORG2_IP"
        log "Container status:"
        ssh fabricadmin@$ORG2_IP "docker ps -a --filter name=$ORG2_CLI_CONTAINER" >> $LOG_FILE
        exit 1
    fi
    log "✅ Org2 peer and CLI are running"

    log "✅ All network components verified"
}

# Function to run a peer command via SSH + docker exec with timeout
# Arguments: $1=Org IP, $2=CLI Container Name, $3=Peer Command String, $4=Timeout (optional), $5=AllowError (optional)
run_peer_command() {
    local org_ip=$1
    local cli_container=$2
    local peer_cmd=$3
    local timeout=${4:-60} # Default timeout 60 seconds
    local allow_error=${5:-false} # Default to exit on error
    local full_remote_cmd="docker exec $cli_container bash -c \"$peer_cmd\""

    log "Executing on $org_ip: $full_remote_cmd"

    # Use timeout command to prevent hanging
    local output
    output=$(timeout $timeout ssh "fabricadmin@$org_ip" "$full_remote_cmd" 2>&1)
    local exit_code=$?

    # Log the raw output
    echo "$output" >> $LOG_FILE

    # Check for timeout
    if [ $exit_code -eq 124 ]; then
        log "⛔ Command timed out after $timeout seconds"
        log "Command: $peer_cmd"
        echo -e "${RED}Command timed out. Check log file: $LOG_FILE${NC}"
        return 124
    fi

    # Check for other errors
    if [ $exit_code -ne 0 ]; then
        if [ "$allow_error" = "false" ]; then
            log "⛔ Error executing command. Exit code: $exit_code"
            log "Command: $peer_cmd"
            log "Output: $output"
            echo -e "${RED}Error executing command. Check log file: $LOG_FILE${NC}"
            exit 1
        else
            # Just log the error but don't exit
            log "⚠️ Command returned non-zero exit code: $exit_code"
            log "Command: $peer_cmd"
            log "Output: $output"
        fi
    fi

    # Return the output for potential further processing
    echo "$output"
    return $exit_code
}

# Function to format and colorize JSON (expects potentially mixed string as input)
format_json() {
    # Attempt to extract lines starting with { or [ (allowing leading whitespace)
    local json_part=$(echo "$1" | grep -E '^\s*[\{\[]')
    if [ -z "$json_part" ]; then
        log "⚠️ format_json: Could not find JSON start ({ or [) in input:"
        log "$1"
        echo "Error: Could not extract JSON from query output." >&2 # Send error to stderr
        return 1 # Indicate failure
    fi

    # Use python with pygments for colorization
    echo "$json_part" | python3 -c '
import sys, json, io
try:
    from pygments import highlight
    from pygments.lexers import JsonLexer
    from pygments.formatters import TerminalFormatter
    PYGMENTS_AVAILABLE = True
except ImportError:
    PYGMENTS_AVAILABLE = False
    print("Warning: pygments library not found. Install with: pip install Pygments", file=sys.stderr)

# Read all input first
stdin_data = sys.stdin.read()
try:
    # Parse the JSON
    data = json.load(io.StringIO(stdin_data))
    # Format it nicely
    formatted_json = json.dumps(data, indent=2)

    if PYGMENTS_AVAILABLE:
        # Colorize if pygments is available
        print(highlight(formatted_json, JsonLexer(), TerminalFormatter()))
    else:
        # Otherwise, just print the formatted JSON
        print(formatted_json)

except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON after extraction: {e}", file=sys.stderr)
    print("--- Raw input to python ---", file=sys.stderr)
    print(stdin_data, file=sys.stderr)
    print("--- End raw input ---", file=sys.stderr)
    exit(1)
'
    # Check python exit code
    local python_exit_code=$?
    if [ $python_exit_code -ne 0 ]; then
        log "⛔ format_json: Python JSON formatting failed with exit code $python_exit_code"
        # Error message already printed by python to stderr
        return $python_exit_code # Propagate failure
    fi
    return 0 # Indicate success
}

# Function to handle cleanup on script exit
cleanup() {
    if [ $? -ne 0 ]; then
        log "⛔ Script failed. Check the log file for details: $LOG_FILE"
        echo -e "\n${RED}Script failed. Check the log file: $LOG_FILE${NC}\n"
    fi
}
trap cleanup EXIT

# --- Demo Start ---

clear
log "Starting Zakat Chaincode Demo Script (27)"
echo -e "\n\n"
echo -e "${BOLD}${BLUE} ███████╗ █████╗ ██╗  ██╗ █████╗ ████████╗     ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗ ${NC}"
echo -e "${BOLD}${BLUE} ╚══███╔╝██╔══██╗██║ ██╔╝██╔══██╗╚══██╔══╝    ██╔════╝██║  ██║██╔══██╗██║████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝ ${NC}"
echo -e "${BOLD}${BLUE}   ███╔╝ ███████║█████╔╝ ███████║   ██║       ██║     ███████║███████║██║██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗   ${NC}"
echo -e "${BOLD}${BLUE}  ███╔╝  ██╔══██║██╔═██╗ ██╔══██║   ██║       ██║     ██╔══██║██╔══██║██║██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝   ${NC}"
echo -e "${BOLD}${BLUE} ███████╗██║  ██║██║  ██╗██║  ██║   ██║       ╚██████╗██║  ██║██║  ██║██║██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗ ${NC}"
echo -e "${BOLD}${BLUE} ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝        ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝ ${NC}"
echo -e "\n\n${BOLD}${BLUE}                    BLOCKCHAIN-BASED ZAKAT MANAGEMENT SYSTEM                           ${NC}"
echo -e "${BOLD}${BLUE}                              HYPERLEDGER FABRIC DEMO                                    ${NC}\n\n" | tee -a $LOG_FILE

log "Environment: Multi-Host Docker Containers via SSH"
echo -e "${YELLOW}Date: $(date)${NC}" | tee -a $LOG_FILE
echo -e "${YELLOW}Environment: Multi-Host Docker Containers via SSH${NC}" | tee -a $LOG_FILE

# Verify network components before starting
verify_network

read -p "Press Enter to start the demonstration..." dummy

# --- DEMO STEP 0: Initialize Ledger ---
print_header "STEP 0: INITIALIZE LEDGER (InitLedger)"
log "Invoking InitLedger function on chaincode '$CC_NAME' (Sequence: $SEQUENCE)..."

# First check chaincode commitment
log "Checking chaincode status..."
output=$(run_peer_command "$ORG1_IP" "$ORG1_CLI_CONTAINER" "peer lifecycle chaincode querycommitted -C $CHANNEL_NAME -n $CC_NAME")
if ! echo "$output" | grep -q "Version: ${CC_VERSION}"; then
    log "⛔ Error: Chaincode not properly committed. Please run installation and commit scripts first."
    exit 1
fi
log "✅ Chaincode is committed with correct version"

# Now check initialization status
log "Checking chaincode initialization..."
# Add '|| true' *after* the command substitution to prevent set -e from exiting if the query fails (which is expected if not initialized)
init_check=$(run_peer_command "$ORG1_IP" "$ORG1_CLI_CONTAINER" "peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\\\"function\\\":\\\"GetAllZakat\\\",\\\"Args\\\":[]}'" 10 true) || true
if echo "$init_check" | grep -q "must call as init first"; then
    log "Chaincode needs initialization"
    need_init=true
# Only exit if there's an error *and* it's not the expected 'init required' error
elif echo "$init_check" | grep -q "Error:"; then
    log "⛔ Error checking chaincode status (and it's not the expected 'init required' message):"
    log "$init_check"
    exit 1
else
    log "✅ Chaincode is already initialized"
    echo -e "${YELLOW}Chaincode is already initialized. Do you want to reinitialize it? [y/N]${NC} "
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        log "User chose to reinitialize chaincode"
        need_init=true
    else
        log "Skipping initialization as per user choice"
        echo -e "${GREEN}✓ Using existing chaincode initialization${NC}"
        sleep 2
        goto_step_1=true
    fi
fi

if [ "${need_init}" = "true" ]; then
    log "Starting chaincode initialization..."
    # InitLedger needs endorsement from both orgs as per the policy
    INIT_CMD="peer chaincode invoke \
        -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local \
        --tls --cafile $ORDERER_CA_CERT_PATH \
        -C $CHANNEL_NAME -n $CC_NAME \
        --peerAddresses $PEER_ADDRESS_ORG1 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG1_PATH \
        --peerAddresses $PEER_ADDRESS_ORG2 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG2_PATH \
        --isInit \
        -c '{\\\"function\\\":\\\"InitLedger\\\",\\\"Args\\\":[]}' \
        --waitForEvent \
        --connTimeout 30s"

    # Execute using Org1's CLI
    echo -e "${BOLD}${YELLOW}Invoking InitLedger (using Org1 CLI)${NC}" | tee -a $LOG_FILE
    echo -e "Initializing the ledger with default data (if any defined in InitLedger).\n" | tee -a $LOG_FILE
    echo -e "${UNDERLINE}Command (inside ${ORG1_CLI_CONTAINER}):${NC}\npeer chaincode invoke ... --isInit -c '{\"function\":\"InitLedger\",\"Args\":[]}' ...\n" | tee -a $LOG_FILE
    echo -e "${UNDERLINE}Result:${NC}" | tee -a $LOG_FILE

    INIT_OUTPUT=$(run_peer_command "$ORG1_IP" "$ORG1_CLI_CONTAINER" "$INIT_CMD")
    # Explicitly log the raw output from the InitLedger invoke command
    log "--- InitLedger Invoke Output ---"
    log "$INIT_OUTPUT"
    log "--- End InitLedger Invoke Output ---"
    echo "$INIT_OUTPUT" | tee -a $LOG_FILE # Keep existing tee for terminal output

    # Explicitly check for errors in the output, even if exit code was 0
    if echo "$INIT_OUTPUT" | grep -q -i "error"; then
        log "⛔ Error detected in InitLedger output, even though command might have returned success:"
        log "$INIT_OUTPUT"
        exit 1
    fi

    echo -e "\n${GREEN}✓ InitLedger invoke command sent successfully (Check logs for detailed output and potential transaction errors)${NC}\n" | tee -a $LOG_FILE
    log "Waiting for transaction to be committed..."
    sleep 5

    # Verify initialization was successful
    # Verify initialization was successful
    # Wait a moment for the initialization to be committed
    # Increased sleep from 5 to 10 for potentially slow init processing
    sleep 10

    # Verify initialization was successful
    # Verify initialization was successful
    log "Verifying initialization..."
    verify_output=$(run_peer_command "$ORG1_IP" "$ORG1_CLI_CONTAINER" "peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\\\"function\\\":\\\"GetAllZakat\\\",\\\"Args\\\":[]}'" 10 true)
    if echo "$verify_output" | grep -q "must call as init first"; then
        log "⛔ Error: Chaincode initialization failed - still needs initialization"
        exit 1
    elif echo "$verify_output" | grep -q "Error:"; then
        log "⛔ Error verifying chaincode initialization"
        log "$verify_output"
        exit 1
    else
        log "✅ Chaincode initialization verified"
    fi
else
    log "Skipping initialization phase"
    if [ "${goto_step_1}" != "true" ]; then
        log "⛔ Error: Unexpected state - neither initialization needed nor skipping to step 1"
        exit 1
    fi
fi

# --- DEMO STEP 1: Initial Query ---
print_header "STEP 1: QUERY INITIAL BLOCKCHAIN STATE"
log "Querying GetAllZakat from chaincode '$CC_NAME'..."

# Need extra escaping for the JSON when passing through SSH and docker exec
QUERY_ALL_CMD="peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\\\"function\\\":\\\"GetAllZakat\\\",\\\"Args\\\":[]}'"

# Execute using Org1's CLI
echo -e "${BOLD}${YELLOW}Query All Zakat Records (using Org1 CLI)${NC}" | tee -a $LOG_FILE
echo -e "Retrieving all zakat records from the blockchain to show the initial state after InitLedger.\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Command (inside ${ORG1_CLI_CONTAINER}):${NC}\n$QUERY_ALL_CMD\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Result (Formatted JSON):${NC}" | tee -a $LOG_FILE

QUERY_OUTPUT_RAW=$(run_peer_command "$ORG1_IP" "$ORG1_CLI_CONTAINER" "$QUERY_ALL_CMD")
formatted_json=$(format_json "$QUERY_OUTPUT_RAW")
json_format_exit_code=$?
if [ $json_format_exit_code -ne 0 ]; then
    log "⛔ Failed to format JSON output for Step 1. Raw output:"
    log "$QUERY_OUTPUT_RAW"
    # Print the error from format_json (which goes to stderr) to the terminal as well
    echo -e "${RED}$formatted_json${NC}"
else
    echo "$formatted_json" | tee -a $LOG_FILE
fi
echo -e "\n${GREEN}✓ Initial state queried successfully${NC}\n" | tee -a $LOG_FILE

# --- DEMO STEP 2: Add New Zakat Transaction (Org1) ---
print_header "STEP 2: ADD NEW ZAKAT TRANSACTION (Org1 - YDSF Malang)"
log "Adding new Zakat record via Org1 CLI..."

# Generate dynamic data
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MONTH_YEAR=$(date +"%Y%m")
ZKT_ID="ZKT-YDSF-MLG-${MONTH_YEAR}-$(shuf -i 1000-9999 -n 1)" # Add random element

# Random Donor Name Generation
FIRST_NAMES=("Ahmad" "Budi" "Citra" "Dewi" "Eko" "Fajar" "Gita" "Hadi" "Indah" "Joko")
LAST_NAMES=("Santoso" "Wijaya" "Lestari" "Kusuma" "Pratama" "Nugroho" "Wahyuni" "Setiawan" "Hidayat" "Putri")
RANDOM_FIRST_NAME=$(printf "%s\n" "${FIRST_NAMES[@]}" | shuf -n 1)
RANDOM_LAST_NAME=$(printf "%s\n" "${LAST_NAMES[@]}" | shuf -n 1)
DONOR_NAME="$RANDOM_FIRST_NAME $RANDOM_LAST_NAME"
log "Generated random donor name: $DONOR_NAME"

AMOUNT="2500000"
TYPE="maal"
COLLECTOR="YDSF Malang"

# Invoke requires endorsement from both orgs
ADD_CMD="peer chaincode invoke \
    -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local \
    --tls --cafile $ORDERER_CA_CERT_PATH \
    -C $CHANNEL_NAME -n $CC_NAME \
    --peerAddresses $PEER_ADDRESS_ORG1 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG1_PATH \
    --peerAddresses $PEER_ADDRESS_ORG2 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG2_PATH \
    -c '{\\\"function\\\":\\\"AddZakat\\\",\\\"Args\\\":[\\\"$ZKT_ID\\\", \\\"$DONOR_NAME\\\", \\\"$AMOUNT\\\", \\\"$TYPE\\\", \\\"$COLLECTOR\\\", \\\"$TIMESTAMP\\\"]}' \
    --waitForEvent \
    --connTimeout 30s"

# Execute using Org1's CLI
echo -e "${BOLD}${YELLOW}Add New Zakat Transaction (using Org1 CLI)${NC}" | tee -a $LOG_FILE
echo -e "Adding a new zakat donation record (ID: $ZKT_ID, Donor: $DONOR_NAME) to the blockchain as YDSF Malang.\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Command (inside ${ORG1_CLI_CONTAINER}):${NC}\npeer chaincode invoke ... -c '{\"function\":\"AddZakat\",\"Args\":[\"$ZKT_ID\", \"$DONOR_NAME\", ...] }' ...\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Result:${NC}" | tee -a $LOG_FILE

ADD_OUTPUT=$(run_peer_command "$ORG1_IP" "$ORG1_CLI_CONTAINER" "$ADD_CMD")
echo "$ADD_OUTPUT" | tee -a $LOG_FILE
echo -e "\n${GREEN}✓ New Zakat record added successfully${NC}\n" | tee -a $LOG_FILE
log "Waiting for transaction to be committed..."
sleep 5

# --- DEMO STEP 3: Query Specific Zakat Transaction ---
print_header "STEP 3: QUERY SPECIFIC ZAKAT TRANSACTION"
log "Querying specific Zakat record (ID: $ZKT_ID)..."

# Need extra escaping for the JSON when passing through SSH and docker exec
QUERY_SPECIFIC_CMD="peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\\\"function\\\":\\\"QueryZakat\\\",\\\"Args\\\":[\\\"$ZKT_ID\\\"]}'"

# Execute using Org2's CLI (demonstrates cross-org query)
echo -e "${BOLD}${YELLOW}Query Specific Zakat Record (using Org2 CLI)${NC}" | tee -a $LOG_FILE
echo -e "Retrieving details of the newly added zakat record (ID: $ZKT_ID) from the blockchain using Org2's peer.\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Command (inside ${ORG2_CLI_CONTAINER}):${NC}\n$QUERY_SPECIFIC_CMD\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Result (Formatted JSON):${NC}" | tee -a $LOG_FILE

QUERY_OUTPUT_SPECIFIC_RAW=$(run_peer_command "$ORG2_IP" "$ORG2_CLI_CONTAINER" "$QUERY_SPECIFIC_CMD")
formatted_json=$(format_json "$QUERY_OUTPUT_SPECIFIC_RAW")
json_format_exit_code=$?
if [ $json_format_exit_code -ne 0 ]; then
    log "⛔ Failed to format JSON output for Step 3. Raw output:"
    log "$QUERY_OUTPUT_SPECIFIC_RAW"
    echo -e "${RED}$formatted_json${NC}"
else
    echo "$formatted_json" | tee -a $LOG_FILE
fi
echo -e "\n${GREEN}✓ Specific Zakat record queried successfully${NC}\n" | tee -a $LOG_FILE

# --- DEMO STEP 4: Distribute Zakat (Org2) ---
print_header "STEP 4: DISTRIBUTE ZAKAT (Org2 - YDSF Jatim)"
log "Distributing Zakat (ID: $ZKT_ID) via Org2 CLI..."

# Generate dynamic data
DIST_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RECIPIENT="Orphanage Foundation"
DIST_AMOUNT="1000000"

DISTRIBUTE_CMD="peer chaincode invoke \
    -o $ORDERER_ADDRESS --ordererTLSHostnameOverride orderer.fabriczakat.local \
    --tls --cafile $ORDERER_CA_CERT_PATH \
    -C $CHANNEL_NAME -n $CC_NAME \
    --peerAddresses $PEER_ADDRESS_ORG1 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG1_PATH \
    --peerAddresses $PEER_ADDRESS_ORG2 --tlsRootCertFiles $PEER_TLS_ROOTCERT_ORG2_PATH \
    -c '{\\\"function\\\":\\\"DistributeZakat\\\",\\\"Args\\\":[\\\"$ZKT_ID\\\", \\\"$RECIPIENT\\\", \\\"$DIST_AMOUNT\\\", \\\"$DIST_TIMESTAMP\\\"]}' \
    --waitForEvent \
    --connTimeout 30s"

# Execute using Org2's CLI
echo -e "${BOLD}${YELLOW}Distribute Zakat (using Org2 CLI)${NC}" | tee -a $LOG_FILE
echo -e "Distributing a portion ($DIST_AMOUNT) of the collected zakat (ID: $ZKT_ID) to '$RECIPIENT' (performed by YDSF Jatim).\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Command (inside ${ORG2_CLI_CONTAINER}):${NC}\npeer chaincode invoke ... -c '{\"function\":\"DistributeZakat\",\"Args\":[\"$ZKT_ID\", ...] }' ...\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Result:${NC}" | tee -a $LOG_FILE

DIST_OUTPUT=$(run_peer_command "$ORG2_IP" "$ORG2_CLI_CONTAINER" "$DISTRIBUTE_CMD")
echo "$DIST_OUTPUT" | tee -a $LOG_FILE
echo -e "\n${GREEN}✓ Zakat distributed successfully${NC}\n" | tee -a $LOG_FILE
log "Waiting for transaction to be committed..."
sleep 5

# --- DEMO STEP 5: Query Updated Zakat Status ---
print_header "STEP 5: QUERY UPDATED ZAKAT TRANSACTION"
log "Querying updated Zakat record (ID: $ZKT_ID) after distribution..."

# Execute using Org1's CLI (demonstrates cross-org query of updated state)
echo -e "${BOLD}${YELLOW}Query Updated Zakat Record (using Org1 CLI)${NC}" | tee -a $LOG_FILE
echo -e "Retrieving the updated zakat record (ID: $ZKT_ID) showing distribution details using Org1's peer.\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Command (inside ${ORG1_CLI_CONTAINER}):${NC}\n$QUERY_SPECIFIC_CMD\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Result (Formatted JSON):${NC}" | tee -a $LOG_FILE

QUERY_OUTPUT_UPDATED_RAW=$(run_peer_command "$ORG1_IP" "$ORG1_CLI_CONTAINER" "$QUERY_SPECIFIC_CMD")
formatted_json=$(format_json "$QUERY_OUTPUT_UPDATED_RAW")
json_format_exit_code=$?
if [ $json_format_exit_code -ne 0 ]; then
    log "⛔ Failed to format JSON output for Step 5. Raw output:"
    log "$QUERY_OUTPUT_UPDATED_RAW"
    echo -e "${RED}$formatted_json${NC}"
else
    echo "$formatted_json" | tee -a $LOG_FILE
fi
echo -e "\n${GREEN}✓ Updated Zakat record queried successfully${NC}\n" | tee -a $LOG_FILE

# --- DEMO STEP 6: Final Query All ---
print_header "STEP 6: QUERY FINAL BLOCKCHAIN STATE"
log "Querying GetAllZakat to show final state..."

# Execute using Org2's CLI
echo -e "${BOLD}${YELLOW}Query All Zakat Records (using Org2 CLI)${NC}" | tee -a $LOG_FILE
echo -e "Retrieving all zakat records to show the final state of the blockchain.\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Command (inside ${ORG2_CLI_CONTAINER}):${NC}\n$QUERY_ALL_CMD\n" | tee -a $LOG_FILE
echo -e "${UNDERLINE}Result (Formatted JSON):${NC}" | tee -a $LOG_FILE

QUERY_OUTPUT_FINAL_RAW=$(run_peer_command "$ORG2_IP" "$ORG2_CLI_CONTAINER" "$QUERY_ALL_CMD")
formatted_json=$(format_json "$QUERY_OUTPUT_FINAL_RAW")
json_format_exit_code=$?
if [ $json_format_exit_code -ne 0 ]; then
    log "⛔ Failed to format JSON output for Step 6. Raw output:"
    log "$QUERY_OUTPUT_FINAL_RAW"
    echo -e "${RED}$formatted_json${NC}"
else
    echo "$formatted_json" | tee -a $LOG_FILE
fi
echo -e "\n${GREEN}✓ Final state queried successfully${NC}\n" | tee -a $LOG_FILE

# --- DEMO CONCLUSION ---
print_header "DEMONSTRATION SUMMARY"

# Define summary template with embedded color codes (using eval later to expand)
SUMMARY_TEMPLATE=$(cat << 'EOF'

${BOLD}The demonstration showcased the following capabilities:${NC}

1. ${GREEN}Transparent Recording - All zakat transactions are recorded on the blockchain with complete details${NC}
2. ${GREEN}Cross-Organization Operations - Different organizations (YDSF Malang and YDSF Jatim) can interact with the same records${NC}
3. ${GREEN}Traceability - Each zakat transaction has a unique ID and complete audit trail${NC}
4. ${GREEN}Distribution Tracking - The blockchain records details of how zakat funds are distributed to recipients${NC}
5. ${GREEN}Data Integrity - All information is cryptographically secured and immutable${NC}

${BOLD}${BLUE}Blockchain Benefits for Zakat Management:${NC}

• ${YELLOW}Transparency - All stakeholders can verify zakat collection and distribution${NC}
• ${YELLOW}Trust - Cryptographic proof ensures data cannot be altered retroactively${NC}
• ${YELLOW}Efficiency - Streamlined process reduces administrative overhead${NC}
• ${YELLOW}Accountability - Clear record of all transactions and distributions${NC}
• ${YELLOW}Collaboration - Multiple zakat organizations can work together on the same platform${NC}

${BOLD}${GREEN}Thank you for attending this demonstration!${NC}

EOF
)

# Evaluate the template to expand color variables and print/log
eval "echo -e \"$SUMMARY_TEMPLATE\"" | tee -a $LOG_FILE

log "Zakat Chaincode Demo Script (27) finished successfully."
