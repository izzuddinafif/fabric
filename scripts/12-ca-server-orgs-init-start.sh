#!/bin/bash
# Script 12: Initialize and Start CA Servers for Organizations

set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

echo "🚀 Starting CA Server initialization and startup for organizations..."

# Prepare the remote setup script by reading from template
SETUP_FILE="$(dirname "$0")/templates/ca-server-setup.sh"
if [ ! -f "$SETUP_FILE" ]; then
    echo "⛔ CA server setup template not found at: $SETUP_FILE"
    exit 1
fi
SETUP_SCRIPT=$(<"$SETUP_FILE")

# Process each organization
for i in "${!ORGS[@]}"; do
    IP=${ORG_IPS[$i]}
    ORG=${ORGS[$i]}
    CA_DIR="fabric/ca/${ORG,,}"
    CSR_HOSTNAME="${ORG,,}.fabriczakat.local"
    REMOTE_BIN_DIR="fabric/bin"
    BOOTSTRAP_USER="admin"
    BOOTSTRAP_PASS="adminpw"

    echo "----------------------------------------"
    echo "🏢 Processing ${ORG} CA Server ($IP)..."
    echo "----------------------------------------"

    # Create the setup script with variables substituted
    echo "📝 Creating setup script for $ORG..."
    SETUP_SCRIPT_WITH_VARS=$(eval "echo \"$SETUP_SCRIPT\"")

    # Execute the setup script via SSH
    echo "⚙️ Executing setup script on $IP..."
    ssh fabricadmin@$IP "bash -s" <<< "$SETUP_SCRIPT_WITH_VARS"
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to setup CA server for $ORG on $IP"
        exit 1
    fi

    echo "✅ CA Server initialized and started for $ORG"
done

echo "🎉 All CA Servers initialized and started successfully!"
echo ""
echo "Next Steps:"
echo "1. Run 'fabric-ca-client enroll' for bootstrap identities"
echo "2. Register and enroll additional identities"
echo "----------------------------------------"

exit 0
