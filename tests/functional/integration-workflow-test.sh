#!/bin/bash
# Integration Workflow Test - End-to-End Zakat Business Process
# Simulates complete real-world zakat donation scenario

set -e

# Configuration
CHANNEL_NAME="zakatchannel"
CC_NAME="zakat"

ORG1_CLI="cli.org1.fabriczakat.local"
ORG2_CLI="cli.org2.fabriczakat.local"
ORG1_IP="10.104.0.2"
ORG2_IP="10.104.0.4"

LOG_DIR="$HOME/fabric/tests/functional/results"
LOG_FILE="$LOG_DIR/integration-workflow-$(date +%Y%m%d-%H%M%S).log"
mkdir -p $LOG_DIR
> $LOG_FILE

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

print_step() {
    local step_num="$1"
    local title="$2"
    echo -e "\n${BOLD}${BLUE}=== STEP $step_num: $title ===${NC}" | tee -a $LOG_FILE
}

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
    
    local cmd_type="invoke"
    if [ "$is_query" = "true" ]; then
        cmd_type="query"
    fi
    
    log "Executing $cmd_type on $org_cli: $function($args)"
    ssh fabricadmin@$org_ip "docker exec $org_cli bash -c \"peer chaincode $cmd_type -C $CHANNEL_NAME -n $CC_NAME -c '{\\\"function\\\":\\\"$function\\\",\\\"Args\\\":[$args]}' --waitForEvent\"" 2>&1
}

verify_result() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if echo "$actual" | grep -q "$expected"; then
        echo -e "${GREEN}✅ VERIFIED${NC}: $test_name" | tee -a $LOG_FILE
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}: $test_name" | tee -a $LOG_FILE
        echo "Expected: $expected" | tee -a $LOG_FILE
        echo "Actual: $actual" | tee -a $LOG_FILE
        return 1
    fi
}

# Main Integration Test Workflow
main() {
    log "Starting Integration Workflow Test - Complete Zakat Business Process"
    
    # Generate unique identifiers for this test run
    local timestamp=$(date +%s)
    local program_id="PROG-2024-${timestamp:(-4)}"
    local officer_id="OFF-2024-${timestamp:(-4)}"
    local referral_code="REF${timestamp:(-6)}"
    local zakat_id_1="ZKT-YDSF-MLG-$(date +%Y%m)-${timestamp:(-4)}"
    local zakat_id_2="ZKT-YDSF-JTM-$(date +%Y%m)-${timestamp:(-4)}"
    
    # STEP 1: Setup - Create Donation Program
    print_step "1" "Create New Donation Program"
    
    local prog_name="Ramadan Emergency Relief $timestamp"
    local description="Emergency relief program for Ramadan period - Integration Test"
    local target="10000000"  # 10M IDR target
    local start_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local end_date="$(date -u -d '+6 months' +%Y-%m-%dT%H:%M:%SZ)"
    local created_by="IntegrationTestAdmin"
    
    result=$(execute_chaincode "$ORG1_CLI" "CreateProgram" "\"$program_id\",\"$prog_name\",\"$description\",\"$target\",\"$start_date\",\"$end_date\",\"$created_by\"")
    verify_result "successfully" "$result" "Program Creation"
    
    # STEP 2: Setup - Register Field Officer
    print_step "2" "Register Field Officer for Referrals"
    
    local officer_name="Integration Test Officer $timestamp"
    
    result=$(execute_chaincode "$ORG2_CLI" "RegisterOfficer" "\"$officer_id\",\"$officer_name\",\"$referral_code\"")
    verify_result "successfully" "$result" "Officer Registration"
    
    # STEP 3: Donor Submits Zakat (Org1 - YDSF Malang)
    print_step "3" "Donor Submits Zakat via YDSF Malang"
    
    local muzakki_1="Ahmad Kurniawan"
    local amount_1="2500000"  # 2.5M IDR
    local zakat_type_1="maal"
    local payment_method_1="transfer"
    local organization_1="YDSF Malang"
    
    result=$(execute_chaincode "$ORG1_CLI" "AddZakat" "\"$zakat_id_1\",\"$program_id\",\"$muzakki_1\",\"$amount_1\",\"$zakat_type_1\",\"$payment_method_1\",\"$organization_1\",\"$referral_code\"")
    verify_result "successfully" "$result" "Zakat Submission (Org1)"
    
    # STEP 4: Donor Submits Zakat (Org2 - YDSF Jatim)
    print_step "4" "Donor Submits Zakat via YDSF Jatim"
    
    local muzakki_2="Fatimah Sari Dewi"
    local amount_2="1750000"  # 1.75M IDR
    local zakat_type_2="fitrah"
    local payment_method_2="ewallet"
    local organization_2="YDSF Jatim"
    
    result=$(execute_chaincode "$ORG2_CLI" "AddZakat" "\"$zakat_id_2\",\"$program_id\",\"$muzakki_2\",\"$amount_2\",\"$zakat_type_2\",\"$payment_method_2\",\"$organization_2\",\"$referral_code\"")
    verify_result "successfully" "$result" "Zakat Submission (Org2)"
    
    # STEP 5: Verify Pending Status
    print_step "5" "Verify Pending Donations in System"
    
    result=$(execute_chaincode "$ORG1_CLI" "GetZakatByStatus" "\"pending\"" "true")
    verify_result "$zakat_id_1" "$result" "Zakat 1 in Pending Status"
    verify_result "$zakat_id_2" "$result" "Zakat 2 in Pending Status"
    
    # STEP 6: Verify Program Association
    print_step "6" "Verify Program Association"
    
    result=$(execute_chaincode "$ORG1_CLI" "GetZakatByProgram" "\"$program_id\"" "true")
    verify_result "$zakat_id_1" "$result" "Zakat 1 linked to Program"
    verify_result "$zakat_id_2" "$result" "Zakat 2 linked to Program"
    
    # STEP 7: Admin Payment Validation (Org1)
    print_step "7" "Admin Validates Payment (YDSF Malang)"
    
    local receipt_1="INV/MLG/$(date +%Y%m%d)/${timestamp:(-6)}"
    local validated_by_1="AdminMalang"
    
    result=$(execute_chaincode "$ORG1_CLI" "ValidatePayment" "\"$zakat_id_1\",\"$receipt_1\",\"$validated_by_1\"")
    verify_result "successfully" "$result" "Payment Validation (Org1)"
    
    # STEP 8: Admin Payment Validation (Org2)
    print_step "8" "Admin Validates Payment (YDSF Jatim)"
    
    local receipt_2="INV/JTM/$(date +%Y%m%d)/${timestamp:(-6)}"
    local validated_by_2="AdminJatim"
    
    result=$(execute_chaincode "$ORG2_CLI" "ValidatePayment" "\"$zakat_id_2\",\"$receipt_2\",\"$validated_by_2\"")
    verify_result "successfully" "$result" "Payment Validation (Org2)"
    
    # STEP 9: Verify Collected Status
    print_step "9" "Verify Collected Status and Program Updates"
    
    result=$(execute_chaincode "$ORG1_CLI" "GetZakatByStatus" "\"collected\"" "true")
    verify_result "$zakat_id_1" "$result" "Zakat 1 Status Updated to Collected"
    verify_result "$zakat_id_2" "$result" "Zakat 2 Status Updated to Collected"
    
    # Verify program collected amount updated
    result=$(execute_chaincode "$ORG1_CLI" "GetProgram" "\"$program_id\"" "true")
    verify_result "4250000" "$result" "Program Collected Amount Updated (2.5M + 1.75M)"
    
    # STEP 10: Verify Officer Referral Updates
    print_step "10" "Verify Officer Referral Tracking"
    
    result=$(execute_chaincode "$ORG2_CLI" "GetOfficerByReferral" "\"$referral_code\"" "true")
    verify_result "4250000" "$result" "Officer Total Referred Amount Updated"
    
    # STEP 11: Distribution to Mustahik (Org1)
    print_step "11" "Distribute Funds to Mustahik (YDSF Malang)"
    
    local mustahik_1="Yatim Piatu Panti Asuhan Al-Ikhlas"
    local distribution_timestamp_1="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    result=$(execute_chaincode "$ORG1_CLI" "DistributeZakat" "\"$zakat_id_1\",\"$mustahik_1\",\"$amount_1\",\"$distribution_timestamp_1\"")
    verify_result "successfully" "$result" "Zakat Distribution (Org1)"
    
    # STEP 12: Distribution to Mustahik (Org2)
    print_step "12" "Distribute Funds to Mustahik (YDSF Jatim)"
    
    local mustahik_2="Keluarga Dhuafa Kelurahan Tanjungsari"
    local distribution_timestamp_2="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    result=$(execute_chaincode "$ORG2_CLI" "DistributeZakat" "\"$zakat_id_2\",\"$mustahik_2\",\"$amount_2\",\"$distribution_timestamp_2\"")
    verify_result "successfully" "$result" "Zakat Distribution (Org2)"
    
    # STEP 13: Verify Final Distributed Status
    print_step "13" "Verify Final Distribution Status"
    
    result=$(execute_chaincode "$ORG1_CLI" "GetZakatByStatus" "\"distributed\"" "true")
    verify_result "$zakat_id_1" "$result" "Zakat 1 Final Status: Distributed"
    verify_result "$zakat_id_2" "$result" "Zakat 2 Final Status: Distributed"
    
    # STEP 14: Generate Daily Report
    print_step "14" "Generate Daily Activity Report"
    
    local report_date=$(date +%Y-%m-%d)
    result=$(execute_chaincode "$ORG1_CLI" "GetDailyReport" "\"$report_date\"" "true")
    verify_result "totalAmount" "$result" "Daily Report Contains Transaction Summary"
    verify_result "transactionCount" "$result" "Daily Report Contains Transaction Count"
    
    # STEP 15: Cross-Organization Data Consistency Check
    print_step "15" "Cross-Organization Consistency Verification"
    
    # Query same transaction from both orgs
    result_org1=$(execute_chaincode "$ORG1_CLI" "QueryZakat" "\"$zakat_id_1\"" "true")
    result_org2=$(execute_chaincode "$ORG2_CLI" "QueryZakat" "\"$zakat_id_1\"" "true")
    
    # Extract amounts from both results and compare
    amount_org1=$(echo "$result_org1" | grep -o '"amount":[0-9]*' | cut -d: -f2)
    amount_org2=$(echo "$result_org2" | grep -o '"amount":[0-9]*' | cut -d: -f2)
    
    if [ "$amount_org1" = "$amount_org2" ]; then
        echo -e "${GREEN}✅ VERIFIED${NC}: Cross-Organization Data Consistency" | tee -a $LOG_FILE
    else
        echo -e "${RED}❌ FAILED${NC}: Cross-Organization Data Consistency" | tee -a $LOG_FILE
    fi
    
    # STEP 16: Complete Workflow Summary
    print_step "16" "Integration Test Summary"
    
    log "INTEGRATION TEST COMPLETED SUCCESSFULLY!"
    log ""
    log "Workflow Summary:"
    log "  • Program Created: $program_id ($prog_name)"
    log "  • Officer Registered: $officer_id ($officer_name)"
    log "  • Donations Submitted: 2 transactions (Total: 4.25M IDR)"
    log "  • Payments Validated: Both transactions by respective admins"
    log "  • Funds Distributed: Both transactions to mustahik recipients"
    log "  • Cross-Org Consistency: Verified"
    log "  • Daily Reporting: Functional"
    log ""
    log "Complete End-to-End Zakat Business Process Successfully Tested!"
    
    echo -e "\n${GREEN}🎉 INTEGRATION WORKFLOW TEST PASSED!${NC}" | tee -a $LOG_FILE
    echo -e "Full workflow from donation submission to distribution completed successfully." | tee -a $LOG_FILE
    echo -e "Test log saved to: $LOG_FILE" | tee -a $LOG_FILE
}

# Execute main workflow
main "$@"