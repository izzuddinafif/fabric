#!/bin/bash
set -e # Exit on error

# This script gathers MSP artifacts from remote org machines to the orderer machine
# and then distributes organization MSPs to each org (safely without private keys)

# Only include remote organization IPs - we're running this on the orderer
declare -A ORGS=(
    ["10.104.0.2"]="org1"
    ["10.104.0.4"]="org2"
)

# The host we're running on (orderer)
ORDERER_HOST="orderer"

# Adjust paths to match orderer workspace structure
ORDERER_ORG_DIR="/home/fabricadmin/fabric/organizations/ordererOrganizations/fabriczakat.local"
LOCAL_ORG_DIR="/home/fabricadmin/fabric/organizations/peerOrganizations"

echo "🔄 Starting MSP artifacts collection and distribution..."

# Create local directories to store org MSPs
echo "📁 Creating local directories for peer organizations..."
for ORG in "${ORGS[@]}"; do
    DOMAIN="${ORG}.fabriczakat.local"
    
    echo "  Creating local directory for $ORG MSP: $LOCAL_ORG_DIR/$DOMAIN"
    mkdir -p "$LOCAL_ORG_DIR/$DOMAIN/msp"
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to create directory $LOCAL_ORG_DIR/$DOMAIN/msp"; exit 1; fi
    mkdir -p "$LOCAL_ORG_DIR/$DOMAIN/peers"
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to create directory $LOCAL_ORG_DIR/$DOMAIN/peers"; exit 1; fi
    mkdir -p "$LOCAL_ORG_DIR/$DOMAIN/users"
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to create directory $LOCAL_ORG_DIR/$DOMAIN/users"; exit 1; fi
done
echo "✅ Local peer organization directories created."

# Gather MSP artifacts from each remote organization
echo "📥 Gathering MSP artifacts from remote organizations..."
for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    DOMAIN="${ORG}.fabriczakat.local"
    REMOTE_ORG_PATH="fabric/organizations/peerOrganizations/$DOMAIN"
    LOCAL_ORG_PATH="$LOCAL_ORG_DIR/$DOMAIN"
    
    echo "  📥 Gathering from $ORG at $IP..."
    
    # First, check if the org MSP exists remotely
    echo "    🔎 Checking for remote MSP directory: ~/$REMOTE_ORG_PATH/msp"
    REMOTE_MSP_EXISTS=$(ssh "fabricadmin@$IP" "[ -d ~/$REMOTE_ORG_PATH/msp ] && echo 'true' || echo 'false'")
    
    if [ "$REMOTE_MSP_EXISTS" = "false" ]; then
        echo "    ⛔ Error: MSP directory not found for $ORG at $IP (~/$REMOTE_ORG_PATH/msp). Skipping."
        continue # Consider exiting if this is critical: exit 1
    fi
    echo "    ✅ Remote MSP directory found."
    
    # Copy the organization MSP - without private keys
    echo "    📄 Copying organization MSP for $ORG (certs only)..."
    
    # Create local directories
    mkdir -p "$LOCAL_ORG_PATH/msp/"{cacerts,tlscacerts,admincerts}
    if [ $? -ne 0 ]; then echo "    ⛔ Failed to create local MSP subdirectories for $ORG"; exit 1; fi
    
    # Copy organization MSP files (suppress errors for non-existent files, check critical ones)
    scp "fabricadmin@$IP:~/$REMOTE_ORG_PATH/msp/config.yaml" "$LOCAL_ORG_PATH/msp/" 2>/dev/null || echo "    ⚠️ No remote config.yaml found for $ORG MSP"
    scp "fabricadmin@$IP:~/$REMOTE_ORG_PATH/msp/cacerts/*" "$LOCAL_ORG_PATH/msp/cacerts/" 2>/dev/null || echo "    ⚠️ No remote cacerts found for $ORG MSP"
    scp "fabricadmin@$IP:~/$REMOTE_ORG_PATH/msp/tlscacerts/*" "$LOCAL_ORG_PATH/msp/tlscacerts/" 2>/dev/null || echo "    ⚠️ No remote tlscacerts found for $ORG MSP"
    # Check if critical cacerts were copied
    if [ -z "$(ls -A $LOCAL_ORG_PATH/msp/cacerts/)" ]; then echo "    ⛔ Error: Failed to copy critical cacerts for $ORG MSP."; exit 1; fi
    echo "    ✅ Organization MSP certs copied."

    # Copy peer artifacts (only certificates, no private keys)
    PEER_NAME="peer.$DOMAIN"
    REMOTE_PEER_PATH="$REMOTE_ORG_PATH/peers/$PEER_NAME"
    LOCAL_PEER_PATH="$LOCAL_ORG_PATH/peers/$PEER_NAME"
    
    echo "    📄 Copying peer certificates for $PEER_NAME..."
    mkdir -p "$LOCAL_PEER_PATH/"{msp/cacerts,msp/tlscacerts,msp/signcerts,tls}
    if [ $? -ne 0 ]; then echo "    ⛔ Failed to create local peer subdirectories for $PEER_NAME"; exit 1; fi
    
    # Copy peer MSP files (suppress errors)
    scp "fabricadmin@$IP:~/$REMOTE_PEER_PATH/msp/config.yaml" "$LOCAL_PEER_PATH/msp/" 2>/dev/null || echo "    ⚠️ No remote peer config.yaml found"
    scp "fabricadmin@$IP:~/$REMOTE_PEER_PATH/msp/signcerts/*" "$LOCAL_PEER_PATH/msp/signcerts/" 2>/dev/null || echo "    ⚠️ No remote peer signcerts found"
    scp "fabricadmin@$IP:~/$REMOTE_PEER_PATH/msp/cacerts/*" "$LOCAL_PEER_PATH/msp/cacerts/" 2>/dev/null || echo "    ⚠️ No remote peer cacerts found"
    scp "fabricadmin@$IP:~/$REMOTE_PEER_PATH/msp/tlscacerts/*" "$LOCAL_PEER_PATH/msp/tlscacerts/" 2>/dev/null || echo "    ⚠️ No remote peer tlscacerts found"
    # Check critical peer certs
    if [ -z "$(ls -A $LOCAL_PEER_PATH/msp/signcerts/)" ]; then echo "    ⛔ Error: Failed to copy critical signcerts for $PEER_NAME."; exit 1; fi
    
    # Copy peer TLS certificates (suppress errors)
    scp "fabricadmin@$IP:~/$REMOTE_PEER_PATH/tls/server.crt" "$LOCAL_PEER_PATH/tls/" 2>/dev/null || echo "    ⚠️ No remote peer server.crt found"
    scp "fabricadmin@$IP:~/$REMOTE_PEER_PATH/tls/ca.crt" "$LOCAL_PEER_PATH/tls/" 2>/dev/null || echo "    ⚠️ No remote peer ca.crt found"
    # Check critical peer TLS certs
    if [ ! -f "$LOCAL_PEER_PATH/tls/server.crt" ]; then echo "    ⛔ Error: Failed to copy critical server.crt for $PEER_NAME."; exit 1; fi
    echo "    ✅ Peer certificates copied."

    # Copy admin certificates
    ADMIN_NAME_REMOTE="Admin@$DOMAIN" # Use correct remote admin name
    ADMIN_PATH="$REMOTE_ORG_PATH/users/$ADMIN_NAME_REMOTE"
    LOCAL_ADMIN_PATH="$LOCAL_ORG_PATH/users/$ADMIN_NAME_REMOTE" # Use correct local admin name
    
    echo "    📄 Copying admin certificates for $ADMIN_NAME_REMOTE..."
    mkdir -p "$LOCAL_ADMIN_PATH/"{msp/cacerts,msp/tlscacerts,msp/signcerts}
    if [ $? -ne 0 ]; then echo "    ⛔ Failed to create local admin subdirectories for $ADMIN_NAME_REMOTE"; exit 1; fi
    
    # Copy admin MSP files (suppress errors)
    scp "fabricadmin@$IP:~/$ADMIN_PATH/msp/config.yaml" "$LOCAL_ADMIN_PATH/msp/" 2>/dev/null || echo "    ⚠️ No remote admin config.yaml found"
    scp "fabricadmin@$IP:~/$ADMIN_PATH/msp/signcerts/*" "$LOCAL_ADMIN_PATH/msp/signcerts/" 2>/dev/null || echo "    ⚠️ No remote admin signcerts found"
    scp "fabricadmin@$IP:~/$ADMIN_PATH/msp/cacerts/*" "$LOCAL_ADMIN_PATH/msp/cacerts/" 2>/dev/null || echo "    ⚠️ No remote admin cacerts found"
    scp "fabricadmin@$IP:~/$ADMIN_PATH/msp/tlscacerts/*" "$LOCAL_ADMIN_PATH/msp/tlscacerts/" 2>/dev/null || echo "    ⚠️ No remote admin tlscacerts found"
    # Check critical admin certs
    if [ -z "$(ls -A $LOCAL_ADMIN_PATH/msp/signcerts/)" ]; then echo "    ⛔ Error: Failed to copy critical signcerts for $ADMIN_NAME_REMOTE."; exit 1; fi
    echo "    ✅ Admin certificates copied."
    
    echo "  ✅ MSP artifacts collection from $ORG completed."
done
echo "✅ All remote MSP artifacts gathered."

# Now distribute organization MSPs to each other (for mutual authentication)
echo "📤 Preparing MSP distribution bundle (certs only)..."

# First create a temporary directory with all orgs' MSPs
TEMP_DIST_DIR="/tmp/org-msps-distribution-$$" # Add PID for uniqueness
mkdir -p "$TEMP_DIST_DIR/ordererOrganizations" "$TEMP_DIST_DIR/peerOrganizations"
if [ $? -ne 0 ]; then echo "⛔ Failed to create temporary distribution directory $TEMP_DIST_DIR"; exit 1; fi

# Copy all peer organization MSPs to temp dir
echo "  📄 Copying peer organization MSPs to bundle..."
for ORG in "${ORGS[@]}"; do
    DOMAIN="${ORG}.fabriczakat.local"
    if [ -d "$LOCAL_ORG_DIR/$DOMAIN" ]; then
        cp -r "$LOCAL_ORG_DIR/$DOMAIN" "$TEMP_DIST_DIR/peerOrganizations/"
        if [ $? -ne 0 ]; then echo "  ⛔ Failed to copy $ORG MSP to bundle"; exit 1; fi
    else
        echo "  ⚠️ Warning: Local directory for $ORG not found ($LOCAL_ORG_DIR/$DOMAIN), skipping copy to bundle."
    fi
done
echo "  ✅ Peer organization MSPs added to bundle."

# Copy orderer org MSP to temp dir - SAFELY WITHOUT PRIVATE KEYS
echo "  📄 Copying orderer organization MSP to bundle (certs only)..."
ORDERER_DOMAIN="fabriczakat.local"
ORDERER_TEMP_DIR="$TEMP_DIST_DIR/ordererOrganizations/$ORDERER_DOMAIN"

# Create directory structure for orderer MSP
mkdir -p "$ORDERER_TEMP_DIR/msp/"{cacerts,tlscacerts} \
         "$ORDERER_TEMP_DIR/orderers/orderer.$ORDERER_DOMAIN/"{msp/cacerts,msp/tlscacerts,msp/signcerts,tls} \
         "$ORDERER_TEMP_DIR/users/Admin@$ORDERER_DOMAIN/"{msp/cacerts,msp/tlscacerts,msp/signcerts}
if [ $? -ne 0 ]; then echo "  ⛔ Failed to create temporary orderer directory structure"; exit 1; fi

# Copy orderer organization MSP files (only certs, no private keys, check existence)
if [ -f "$ORDERER_ORG_DIR/msp/config.yaml" ]; then cp "$ORDERER_ORG_DIR/msp/config.yaml" "$ORDERER_TEMP_DIR/msp/"; else echo "  ⚠️ No orderer organization config.yaml found"; fi
if [ -d "$ORDERER_ORG_DIR/msp/cacerts" ]; then cp -r "$ORDERER_ORG_DIR/msp/cacerts"/* "$ORDERER_TEMP_DIR/msp/cacerts/"; else echo "  ⚠️ No orderer org cacerts found"; fi
if [ -d "$ORDERER_ORG_DIR/msp/tlscacerts" ]; then cp -r "$ORDERER_ORG_DIR/msp/tlscacerts"/* "$ORDERER_TEMP_DIR/msp/tlscacerts/"; else echo "  ⚠️ No orderer org tlscacerts found"; fi
if [ -z "$(ls -A $ORDERER_TEMP_DIR/msp/cacerts/)" ]; then echo "  ⛔ Error: Failed to copy critical orderer org cacerts to bundle."; exit 1; fi

# Copy orderer node certificates (no private keys, check existence)
ORDERER_NODE="orderer.$ORDERER_DOMAIN"
if [ -f "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/msp/config.yaml" ]; then cp "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/msp/config.yaml" "$ORDERER_TEMP_DIR/orderers/$ORDERER_NODE/msp/"; fi
if [ -d "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/msp/cacerts" ]; then cp -r "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/msp/cacerts"/* "$ORDERER_TEMP_DIR/orderers/$ORDERER_NODE/msp/cacerts/"; fi
if [ -d "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/msp/tlscacerts" ]; then cp -r "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/msp/tlscacerts"/* "$ORDERER_TEMP_DIR/orderers/$ORDERER_NODE/msp/tlscacerts/"; fi
if [ -d "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/msp/signcerts" ]; then cp -r "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/msp/signcerts"/* "$ORDERER_TEMP_DIR/orderers/$ORDERER_NODE/msp/signcerts/"; fi
if [ -z "$(ls -A $ORDERER_TEMP_DIR/orderers/$ORDERER_NODE/msp/signcerts/)" ]; then echo "  ⛔ Error: Failed to copy critical orderer node signcerts to bundle."; exit 1; fi

# Copy orderer TLS certificates (no private keys, check existence)
if [ -f "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/tls/server.crt" ]; then cp "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/tls/server.crt" "$ORDERER_TEMP_DIR/orderers/$ORDERER_NODE/tls/"; fi
if [ -f "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/tls/ca.crt" ]; then cp "$ORDERER_ORG_DIR/orderers/$ORDERER_NODE/tls/ca.crt" "$ORDERER_TEMP_DIR/orderers/$ORDERER_NODE/tls/"; fi
if [ ! -f "$ORDERER_TEMP_DIR/orderers/$ORDERER_NODE/tls/server.crt" ]; then echo "  ⛔ Error: Failed to copy critical orderer node server.crt to bundle."; exit 1; fi

# Copy orderer admin certificates (no private keys, check existence)
ADMIN_NAME="Admin@$ORDERER_DOMAIN"
if [ -f "$ORDERER_ORG_DIR/users/$ADMIN_NAME/msp/config.yaml" ]; then cp "$ORDERER_ORG_DIR/users/$ADMIN_NAME/msp/config.yaml" "$ORDERER_TEMP_DIR/users/$ADMIN_NAME/msp/"; fi
if [ -d "$ORDERER_ORG_DIR/users/$ADMIN_NAME/msp/cacerts" ]; then cp -r "$ORDERER_ORG_DIR/users/$ADMIN_NAME/msp/cacerts"/* "$ORDERER_TEMP_DIR/users/$ADMIN_NAME/msp/cacerts/"; fi
if [ -d "$ORDERER_ORG_DIR/users/$ADMIN_NAME/msp/tlscacerts" ]; then cp -r "$ORDERER_ORG_DIR/users/$ADMIN_NAME/msp/tlscacerts"/* "$ORDERER_TEMP_DIR/users/$ADMIN_NAME/msp/tlscacerts/"; fi
if [ -d "$ORDERER_ORG_DIR/users/$ADMIN_NAME/msp/signcerts" ]; then cp -r "$ORDERER_ORG_DIR/users/$ADMIN_NAME/msp/signcerts"/* "$ORDERER_TEMP_DIR/users/$ADMIN_NAME/msp/signcerts/"; fi
if [ -z "$(ls -A $ORDERER_TEMP_DIR/users/$ADMIN_NAME/msp/signcerts/)" ]; then echo "  ⛔ Error: Failed to copy critical orderer admin signcerts to bundle."; exit 1; fi
echo "  ✅ Orderer organization MSP added to bundle."

# Create a tar file for easy distribution
echo "  📦 Creating distribution archive..."
# Create archive from parent directory to avoid the "." issue
tar -czf "/tmp/all-msps-$$.tar.gz" -C "$TEMP_DIST_DIR" ordererOrganizations peerOrganizations
# Then move it to the temp dir
mv "/tmp/all-msps-$$.tar.gz" "$TEMP_DIST_DIR/all-msps.tar.gz"
if [ $? -ne 0 ]; then echo "  ⛔ Failed to create distribution archive"; exit 1; fi
echo "  ✅ Distribution archive created: $TEMP_DIST_DIR/all-msps.tar.gz"

# Distribute the MSP archive to each remote org
echo "📤 Distributing MSP bundle to remote organizations..."
for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    
    echo "  📤 Distributing to $ORG at $IP..."
    
    # Copy the archive
    echo "    📄 Copying archive..."
    scp "$TEMP_DIST_DIR/all-msps.tar.gz" "fabricadmin@$IP:~/fabric/"
    if [ $? -ne 0 ]; then echo "    ⛔ Failed to copy archive to $IP"; continue; fi # Continue to next org
    
    # Extract the archive on the remote host directly to organizations directory
    echo "    📦 Extracting archive on remote host..."
    ssh "fabricadmin@$IP" "mkdir -p ~/fabric/organizations && tar -xzf ~/fabric/all-msps.tar.gz -C ~/fabric/organizations/"
    if [ $? -ne 0 ]; then echo "    ⛔ Failed to extract archive on $IP"; continue; fi # Continue to next org
    
    # Cleanup the archive on remote host
    echo "    🗑️ Cleaning up remote archive..."
    ssh "fabricadmin@$IP" "rm ~/fabric/all-msps.tar.gz"
    if [ $? -ne 0 ]; then echo "    ⚠️ Warning: Failed to remove remote archive on $IP"; fi # Non-critical
    
    echo "  ✅ MSP distribution to $ORG completed."
done
echo "✅ MSP bundle distributed to all remote organizations."

# Also update the orderer's own organizations directory
echo "📤 Distributing MSP bundle locally on the orderer machine..."
tar -xzf "$TEMP_DIST_DIR/all-msps.tar.gz" -C "/home/fabricadmin/fabric/organizations/"
if [ $? -ne 0 ]; then echo "⛔ Failed to extract archive locally"; exit 1; fi
echo "✅ MSP distribution to orderer (local) completed."

# Cleanup the temporary directory
echo "🗑️ Cleaning up temporary distribution directory..."
rm -rf "$TEMP_DIST_DIR"
if [ $? -ne 0 ]; then echo "⚠️ Warning: Failed to remove temporary directory $TEMP_DIST_DIR"; fi
echo "✅ Cleanup complete."

# Inform about the change in approach
echo "ℹ️ NOTE: Following Fabric standards, we've consolidated all MSPs in the organizations/ directory."
echo "   The organizations-shared/ directory is no longer needed and can be removed."

# Offer to remove the organizations-shared directory if it exists
if [ -d "/home/fabricadmin/fabric/organizations-shared" ]; then
    echo "   To clean up, you can remove it with: rm -rf /home/fabricadmin/fabric/organizations-shared"
    
    # Also help remove the directory from remote orgs if needed
    echo "   To remove it from remote organizations as well, you can run:"
    for IP in "${!ORGS[@]}"; do
        echo "   ssh fabricadmin@$IP 'rm -rf ~/fabric/organizations-shared'"
    done
fi

echo "🎉 MSP artifacts collection and distribution completed successfully!"
echo ""
echo "📊 Summary:"
echo "  - Organization MSPs have been collected to this machine at: $LOCAL_ORG_DIR"
echo "  - All organization MSPs have been distributed to each org in their standard organizations directory"
echo ""
echo "⚠️ Security Note: Private keys have been excluded from the distribution process"
echo "    Only public certificates necessary for mutual authentication are shared"
echo ""
echo "You can now use these artifacts to create the genesis block and channel configurations."