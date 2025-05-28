#!/bin/bash

# This script performs a comprehensive cleanup of all Fabric artifacts on remote organization machines

declare -A ORGS=(
    ["10.104.0.2"]="org1"
    ["10.104.0.4"]="org2"
)

echo "🧹 Starting comprehensive cleanup of all Fabric artifacts on remote org machines..."

for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    
    echo "🧹 Cleaning up all artifacts for $ORG at $IP..."
    
    ssh fabricadmin@$IP << EOF
echo "  🚀 Starting cleanup on $ORG machine ($IP)..."
set +e # Allow commands to fail without exiting immediately for cleanup steps

# First, stop any running CA servers using an explicit find
echo "  🛑 Stopping any running CA servers..."
CA_STOPPED=0
for PID_FILE in \$(find ~/fabric -name "fabric-ca-server-*.pid" 2>/dev/null); do
    if [ -f "\$PID_FILE" ]; then
        echo "    Found PID file: \$PID_FILE"
        PID=\$(cat "\$PID_FILE")
        if ps -p \$PID > /dev/null; then
            echo "    Killing process \$PID..."
            kill \$PID
            sleep 1 # Give it a moment
            if ps -p \$PID > /dev/null; then
                 echo "    Process \$PID still running, attempting force kill..."
                 kill -9 \$PID
                 sleep 1
            fi
            if ! ps -p \$PID > /dev/null; then
                 echo "    ✅ Process \$PID stopped."
                 rm -f "\$PID_FILE" # Remove PID file after stopping
                 CA_STOPPED=1
            else
                 echo "    ⛔ Failed to stop process \$PID."
            fi
        else
            echo "    Process \$PID from \$PID_FILE is not running."
            rm -f "\$PID_FILE" # Remove stale PID file
        fi
    fi
done
if [ \$CA_STOPPED -eq 0 ]; then
    echo "    ℹ️ No running CA servers found via PID files."
fi

# Force kill any remaining fabric-ca-server processes just in case
echo "  🛑 Force killing any remaining fabric-ca-server processes..."
pkill -9 -f fabric-ca-server
if [ \$? -eq 0 ]; then
    echo "    ✅ Force kill command executed (may or may not have killed processes)."
else
    echo "    ℹ️ No remaining fabric-ca-server processes found to kill."
fi

# Verify all fabric-ca-server processes are gone
echo "  🔎 Verifying all fabric-ca-server processes are terminated..."
if pgrep -l -f fabric-ca-server; then
    echo "    ⛔ Warning: fabric-ca-server processes still seem to be running!"
else
    echo "    ✅ Verification complete: No fabric-ca-server processes found."
fi

# List what's in the fabric directory before removal
echo "  🔎 Current fabric directory contents before removal:"
ls -la ~/fabric/

# Remove the entire fabric directory with verbose output
echo "  🗑️ Removing entire fabric directory (~/fabric)..."
rm -rfv ~/fabric/
RM_EXIT_CODE=\$?

# Verify removal
echo "  🔎 Verifying fabric directory removal..."
if [ -d ~/fabric ]; then
    echo "    ⛔ Error: fabric directory still exists after rm -rf!"
    ls -la ~/fabric/
    exit 1 # Exit the heredoc script with error
else
    if [ \$RM_EXIT_CODE -eq 0 ]; then
        echo "    ✅ Success: fabric directory has been removed."
    else
        echo "    ⛔ Error: rm command failed with exit code \$RM_EXIT_CODE, but directory seems gone?"
        # Don't exit, maybe it partially failed but is gone now
    fi
fi

echo "  ✅ Comprehensive cleanup completed for $ORG on $IP."
EOF

    # Check the exit status of the SSH command
    if [ $? -eq 0 ]; then
        echo "✅ Successfully cleaned up artifacts for $ORG at $IP."
    else
        echo "⛔ Failed during cleanup for $ORG at $IP. Check logs on the remote machine."
    fi
    echo "-----------------------------------------------------"

done

echo "🎉 All Fabric artifact cleanup attempts finished."