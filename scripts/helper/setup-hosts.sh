#!/bin/bash
# Helper script to generate and update hosts file entries

# Source the configuration
source "$(dirname "$0")/../config/orgs-config.sh"

# Function to generate hosts file content
generate_hosts_content() {
    local content=""
    
    # Add orderer entries
    content+="$ORDERER_IP orderer.${ORDERER_DOMAIN}\n"
    content+="$ORDERER_IP tls-ca.${ORDERER_DOMAIN}\n"
    
    # Add organization entries
    for i in "${!ORGS[@]}"; do
        content+="${ORG_IPS[$i]} ${ORG_DOMAINS[$i]}\n"
        content+="${ORG_IPS[$i]} peer.${ORG_DOMAINS[$i]}\n"
        content+="${ORG_IPS[$i]} ca_${ORGS[$i],,}.${ORDERER_DOMAIN}\n"
    done
    
    echo -e "$content"
}

# Function to update hosts file on a remote machine
update_hosts_on_machine() {
    local ip=$1
    local hosts_content=$(generate_hosts_content)
    
    echo "🔄 Updating hosts file on $ip..."
    
    # Create a temporary file with the hosts entries
    echo -e "$hosts_content" > /tmp/fabric-hosts
    
    # Copy to remote machine
    scp /tmp/fabric-hosts fabricadmin@$ip:/tmp/
    
    # Update /etc/hosts on remote machine (requires sudo)
    ssh fabricadmin@$ip "echo '# Fabric Zakat Network' | sudo tee -a /etc/hosts > /dev/null"
    ssh fabricadmin@$ip "cat /tmp/fabric-hosts | sudo tee -a /etc/hosts > /dev/null"
    ssh fabricadmin@$ip "rm /tmp/fabric-hosts"
    
    # Clean up local temp file
    rm /tmp/fabric-hosts
    
    echo "✅ Updated hosts file on $ip"
}

# Update hosts files on all machines if running as main script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "🌐 Updating hosts files on all machines..."
    
    # Update orderer machine
    update_hosts_on_machine "$ORDERER_IP"
    
    # Update organization machines
    for ip in "${ORG_IPS[@]}"; do
        update_hosts_on_machine "$ip"
    done
    
    echo "✅ All hosts files updated successfully!"
    echo ""
    echo "Note: You may want to update the control machine's hosts file as well."
    echo "Here are the entries to add:"
    echo ""
    generate_hosts_content
fi
