#!/bin/bash

declare -A ORGS=(
    ["10.104.0.2"]="org1"
    ["10.104.0.4"]="org2"
)

TLS_ROOT_CERT=~/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem
TLS_BASE=~/fabric/fabric-ca-client/tls-ca
TLS_ADMIN_BASE=~/fabric/fabric-ca-client/tls-ca/tlsadmin

# Verify local files exist before attempting to copy
echo "🔎 Verifying local TLS files exist..."
if [ ! -f "$TLS_ROOT_CERT" ]; then echo "⛔ Local TLS root cert not found: $TLS_ROOT_CERT"; exit 1; fi
echo "  ✅ Local TLS root cert found."

for ORG in "${ORGS[@]}"; do
    echo "  🔎 Checking local files for $ORG:"
    TLS_CERT_SRC="$TLS_BASE/rcaadmin-$ORG/msp/signcerts/cert.pem"
    TLS_KEY_SRC="$TLS_BASE/rcaadmin-$ORG/msp/keystore/key.pem"
    if [ ! -f "$TLS_CERT_SRC" ]; then echo "  ⛔ Local TLS cert for $ORG not found: $TLS_CERT_SRC"; exit 1; fi
    if [ ! -f "$TLS_KEY_SRC" ]; then echo "  ⛔ Local TLS key for $ORG not found: $TLS_KEY_SRC"; exit 1; fi
    echo "    ✅ Local TLS cert and key for $ORG found."
done

# Also verify TLS admin credentials exist locally
echo "  🔎 Checking local TLS admin credentials:"
if [ ! -f "$TLS_ADMIN_BASE/msp/signcerts/cert.pem" ]; then echo "  ⛔ Local TLS admin cert not found!"; exit 1; fi
if [ ! -d "$TLS_ADMIN_BASE/msp/keystore" ]; then echo "  ⛔ Local TLS admin keystore directory not found!"; exit 1; fi
if [ -z "$(find "$TLS_ADMIN_BASE/msp/keystore" -type f)" ]; then echo "  ⛔ Local TLS admin key file not found in keystore!"; exit 1; fi
echo "    ✅ Local TLS admin credentials found."
echo "✅ All required local files verified."


for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    echo "🚀 Setting up TLS certs for $ORG at $IP..."

    # Step 1: Copy TLS CA root cert
    echo "  📁 Ensuring remote directory exists: ~/fabric/fabric-ca-client/tls-root-cert"
    ssh "fabricadmin@$IP" "mkdir -p ~/fabric/fabric-ca-client/tls-root-cert"
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to create remote directory for root cert on $IP."; continue; fi
    echo "  📄 Copying TLS root cert to $IP..."
    scp "$TLS_ROOT_CERT" "fabricadmin@$IP:~/fabric/fabric-ca-client/tls-root-cert/"
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to copy TLS root cert to $IP."; continue; fi
    
    # Verify the root cert was copied
    echo "  🔎 Verifying remote TLS root cert on $IP..."
    ssh "fabricadmin@$IP" "ls -la ~/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" > /dev/null 2>&1
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to verify TLS root cert on $IP."; continue; fi
    echo "  ✅ TLS root cert copied and verified on $IP."

    # Step 2: Copy TLS admin credentials 
    echo "  📄 Checking/Copying TLS admin credentials to $ORG VPS ($IP)..."
    
    # Check if TLS admin credentials exist on org VPS
    TLS_ADMIN_EXISTS=$(ssh "fabricadmin@$IP" "[ -f ~/fabric/fabric-ca-client/tls-ca/tlsadmin/msp/signcerts/cert.pem ] && echo 'true' || echo 'false'")
    
    if [ "$TLS_ADMIN_EXISTS" = "false" ]; then
        echo "    ℹ️ TLS admin credentials not found on $ORG VPS. Copying from orderer VPS..."
        
        # Ensure target directory exists
        ssh "fabricadmin@$IP" "mkdir -p ~/fabric/fabric-ca-client/tls-ca/tlsadmin/msp"
        if [ $? -ne 0 ]; then echo "    ⛔ Failed to create remote directory for TLS admin creds on $IP."; continue; fi
        
        # Copy entire tlsadmin msp directory structure from orderer to org VPS
        scp -r "$TLS_ADMIN_BASE/msp"/* "fabricadmin@$IP:~/fabric/fabric-ca-client/tls-ca/tlsadmin/msp/"
        if [ $? -ne 0 ]; then echo "    ⛔ Failed to copy TLS admin credentials to $IP."; continue; fi
        
        # Verify the copy was successful
        TLS_ADMIN_VERIFY=$(ssh "fabricadmin@$IP" "[ -f ~/fabric/fabric-ca-client/tls-ca/tlsadmin/msp/signcerts/cert.pem ] && echo 'true' || echo 'false'")
        
        if [ "$TLS_ADMIN_VERIFY" = "true" ]; then
            echo "    ✅ Successfully copied and verified TLS admin credentials to $ORG VPS."
        else
            echo "    ⛔ Error: Failed to verify copied TLS admin credentials on $ORG VPS. Aborting for this org."
            continue # Skip to next org
        fi
    else
        echo "    ✅ TLS admin credentials already exist on $ORG VPS. Skipping copy."
    fi

    # Step 3: Copy org-specific TLS cert + key
    TLS_CERT_SRC="$TLS_BASE/rcaadmin-$ORG/msp/signcerts/cert.pem"
    TLS_KEY_SRC="$TLS_BASE/rcaadmin-$ORG/msp/keystore/key.pem"
    
    # Local source files already verified at the beginning

    # Create target directory on remote host
    echo "  📁 Ensuring remote directory exists: ~/fabric/fabric-ca-server-$ORG/tls"
    ssh "fabricadmin@$IP" "mkdir -p ~/fabric/fabric-ca-server-$ORG/tls"
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to create remote directory for org-specific TLS on $IP."; continue; fi
    
    # Copy certificate and key
    echo "  📄 Copying $ORG-specific TLS cert and key to $IP..."
    scp "$TLS_CERT_SRC" "fabricadmin@$IP:~/fabric/fabric-ca-server-$ORG/tls/cert.pem"
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to copy $ORG TLS cert to $IP."; continue; fi
    scp "$TLS_KEY_SRC" "fabricadmin@$IP:~/fabric/fabric-ca-server-$ORG/tls/key.pem"
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to copy $ORG TLS key to $IP."; continue; fi

    # Verify the files were copied properly
    echo "  🔎 Verifying $ORG-specific TLS cert and key on $IP..."
    ssh "fabricadmin@$IP" "ls -la ~/fabric/fabric-ca-server-$ORG/tls/cert.pem ~/fabric/fabric-ca-server-$ORG/tls/key.pem" > /dev/null 2>&1
    if [ $? -ne 0 ]; then echo "  ⛔ Failed to verify $ORG TLS cert/key on $IP."; continue; fi
    echo "  ✅ $ORG-specific TLS cert and key copied and verified on $IP."

    echo "✅ TLS setup completed for $ORG at $IP."
done

echo "✅ All operations finished."
