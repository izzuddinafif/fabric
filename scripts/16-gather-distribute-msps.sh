#!/bin/bash
set -e

# Source helper scripts
source "$(dirname "$0")/helper/msp-utils.sh"

# The host we're running on (orderer)
ORDERER_HOST="orderer"

# Adjust paths to match orderer workspace structure
ORDERER_ORG_DIR="/home/fabricadmin/fabric/organizations/ordererOrganizations/fabriczakat.local"
LOCAL_ORG_DIR="/home/fabricadmin/fabric/organizations/peerOrganizations"

echo "🔄 Starting MSP artifacts collection and distribution..."

# Create local directories for peer organizations
echo "📁 Creating local directories for peer organizations..."
for ORG in "${ORGS[@]}"; do
    DOMAIN="${ORG}.fabriczakat.local"
    echo "  Creating local directory for $ORG MSP: $LOCAL_ORG_DIR/$DOMAIN"
    create_msp_structure "$LOCAL_ORG_DIR" "$ORG" "$DOMAIN" || exit 1
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
    
    # Check if the org MSP exists remotely
    if ! ssh_exec "$IP" "[ -d ~/$REMOTE_ORG_PATH/msp ]"; then
        echo "    ⛔ Error: MSP directory not found for $ORG at $IP. Skipping."
        continue
    fi
    echo "    ✅ Remote MSP directory found."
    
    # Copy organization MSP
    echo "    📄 Copying organization MSP for $ORG..."
    copy_org_msp "$IP" "$REMOTE_ORG_PATH" "$LOCAL_ORG_PATH" || continue
    echo "    ✅ Organization MSP copied."
    
    # Copy peer certificates
    PEER_NAME="peer.$DOMAIN"
    echo "    📄 Copying peer certificates for $PEER_NAME..."
    REMOTE_PEER_PATH="$REMOTE_ORG_PATH/peers/$PEER_NAME"
    LOCAL_PEER_PATH="$LOCAL_ORG_PATH/peers/$PEER_NAME"
    copy_peer_certs "$IP" "$REMOTE_PEER_PATH" "$LOCAL_PEER_PATH" || continue
    echo "    ✅ Peer certificates copied."
    
    # Copy admin certificates
    ADMIN_NAME="Admin@$DOMAIN"
    echo "    📄 Copying admin certificates for $ADMIN_NAME..."
    REMOTE_ADMIN_PATH="$REMOTE_ORG_PATH/users/$ADMIN_NAME"
    LOCAL_ADMIN_PATH="$LOCAL_ORG_PATH/users/$ADMIN_NAME"
    copy_admin_certs "$IP" "$REMOTE_ADMIN_PATH" "$LOCAL_ADMIN_PATH" || continue
    echo "    ✅ Admin certificates copied."
    
    echo "  ✅ MSP artifacts collection from $ORG completed."
done
echo "✅ Remote MSP artifacts gathered."

# Create distribution bundle
echo "📤 Preparing MSP distribution bundle (certs only)..."
TEMP_DIST_DIR="/tmp/org-msps-distribution-$$"
mkdir -p "$TEMP_DIST_DIR" || exit 1

# Create bundle with all MSPs
if create_msp_bundle "$TEMP_DIST_DIR" "$LOCAL_ORG_DIR" "$ORDERER_ORG_DIR" "${ORGS[@]}"; then
    echo "  ✅ Distribution bundle created successfully."
else
    echo "  ⛔ Failed to create distribution bundle."
    rm -rf "$TEMP_DIST_DIR"
    exit 1
fi

# Distribute the MSP bundle to each remote org
echo "📤 Distributing MSP bundle to remote organizations..."
for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    echo "  📤 Distributing to $ORG at $IP..."
    
    if distribute_msp_bundle "$TEMP_DIST_DIR/all-msps.tar.gz" "$IP"; then
        echo "  ✅ MSP distribution to $ORG completed."
    else
        echo "  ⛔ Failed to distribute MSPs to $ORG."
    fi
    echo "-----------------------------------------------------"
done
echo "✅ MSP bundle distributed to all remote organizations."

# Update orderer's own organizations directory
echo "📤 Distributing MSP bundle locally on the orderer machine..."
tar -xzf "$TEMP_DIST_DIR/all-msps.tar.gz" -C "/home/fabricadmin/fabric/organizations/" || exit 1
echo "✅ MSP distribution to orderer (local) completed."

# Cleanup
echo "🗑️ Cleaning up temporary distribution directory..."
rm -rf "$TEMP_DIST_DIR"

# Inform about the old directory
echo "ℹ️ NOTE: Following Fabric standards, we've consolidated all MSPs in the organizations/ directory."
echo "   The organizations-shared/ directory is no longer needed and can be removed."

if [ -d "/home/fabricadmin/fabric/organizations-shared" ]; then
    echo "   To clean up, you can remove it with: rm -rf /home/fabricadmin/fabric/organizations-shared"
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
