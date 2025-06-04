#!/bin/bash

# Source helper scripts
source "$(dirname "$0")/helper/ssh-utils.sh"

echo "🧹 Starting comprehensive cleanup of all Fabric artifacts on remote org machines..."

for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    
    echo "🧹 Cleaning up all artifacts for $ORG at $IP..."
    
    # Show current state
    echo "  🔎 Current fabric directory contents before removal:"
    ssh_exec "$IP" "ls -la ~/fabric/"

    # Stop CA servers and clean up artifacts
    if clean_fabric_artifacts "$IP"; then
        echo "✅ Successfully cleaned up artifacts for $ORG at $IP."
    else
        echo "⛔ Failed during cleanup for $ORG at $IP. Check logs on the remote machine."
    fi
    echo "-----------------------------------------------------"
done

echo "🎉 All Fabric artifact cleanup attempts finished."
