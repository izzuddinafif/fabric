#!/bin/bash
# Script 22: Zakat Chaincode Demo for Presentation
# This script demonstrates the Zakat chaincode functionality with formatted output

set -e

# Set environment variables
CHANNEL_NAME=zakatchannel
CC_NAME=zakat
BASE_DIR=$HOME/fabric

# ANSI color codes for better presentation
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'
UNDERLINE='\033[4m'

# Function to format JSON output
format_json() {
  local json_data=$1
  echo "$json_data" | python3 -m json.tool | sed "s/\"/\\\"/g"
}

# Function to display section header
print_header() {
  local title=$1
  local width=80
  local line=$(printf '%*s' "$width" | tr ' ' '=')
  echo -e "\n${BOLD}${line}${NC}"
  echo -e "${BOLD}${BLUE}   $title${NC}"
  echo -e "${BOLD}${line}${NC}\n"
}

# Function to run a command and display the result
run_command() {
  local title=$1
  local description=$2
  local command=$3
  
  echo -e "${BOLD}${YELLOW}$title${NC}"
  echo -e "${description}\n"
  echo -e "${UNDERLINE}Command:${NC}"
  echo -e "$command\n"
  echo -e "${UNDERLINE}Result:${NC}"
  
  # Run the command
  eval "$command"
  
  echo -e "\n${GREEN}✓ Operation completed successfully${NC}\n"
}

# Check if we're using Docker
if docker ps | grep -q "peer.org1.fabriczakat.local"; then
  # We're using Docker deployment
  USE_DOCKER=true
  ORG1_PEER="peer.org1.fabriczakat.local"
  ORG2_PEER="peer.org2.fabriczakat.local"
  ORDERER="orderer.fabriczakat.local:7050"
  ORDERER_CA="/etc/hyperledger/fabric/tls/ca.crt"
  TLS_ROOT_CERT_ORG1="/etc/hyperledger/fabric/tls/ca.crt"
  TLS_ROOT_CERT_ORG2="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/peers/peer.org2.fabriczakat.local/tls/ca.crt"
else
  # We're using native deployment
  USE_DOCKER=false
  ORG1_PEER="peer.org1.fabriczakat.local:7051"
  ORG2_PEER="peer.org2.fabriczakat.local:7051"
  ORDERER="orderer.fabriczakat.local:7050"
  ORDERER_CA="$BASE_DIR/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/tls/ca.crt"
  TLS_ROOT_CERT_ORG1="$BASE_DIR/organizations/peerOrganizations/org1.fabriczakat.local/peers/peer.org1.fabriczakat.local/tls/ca.crt"
  TLS_ROOT_CERT_ORG2="$BASE_DIR/organizations/peerOrganizations/org2.fabriczakat.local/peers/peer.org2.fabriczakat.local/tls/ca.crt"
fi

# Display presentation title
clear
echo -e "\n\n"
echo -e "${BOLD}${BLUE} ███████╗ █████╗ ██╗  ██╗ █████╗ ████████╗     ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗ ${NC}"
echo -e "${BOLD}${BLUE} ╚══███╔╝██╔══██╗██║ ██╔╝██╔══██╗╚══██╔══╝    ██╔════╝██║  ██║██╔══██╗██║████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝ ${NC}"
echo -e "${BOLD}${BLUE}   ███╔╝ ███████║█████╔╝ ███████║   ██║       ██║     ███████║███████║██║██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗   ${NC}"
echo -e "${BOLD}${BLUE}  ███╔╝  ██╔══██║██╔═██╗ ██╔══██║   ██║       ██║     ██╔══██║██╔══██║██║██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝   ${NC}"
echo -e "${BOLD}${BLUE} ███████╗██║  ██║██║  ██╗██║  ██║   ██║       ╚██████╗██║  ██║██║  ██║██║██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗ ${NC}"
echo -e "${BOLD}${BLUE} ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝        ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝ ${NC}"
echo -e "\n\n${BOLD}${BLUE}                    BLOCKCHAIN-BASED ZAKAT MANAGEMENT SYSTEM                           ${NC}"
echo -e "${BOLD}${BLUE}                              HYPERLEDGER FABRIC DEMO                                    ${NC}\n\n"

echo -e "${YELLOW}Date: $(date)${NC}"
echo -e "${YELLOW}System: $(uname -a)${NC}"
echo -e "${YELLOW}Environment: $(if $USE_DOCKER; then echo "Docker Containers"; else echo "Native Deployment"; fi)${NC}"

# Wait for user to press enter
read -p "Press Enter to start the demonstration..." dummy

# Initialize chaincode environment for org1
setup_org1_env() {
  if $USE_DOCKER; then
    EXEC_PREFIX="docker exec $ORG1_PEER"
  else
    export FABRIC_CFG_PATH=$BASE_DIR/config
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_ADDRESS=$ORG1_PEER
    export CORE_PEER_TLS_ROOTCERT_FILE=$TLS_ROOT_CERT_ORG1
    export CORE_PEER_MSPCONFIGPATH=$BASE_DIR/organizations/peerOrganizations/org1.fabriczakat.local/users/Admin@org1.fabriczakat.local/msp
    EXEC_PREFIX=""
  fi
}

# Initialize chaincode environment for org2
setup_org2_env() {
  if $USE_DOCKER; then
    EXEC_PREFIX="docker exec $ORG2_PEER"
  else
    export FABRIC_CFG_PATH=$BASE_DIR/config
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org2MSP
    export CORE_PEER_ADDRESS=$ORG2_PEER
    export CORE_PEER_TLS_ROOTCERT_FILE=$TLS_ROOT_CERT_ORG2
    export CORE_PEER_MSPCONFIGPATH=$BASE_DIR/organizations/peerOrganizations/org2.fabriczakat.local/users/Admin@org2.fabriczakat.local/msp
    EXEC_PREFIX=""
  fi
}

# --- DEMO SECTION 1: Initial Query to Show Current State ---
print_header "INITIAL BLOCKCHAIN STATE"
setup_org1_env

# Get all zakat records
if $USE_DOCKER; then
  CMD="$EXEC_PREFIX peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"GetAllZakat\",\"Args\":[]}' | python3 -m json.tool"
else
  CMD="$EXEC_PREFIX peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"GetAllZakat\",\"Args\":[]}' | python3 -m json.tool"
fi

run_command "Query All Zakat Records" "Retrieving all zakat records from the blockchain to show the initial state" "$CMD"

# --- DEMO SECTION 2: Adding New Zakat Transaction from Org1 ---
print_header "ADDING NEW ZAKAT TRANSACTION (Org1 - YDSF Malang)"

# Generate a timestamp and ID for the transaction
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MONTH_YEAR=$(date +"%Y%m")
ZKT_ID="ZKT-YDSF-MLG-${MONTH_YEAR}-0002"

setup_org1_env

# Add new zakat transaction
if $USE_DOCKER; then
  CMD="$EXEC_PREFIX peer chaincode invoke -o $ORDERER --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"AddZakat\",\"Args\":[\"$ZKT_ID\", \"Ahmad Donor\", \"2500000\", \"maal\", \"YDSF Malang\", \"$TIMESTAMP\"]}' --waitForEvent"
else
  CMD="$EXEC_PREFIX peer chaincode invoke -o $ORDERER --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"AddZakat\",\"Args\":[\"$ZKT_ID\", \"Ahmad Donor\", \"2500000\", \"maal\", \"YDSF Malang\", \"$TIMESTAMP\"]}' --waitForEvent"
fi

run_command "Add New Zakat Transaction" "Adding a new zakat donation record to the blockchain as YDSF Malang organization" "$CMD"

# Wait for transaction to settle
echo "Waiting for transaction to be committed to the ledger..."
sleep 5

# --- DEMO SECTION 3: Query Specific Zakat Transaction ---
print_header "QUERYING SPECIFIC ZAKAT TRANSACTION"

# Query the transaction
if $USE_DOCKER; then
  CMD="$EXEC_PREFIX peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"QueryZakat\",\"Args\":[\"$ZKT_ID\"]}' | python3 -m json.tool"
else
  CMD="$EXEC_PREFIX peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"QueryZakat\",\"Args\":[\"$ZKT_ID\"]}' | python3 -m json.tool"
fi

run_command "Query Specific Zakat Record" "Retrieving details of the newly added zakat record from the blockchain" "$CMD"

# --- DEMO SECTION 4: Distributing Zakat from Org2 ---
print_header "DISTRIBUTING ZAKAT (Org2 - YDSF Jatim)"

# Generate a timestamp for distribution
DIST_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

setup_org2_env

# Distribute zakat
if $USE_DOCKER; then
  CMD="$EXEC_PREFIX peer chaincode invoke -o $ORDERER --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"DistributeZakat\",\"Args\":[\"$ZKT_ID\", \"Orphanage Foundation\", \"1000000\", \"$DIST_TIMESTAMP\"]}' --waitForEvent"
else
  CMD="$EXEC_PREFIX peer chaincode invoke -o $ORDERER --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"DistributeZakat\",\"Args\":[\"$ZKT_ID\", \"Orphanage Foundation\", \"1000000\", \"$DIST_TIMESTAMP\"]}' --waitForEvent"
fi

run_command "Distribute Zakat" "Distributing a portion of the collected zakat funds to a recipient (performed by YDSF Jatim)" "$CMD"

# Wait for transaction to settle
echo "Waiting for transaction to be committed to the ledger..."
sleep 5

# --- DEMO SECTION 5: Query Updated Zakat Status ---
print_header "QUERYING UPDATED ZAKAT TRANSACTION"

# Query the transaction again to show updated status
if $USE_DOCKER; then
  CMD="$EXEC_PREFIX peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"QueryZakat\",\"Args\":[\"$ZKT_ID\"]}' | python3 -m json.tool"
else
  CMD="$EXEC_PREFIX peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"QueryZakat\",\"Args\":[\"$ZKT_ID\"]}' | python3 -m json.tool"
fi

run_command "Query Updated Zakat Record" "Retrieving the updated zakat record showing distribution details" "$CMD"

# --- DEMO SECTION 6: Final Query to Show All Zakat Transactions ---
print_header "FINAL BLOCKCHAIN STATE"

# Get all zakat records again to show final state
if $USE_DOCKER; then
  CMD="$EXEC_PREFIX peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"GetAllZakat\",\"Args\":[]}' | python3 -m json.tool"
else
  CMD="$EXEC_PREFIX peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c '{\"function\":\"GetAllZakat\",\"Args\":[]}' | python3 -m json.tool"
fi

run_command "Query All Zakat Records" "Retrieving all zakat records to show the final state of the blockchain" "$CMD"

# --- DEMO CONCLUSION ---
print_header "DEMONSTRATION SUMMARY"

echo -e "${BOLD}The demonstration showcased the following capabilities:${NC}\n"
echo -e "1. ${GREEN}Transparent Recording${NC} - All zakat transactions are recorded on the blockchain with complete details"
echo -e "2. ${GREEN}Cross-Organization Operations${NC} - Different organizations (YDSF Malang and YDSF Jatim) can interact with the same records"
echo -e "3. ${GREEN}Traceability${NC} - Each zakat transaction has a unique ID and complete audit trail"
echo -e "4. ${GREEN}Distribution Tracking${NC} - The blockchain records details of how zakat funds are distributed to recipients"
echo -e "5. ${GREEN}Data Integrity${NC} - All information is cryptographically secured and immutable\n"

echo -e "${BOLD}${BLUE}Blockchain Benefits for Zakat Management:${NC}\n"
echo -e "• ${YELLOW}Transparency${NC} - All stakeholders can verify zakat collection and distribution"
echo -e "• ${YELLOW}Trust${NC} - Cryptographic proof ensures data cannot be altered retroactively"
echo -e "• ${YELLOW}Efficiency${NC} - Streamlined process reduces administrative overhead"
echo -e "• ${YELLOW}Accountability${NC} - Clear record of all transactions and distributions"
echo -e "• ${YELLOW}Collaboration${NC} - Multiple zakat organizations can work together on the same platform\n"

echo -e "${BOLD}${GREEN}Thank you for attending this demonstration!${NC}\n"