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

# Function to log with timestamps
cleanup_log() {
    echo "  \$(date '+%H:%M:%S') - \$1"
}

cleanup_log "🔎 Checking Docker availability..."
if ! command -v docker &> /dev/null; then
    cleanup_log "⚠️ Docker not found, skipping Docker cleanup steps."
    DOCKER_AVAILABLE=false
else
    cleanup_log "✅ Docker found, proceeding with Docker cleanup."
    DOCKER_AVAILABLE=true
fi

# Docker cleanup section
if [ "\$DOCKER_AVAILABLE" = true ]; then
    cleanup_log "🐳 Starting Docker cleanup..."
    
    # Check if Docker daemon is running
    if ! docker info &>/dev/null; then
        cleanup_log "⚠️ Docker daemon not running, skipping Docker cleanup."
    else
        cleanup_log "✅ Docker daemon is running."
        
        # Stop all running containers
        cleanup_log "🛑 Stopping all running containers..."
        RUNNING_CONTAINERS=\$(docker ps -q)
        if [ -n "\$RUNNING_CONTAINERS" ]; then
            cleanup_log "  Found \$(echo \$RUNNING_CONTAINERS | wc -w) running containers, stopping..."
            docker stop \$RUNNING_CONTAINERS
            if [ \$? -eq 0 ]; then
                cleanup_log "  ✅ All running containers stopped."
            else
                cleanup_log "  ⚠️ Some containers may not have stopped cleanly."
            fi
        else
            cleanup_log "  ℹ️ No running containers found."
        fi
        
        # Remove all containers (running and stopped)
        cleanup_log "🗑️ Removing all containers..."
        ALL_CONTAINERS=\$(docker ps -aq)
        if [ -n "\$ALL_CONTAINERS" ]; then
            cleanup_log "  Found \$(echo \$ALL_CONTAINERS | wc -w) total containers, removing..."
            docker rm -f \$ALL_CONTAINERS
            if [ \$? -eq 0 ]; then
                cleanup_log "  ✅ All containers removed."
            else
                cleanup_log "  ⚠️ Some containers may not have been removed."
            fi
        else
            cleanup_log "  ℹ️ No containers found to remove."
        fi
        
        # Remove all volumes
        cleanup_log "💾 Removing all Docker volumes..."
        ALL_VOLUMES=\$(docker volume ls -q)
        if [ -n "\$ALL_VOLUMES" ]; then
            cleanup_log "  Found \$(echo \$ALL_VOLUMES | wc -w) volumes, removing..."
            docker volume rm \$ALL_VOLUMES 2>/dev/null
            cleanup_log "  ✅ Volume removal attempted."
        else
            cleanup_log "  ℹ️ No volumes found to remove."
        fi
        
        # Additional volume cleanup
        cleanup_log "🧹 Running volume prune..."
        docker volume prune -f
        cleanup_log "  ✅ Volume prune completed."
        
        # Remove all networks (except defaults)
        cleanup_log "🌐 Removing custom Docker networks..."
        CUSTOM_NETWORKS=\$(docker network ls --format "{{.ID}} {{.Name}}" | grep -v -E "(bridge|host|none)" | awk '{print \$1}')
        if [ -n "\$CUSTOM_NETWORKS" ]; then
            cleanup_log "  Found \$(echo \$CUSTOM_NETWORKS | wc -w) custom networks, removing..."
            docker network rm \$CUSTOM_NETWORKS 2>/dev/null
            cleanup_log "  ✅ Custom network removal attempted."
        else
            cleanup_log "  ℹ️ No custom networks found to remove."
        fi
        
        # Remove all images
        cleanup_log "🖼️ Removing all Docker images..."
        ALL_IMAGES=\$(docker images -q)
        if [ -n "\$ALL_IMAGES" ]; then
            cleanup_log "  Found \$(echo \$ALL_IMAGES | wc -w) images, removing..."
            docker rmi -f \$ALL_IMAGES 2>/dev/null
            cleanup_log "  ✅ Image removal attempted."
        else
            cleanup_log "  ℹ️ No images found to remove."
        fi
        
        # System-wide Docker cleanup
        cleanup_log "🧽 Running Docker system prune..."
        docker system prune -a -f --volumes
        cleanup_log "  ✅ Docker system prune completed."
        
        # Final verification
        cleanup_log "🔎 Verifying Docker cleanup..."
        REMAINING_CONTAINERS=\$(docker ps -aq | wc -l)
        REMAINING_VOLUMES=\$(docker volume ls -q | wc -l)
        REMAINING_IMAGES=\$(docker images -q | wc -l)
        cleanup_log "  Final state: \$REMAINING_CONTAINERS containers, \$REMAINING_VOLUMES volumes, \$REMAINING_IMAGES images"
        
        if [ "\$REMAINING_CONTAINERS" -eq 0 ] && [ "\$REMAINING_VOLUMES" -eq 0 ]; then
            cleanup_log "  ✅ Docker cleanup successful - no containers or volumes remain."
        else
            cleanup_log "  ⚠️ Some Docker artifacts may still remain."
        fi
    fi
fi

# Original CA cleanup section
cleanup_log "🏭 Starting CA server cleanup..."

# First, stop any running CA servers using an explicit find
cleanup_log "🛑 Stopping any running CA servers..."
CA_STOPPED=0
for PID_FILE in \$(find ~/fabric -name "fabric-ca-server-*.pid" 2>/dev/null); do
    if [ -f "\$PID_FILE" ]; then
        cleanup_log "  Found PID file: \$PID_FILE"
        PID=\$(cat "\$PID_FILE")
        if ps -p \$PID > /dev/null 2>&1; then
            cleanup_log "  Killing process \$PID..."
            sudo kill \$PID
            sleep 1 # Give it a moment
            if ps -p \$PID > /dev/null 2>&1; then
                 cleanup_log "  Process \$PID still running, attempting force kill..."
                 sudo kill -9 \$PID
                 sleep 1
            fi
            if ! ps -p \$PID > /dev/null 2>&1; then
                 cleanup_log "  ✅ Process \$PID stopped."
                 rm -f "\$PID_FILE" # Remove PID file after stopping
                 CA_STOPPED=1
            else
                 cleanup_log "  ⛔ Failed to stop process \$PID."
            fi
        else
            cleanup_log "  Process \$PID from \$PID_FILE is not running."
            rm -f "\$PID_FILE" # Remove stale PID file
        fi
    fi
done
if [ \$CA_STOPPED -eq 0 ]; then
    cleanup_log "ℹ️ No running CA servers found via PID files."
fi

# Force kill any remaining fabric-ca-server processes just in case
cleanup_log "🛑 Force killing any remaining fabric-ca-server processes..."
if pgrep -f fabric-ca-server > /dev/null; then
    sudo pkill -9 -f fabric-ca-server
    cleanup_log "✅ Force kill command executed for fabric-ca-server processes."
    sleep 1
else
    cleanup_log "ℹ️ No fabric-ca-server processes found to kill."
fi

# Verify all fabric-ca-server processes are gone
cleanup_log "🔎 Verifying all fabric-ca-server processes are terminated..."
if pgrep -l -f fabric-ca-server; then
    cleanup_log "⛔ Warning: fabric-ca-server processes still seem to be running!"
else
    cleanup_log "✅ Verification complete: No fabric-ca-server processes found."
fi

# Fabric directory cleanup section
cleanup_log "📁 Starting Fabric directory cleanup..."

# Check if fabric directory exists
if [ ! -d ~/fabric ]; then
    cleanup_log "ℹ️ Fabric directory ~/fabric does not exist, skipping removal."
else
    # List what's in the fabric directory before removal
    cleanup_log "🔎 Current fabric directory contents before removal:"
    ls -la ~/fabric/ 2>/dev/null | head -10  # Limit output to first 10 lines
    
    # Remove the entire fabric directory with verbose output (but limit verbosity)
    cleanup_log "🗑️ Removing entire fabric directory (~/fabric)..."
    sudo rm -rf ~/fabric/
    RM_EXIT_CODE=\$?
    
    # Verify removal
    cleanup_log "🔎 Verifying fabric directory removal..."
    if [ -d ~/fabric ]; then
        cleanup_log "⛔ Error: fabric directory still exists after rm -rf!"
        ls -la ~/fabric/ 2>/dev/null | head -5
        exit 1 # Exit the heredoc script with error
    else
        if [ \$RM_EXIT_CODE -eq 0 ]; then
            cleanup_log "✅ Success: fabric directory has been removed."
        else
            cleanup_log "⛔ Error: rm command failed with exit code \$RM_EXIT_CODE, but directory seems gone?"
            # Don't exit, maybe it partially failed but is gone now
        fi
    fi
fi

# Clean up any remaining fabric-related processes
cleanup_log "🔍 Checking for any remaining fabric-related processes..."
FABRIC_PROCESSES=\$(pgrep -f -l fabric 2>/dev/null || true)
if [ -n "\$FABRIC_PROCESSES" ]; then
    cleanup_log "⚠️ Found remaining fabric processes:"
    echo "\$FABRIC_PROCESSES" | while read line; do cleanup_log "  \$line"; done
    cleanup_log "🛑 Attempting to kill remaining fabric processes..."
    sudo pkill -9 -f fabric
    sleep 1
    cleanup_log "✅ Fabric process cleanup attempted."
else
    cleanup_log "✅ No remaining fabric processes found."
fi

# Clean up any fabric-related systemd services (if any)
cleanup_log "🎛️ Checking for fabric-related systemd services..."
FABRIC_SERVICES=\$(systemctl list-units --all | grep fabric | awk '{print \$1}' || true)
if [ -n "\$FABRIC_SERVICES" ]; then
    cleanup_log "⚠️ Found fabric-related services, attempting to stop and disable..."
    for service in \$FABRIC_SERVICES; do
        cleanup_log "  Stopping \$service..."
        sudo systemctl stop "\$service" 2>/dev/null || true
        sudo systemctl disable "\$service" 2>/dev/null || true
    done
    cleanup_log "✅ Fabric service cleanup attempted."
else
    cleanup_log "ℹ️ No fabric-related systemd services found."
fi

# Final verification
cleanup_log "🏁 Final verification..."
REMAINING_FABRIC_PROCESSES=\$(pgrep -f fabric | wc -l)
FABRIC_DIR_EXISTS=\$([ -d ~/fabric ] && echo "yes" || echo "no")

cleanup_log "📊 Cleanup summary:"
cleanup_log "  - Remaining fabric processes: \$REMAINING_FABRIC_PROCESSES"
cleanup_log "  - Fabric directory exists: \$FABRIC_DIR_EXISTS"

if [ "\$DOCKER_AVAILABLE" = true ]; then
    FINAL_CONTAINERS=\$(docker ps -aq 2>/dev/null | wc -l)
    FINAL_VOLUMES=\$(docker volume ls -q 2>/dev/null | wc -l)
    cleanup_log "  - Docker containers: \$FINAL_CONTAINERS"
    cleanup_log "  - Docker volumes: \$FINAL_VOLUMES"
fi

cleanup_log "✅ Comprehensive cleanup completed for $ORG on $IP."
EOF

    # Check the exit status of the SSH command
    if [ $? -eq 0 ]; then
        echo "✅ Successfully cleaned up artifacts for $ORG at $IP."
    else
        echo "⛔ Failed during cleanup for $ORG at $IP. Check logs on the remote machine."
    fi
    echo "-----------------------------------------------------"

done