#!/bin/bash

# Source helper scripts
source "$(dirname "$0")/helper/ssh-utils.sh"

# Verify local files exist before attempting to copy
echo "🔎 Verifying local TLS files exist..."
if [ ! -f "$TLS_ROOT_CERT" ]; then echo "⛔ Local TLS root cert not found: $TLS_ROOT_CERT"; exit 1; fi
echo "  ✅ Local TLS root cert found."

# Verify TLS files for each org
for ORG in "${ORGS[@]}"; do
    echo "  🔎 Checking local files for $ORG:"
    TLS_CERT_SRC="$TLS_BASE/rcaadmin-$ORG/msp/signcerts/cert.pem"
    TLS_KEY_SRC="$TLS_BASE/rcaadmin-$ORG/msp/keystore/key.pem"
    if [ ! -f "$TLS_CERT_SRC" ]; then echo "  ⛔ Local TLS cert for $ORG not found: $TLS_CERT_SRC"; exit 1; fi
    if [ ! -f "$TLS_KEY_SRC" ]; then echo "  ⛔ Local TLS key for $ORG not found: $TLS_KEY_SRC"; exit 1; fi
    echo "    ✅ Local TLS cert and key for $ORG found."
done

# Verify TLS admin credentials exist locally
echo "  🔎 Checking local TLS admin credentials:"
if [ ! -f "$TLS_ADMIN_BASE/msp/signcerts/cert.pem" ]; then echo "  ⛔ Local TLS admin cert not found!"; exit 1; fi
if [ ! -d "$TLS_ADMIN_BASE/msp/keystore" ]; then echo "  ⛔ Local TLS admin keystore directory not found!"; exit 1; fi
if [ -z "$(find "$TLS_ADMIN_BASE/msp/keystore" -type f)" ]; then echo "  ⛔ Local TLS admin key file not found in keystore!"; exit 1; fi
echo "    ✅ Local TLS admin credentials found."
echo "✅ All required local files verified."

# Process each organization
for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    echo "🚀 Setting up TLS certs for $ORG at $IP..."

    # Step 1: Copy TLS CA root cert
    REMOTE_TLS_ROOT_CERT="~/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem"
    echo "  📁 Copying TLS root cert..."
    scp_file "$TLS_ROOT_CERT" "$IP" "$REMOTE_TLS_ROOT_CERT" "Failed to copy TLS root cert" || continue
    verify_remote_file "$IP" "$REMOTE_TLS_ROOT_CERT" || continue
    echo "  ✅ TLS root cert copied and verified."

    # Step 2: Copy TLS admin credentials
    echo "  📄 Setting up TLS admin credentials..."
    REMOTE_TLS_ADMIN="~/fabric/fabric-ca-client/tls-ca/tlsadmin/msp"
    
    # Check if TLS admin credentials already exist
    if ! verify_remote_dir "$IP" "$REMOTE_TLS_ADMIN"; then
        echo "    ℹ️ TLS admin credentials not found on $ORG VPS. Copying from orderer VPS..."
        scp_file "$TLS_ADMIN_BASE/msp" "$IP" "$REMOTE_TLS_ADMIN" "Failed to copy TLS admin credentials" || continue
        verify_remote_dir "$IP" "$REMOTE_TLS_ADMIN" || continue
        echo "    ✅ TLS admin credentials copied and verified."
    else
        echo "    ✅ TLS admin credentials already exist."
    fi

    # Step 3: Copy org-specific TLS cert + key
    echo "  📄 Setting up org-specific TLS credentials..."
    TLS_CERT_SRC="$TLS_BASE/rcaadmin-$ORG/msp/signcerts/cert.pem"
    TLS_KEY_SRC="$TLS_BASE/rcaadmin-$ORG/msp/keystore/key.pem"
    REMOTE_TLS_DIR="~/fabric/fabric-ca-server-$ORG/tls"
    
    # Copy certificate and key
    scp_file "$TLS_CERT_SRC" "$IP" "$REMOTE_TLS_DIR/cert.pem" "Failed to copy $ORG TLS cert" || continue
    scp_file "$TLS_KEY_SRC" "$IP" "$REMOTE_TLS_DIR/key.pem" "Failed to copy $ORG TLS key" || continue
    
    # Verify the files were copied properly
    verify_remote_file "$IP" "$REMOTE_TLS_DIR/cert.pem" || continue
    verify_remote_file "$IP" "$REMOTE_TLS_DIR/key.pem" || continue
    echo "  ✅ $ORG-specific TLS cert and key copied and verified."

    echo "✅ TLS setup completed for $ORG at $IP."
done

echo "✅ All operations finished."
