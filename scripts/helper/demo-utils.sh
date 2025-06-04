#!/bin/bash

# Source other utilities
source "$(dirname "$0")/docker-utils.sh"
source "$(dirname "$0")/ssh-utils.sh"

# ANSI color codes
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m'
export BOLD='\033[1m'
export UNDERLINE='\033[4m'

# Print demo header
print_zakat_header() {
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
}

# Print section header
print_section_header() {
    local title=$1
    local width=80
    local line=$(printf '%*s' "$width" | tr ' ' '=')
    echo -e "\n${BOLD}${line}${NC}"
    echo -e "${BOLD}${BLUE}   $title${NC}"
    echo -e "${BOLD}${line}${NC}\n"
}

# Format and colorize JSON output
format_json() {
    local json_part=$(echo "$1" | grep -E '^\s*[\{\[]')
    if [ -z "$json_part" ]; then
        echo "Error: Could not extract JSON from query output." >&2
        return 1
    fi

    echo "$json_part" | python3 -c '
import sys, json, io
try:
    from pygments import highlight
    from pygments.lexers import JsonLexer
    from pygments.formatters import TerminalFormatter
    PYGMENTS_AVAILABLE = True
except ImportError:
    PYGMENTS_AVAILABLE = False

stdin_data = sys.stdin.read()
try:
    data = json.load(io.StringIO(stdin_data))
    formatted_json = json.dumps(data, indent=2)
    if PYGMENTS_AVAILABLE:
        print(highlight(formatted_json, JsonLexer(), TerminalFormatter()))
    else:
        print(formatted_json)
except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON: {e}", file=sys.stderr)
    print(stdin_data, file=sys.stderr)
    exit(1)
'
    return ${PIPESTATUS[1]}
}

# Generate random donor name
generate_donor_name() {
    local FIRST_NAMES=("Ahmad" "Budi" "Citra" "Dewi" "Eko" "Fajar" "Gita" "Hadi" "Indah" "Joko")
    local LAST_NAMES=("Santoso" "Wijaya" "Lestari" "Kusuma" "Pratama" "Nugroho" "Wahyuni" "Setiawan" "Hidayat" "Putri")
    local RANDOM_FIRST=$(printf "%s\n" "${FIRST_NAMES[@]}" | shuf -n 1)
    local RANDOM_LAST=$(printf "%s\n" "${LAST_NAMES[@]}" | shuf -n 1)
    echo "$RANDOM_FIRST $RANDOM_LAST"
}

# Generate Zakat transaction ID
generate_zakat_id() {
    local prefix=$1
    local month_year=$(date +"%Y%m")
    local random_num=$(shuf -i 1000-9999 -n 1)
    echo "ZKT-${prefix}-${month_year}-${random_num}"
}

# Execute chaincode query
# Arguments:
#   $1: Organization IP
#   $2: CLI container name
#   $3: Channel name
#   $4: Chaincode name
#   $5: Function name
#   $6: Arguments array
#   $7: Log file
chaincode_query() {
    local org_ip=$1
    local cli_container=$2
    local channel=$3
    local cc_name=$4
    local func=$5
    local args=$6
    local log_file=$7

    local query_cmd="peer chaincode query \
        -C $channel \
        -n $cc_name \
        -c '{\"function\":\"$func\",\"Args\":$args}'"

    run_peer_command "$org_ip" "$cli_container" "$query_cmd" || return 1
    return 0
}

# Execute chaincode invoke
# Arguments:
#   $1: Organization IP
#   $2: CLI container name
#   $3: Channel name
#   $4: Chaincode name
#   $5: Function name
#   $6: Arguments array
#   $7: Orderer details (host:port)
#   $8: TLS cert path
#   $9: Log file
chaincode_invoke() {
    local org_ip=$1
    local cli_container=$2
    local channel=$3
    local cc_name=$4
    local func=$5
    local args=$6
    local orderer_details=$7
    local tls_cert_path=$8
    local log_file=$9

    local invoke_cmd="peer chaincode invoke \
        -o $orderer_details \
        --tls --cafile $tls_cert_path \
        -C $channel \
        -n $cc_name \
        --peerAddresses peer.org1.fabriczakat.local:7051 \
        --tlsRootCertFiles /etc/hyperledger/fabric/tls/ca.crt \
        --peerAddresses peer.org2.fabriczakat.local:7051 \
        --tlsRootCertFiles /etc/hyperledger/fabric/tls/ca.crt \
        -c '{\"function\":\"$func\",\"Args\":$args}' \
        --waitForEvent"

    run_peer_command "$org_ip" "$cli_container" "$invoke_cmd" || return 1
    return 0
}

# Print demo summary
print_demo_summary() {
    local summary_template="""
${BOLD}The demonstration showcased the following capabilities:${NC}

1. ${GREEN}Transparent Recording - All zakat transactions are recorded on the blockchain with complete details${NC}
2. ${GREEN}Cross-Organization Operations - Different organizations can interact with the same records${NC}
3. ${GREEN}Traceability - Each zakat transaction has a unique ID and complete audit trail${NC}
4. ${GREEN}Distribution Tracking - The blockchain records details of how zakat funds are distributed${NC}
5. ${GREEN}Data Integrity - All information is cryptographically secured and immutable${NC}

${BOLD}${BLUE}Blockchain Benefits for Zakat Management:${NC}

• ${YELLOW}Transparency - All stakeholders can verify zakat collection and distribution${NC}
• ${YELLOW}Trust - Cryptographic proof ensures data cannot be altered retroactively${NC}
• ${YELLOW}Efficiency - Streamlined process reduces administrative overhead${NC}
• ${YELLOW}Accountability - Clear record of all transactions and distributions${NC}
• ${YELLOW}Collaboration - Multiple zakat organizations can work together on the same platform${NC}

${BOLD}${GREEN}Thank you for attending this demonstration!${NC}
"""
    eval "echo -e \"$summary_template\""
}
