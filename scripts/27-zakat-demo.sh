#!/bin/bash
set -e # Exit on error

# Source helper scripts
source "$(dirname "$0")/helper/demo-utils.sh"

# Channel and chaincode configuration
CHANNEL_NAME="zakatchannel"
CC_NAME="zakat"
CC_VERSION="1.0"
SEQUENCE="1"

# Organization details
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

# Orderer details
ORDERER_IP="10.104.0.3"
ORDERER_DOMAIN="fabriczakat.local"
ORDERER_CONTAINER="orderer.fabriczakat.local"
ORDERER_ADDRESS="orderer.fabriczakat.local:7050"
ORDERER_CA_CERT_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem"

# Setup logging
LOG_DIR="$HOME/fabric/logs"
LOG_FILE="$LOG_DIR/27-zakat-demo.log"
mkdir -p $LOG_DIR
> $LOG_FILE # Clear previous log

# Print Zakat demo header
print_zakat_header | tee -a $LOG_FILE
echo -e "${YELLOW}Date: $(date)${NC}" | tee -a $LOG_FILE
echo -e "${YELLOW}Environment: Multi-Host Docker Containers via SSH${NC}" | tee -a $LOG_FILE

# Verify network components before starting
print_section_header "VERIFY NETWORK COMPONENTS"
log_msg "$LOG_FILE" "Checking orderer container..."
check_container "$ORDERER_IP" "$ORDERER_CONTAINER" || exit 1

log_msg "$LOG_FILE" "Checking Org1 containers..."
check_container "$ORG1_IP" "$ORG1_PEER_CONTAINER" || exit 1
check_container "$ORG1_IP" "$ORG1_CLI_CONTAINER" || exit 1

log_msg "$LOG_FILE" "Checking Org2 containers..."
check_container "$ORG2_IP" "$ORG2_PEER_CONTAINER" || exit 1
check_container "$ORG2_IP" "$ORG2_CLI_CONTAINER" || exit 1

log_msg "$LOG_FILE" "✅ All network components verified"
read -p "Press Enter to start the demonstration..." dummy

# Initialize Ledger
print_section_header "STEP 0: INITIALIZE LEDGER"
log_msg "$LOG_FILE" "Checking chaincode status..."

# Check chaincode commitment
query_output=$(chaincode_query \
    "$ORG1_IP" \
    "$ORG1_CLI_CONTAINER" \
    "$CHANNEL_NAME" \
    "$CC_NAME" \
    "GetAllZakat" \
    "[]" \
    "$LOG_FILE")

if echo "$query_output" | grep -q "must call as init first"; then
    log_msg "$LOG_FILE" "Chaincode needs initialization"
    # Execute InitLedger
    chaincode_invoke \
        "$ORG1_IP" \
        "$ORG1_CLI_CONTAINER" \
        "$CHANNEL_NAME" \
        "$CC_NAME" \
        "InitLedger" \
        "[]" \
        "$ORDERER_ADDRESS" \
        "$ORDERER_CA_CERT_PATH" \
        "$LOG_FILE" || exit 1
    sleep 5
else
    log_msg "$LOG_FILE" "✅ Chaincode is already initialized"
fi

# Query Initial State
print_section_header "STEP 1: QUERY INITIAL BLOCKCHAIN STATE"
query_output=$(chaincode_query \
    "$ORG1_IP" \
    "$ORG1_CLI_CONTAINER" \
    "$CHANNEL_NAME" \
    "$CC_NAME" \
    "GetAllZakat" \
    "[]" \
    "$LOG_FILE")

echo -e "${UNDERLINE}Initial State:${NC}" | tee -a $LOG_FILE
format_json "$query_output" | tee -a $LOG_FILE

# Add New Zakat Transaction (Org1)
print_section_header "STEP 2: ADD NEW ZAKAT TRANSACTION (Org1 - YDSF Malang)"
ZKT_ID=$(generate_zakat_id "YDSF-MLG")
DONOR_NAME=$(generate_donor_name)
AMOUNT="2500000"
TYPE="maal"
COLLECTOR="YDSF Malang"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log_msg "$LOG_FILE" "Adding new Zakat record (ID: $ZKT_ID, Donor: $DONOR_NAME)..."

chaincode_invoke \
    "$ORG1_IP" \
    "$ORG1_CLI_CONTAINER" \
    "$CHANNEL_NAME" \
    "$CC_NAME" \
    "AddZakat" \
    "[\"$ZKT_ID\", \"$DONOR_NAME\", \"$AMOUNT\", \"$TYPE\", \"$COLLECTOR\", \"$TIMESTAMP\"]" \
    "$ORDERER_ADDRESS" \
    "$ORDERER_CA_CERT_PATH" \
    "$LOG_FILE" || exit 1
sleep 5

# Query Specific Transaction
print_section_header "STEP 3: QUERY SPECIFIC ZAKAT TRANSACTION"
query_output=$(chaincode_query \
    "$ORG2_IP" \
    "$ORG2_CLI_CONTAINER" \
    "$CHANNEL_NAME" \
    "$CC_NAME" \
    "QueryZakat" \
    "[\"$ZKT_ID\"]" \
    "$LOG_FILE")

echo -e "${UNDERLINE}Transaction Details:${NC}" | tee -a $LOG_FILE
format_json "$query_output" | tee -a $LOG_FILE

# Distribute Zakat (Org2)
print_section_header "STEP 4: DISTRIBUTE ZAKAT (Org2 - YDSF Jatim)"
DIST_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RECIPIENT="Orphanage Foundation"
DIST_AMOUNT="1000000"

log_msg "$LOG_FILE" "Distributing Zakat (ID: $ZKT_ID) to $RECIPIENT..."

chaincode_invoke \
    "$ORG2_IP" \
    "$ORG2_CLI_CONTAINER" \
    "$CHANNEL_NAME" \
    "$CC_NAME" \
    "DistributeZakat" \
    "[\"$ZKT_ID\", \"$RECIPIENT\", \"$DIST_AMOUNT\", \"$DIST_TIMESTAMP\"]" \
    "$ORDERER_ADDRESS" \
    "$ORDERER_CA_CERT_PATH" \
    "$LOG_FILE" || exit 1
sleep 5

# Query Updated Transaction
print_section_header "STEP 5: QUERY UPDATED ZAKAT TRANSACTION"
query_output=$(chaincode_query \
    "$ORG1_IP" \
    "$ORG1_CLI_CONTAINER" \
    "$CHANNEL_NAME" \
    "$CC_NAME" \
    "QueryZakat" \
    "[\"$ZKT_ID\"]" \
    "$LOG_FILE")

echo -e "${UNDERLINE}Updated Transaction Details:${NC}" | tee -a $LOG_FILE
format_json "$query_output" | tee -a $LOG_FILE

# Query Final State
print_section_header "STEP 6: QUERY FINAL BLOCKCHAIN STATE"
query_output=$(chaincode_query \
    "$ORG2_IP" \
    "$ORG2_CLI_CONTAINER" \
    "$CHANNEL_NAME" \
    "$CC_NAME" \
    "GetAllZakat" \
    "[]" \
    "$LOG_FILE")

echo -e "${UNDERLINE}Final State:${NC}" | tee -a $LOG_FILE
format_json "$query_output" | tee -a $LOG_FILE

# Print Demo Summary
print_section_header "DEMONSTRATION SUMMARY"
print_demo_summary | tee -a $LOG_FILE

log_msg "$LOG_FILE" "Zakat Chaincode Demo Script (27) finished successfully."
exit 0
