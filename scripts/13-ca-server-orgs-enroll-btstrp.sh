#!/bin/bash

# Source helper scripts
source "$(dirname "$0")/helper/ssh-utils.sh"

for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    BOOTSTRAP_USER="btstrp-${ORG}"
    BOOTSTRAP_PASS="${ORG}${BOOTSTRAP_PASS_SUFFIX}"
    MSP_DIR="${ORG}-ca/${BOOTSTRAP_USER}/msp"
    CA_HOST="ca.${ORG}.fabriczakat.local"
    CA_PORT="7054"
    HOME_DIR="/home/fabricadmin/fabric/fabric-ca-client"
    
    echo "Processing bootstrap user for $ORG at $IP..."
    
    # Check for remote TLS certificate
    REMOTE_TLS_CERT_PATH="/home/fabricadmin/fabric/fabric-ca-server-${ORG}/tls/cert.pem"
    echo "  🔎 Checking for remote TLS certificate..."
    if ! verify_remote_file "$IP" "$REMOTE_TLS_CERT_PATH"; then
        echo "  ⛔ Error: TLS certificate not found at $REMOTE_TLS_CERT_PATH on remote machine $IP. Cannot proceed."
        continue
    fi
    echo "  ✅ Remote TLS certificate found."
    
    # Check for existing enrollment
    echo "  🔎 Checking for existing enrollment for $BOOTSTRAP_USER on $IP..."
    ENROLL_CHECK_SCRIPT="""
        [ -f $HOME_DIR/$MSP_DIR/signcerts/cert.pem ] && [ -f $HOME_DIR/$MSP_DIR/keystore/key.pem ] && echo 'true' || echo 'false'
    """
    ENROLL_EXISTS=$(ssh_exec "$IP" "$ENROLL_CHECK_SCRIPT")
    
    if [ "$ENROLL_EXISTS" = "true" ]; then
        echo "  ✅ Enrollment for $BOOTSTRAP_USER in $ORG already exists on $IP. Skipping enrollment."
        continue
    fi
    echo "  ℹ️ Enrollment not found. Proceeding with enrollment..."
    
    echo "🔐 Enrolling bootstrap user $BOOTSTRAP_USER for $ORG at $IP..."
    
    ENROLL_SCRIPT="""
set -e

echo \"  🚀 Starting bootstrap user enrollment process on $IP for $ORG...\"

# Create required directories
echo \"  📁 Ensuring directory exists: $HOME_DIR/${ORG}-ca/${BOOTSTRAP_USER}\"
mkdir -p $HOME_DIR/${ORG}-ca/${BOOTSTRAP_USER}
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to create directory\"; exit 1; fi
echo \"  ✅ Directory ensured.\"

# Verify TLS certificate
echo \"  🔎 Verifying TLS verification certificate: $REMOTE_TLS_CERT_PATH\"
if [ ! -f \"$REMOTE_TLS_CERT_PATH\" ]; then
    echo \"  ⛔ Error: TLS verification certificate not found\"
    exit 1
fi
echo \"  ✅ TLS verification certificate found.\"

# Enroll bootstrap user
echo \"  🔐 Enrolling $BOOTSTRAP_USER...\"
~/bin/fabric-ca-client enroll -d \\
  --home $HOME_DIR \\
  -u https://$BOOTSTRAP_USER:$BOOTSTRAP_PASS@$CA_HOST:$CA_PORT \\
  --tls.certfiles \"$REMOTE_TLS_CERT_PATH\" \\
  --mspdir $MSP_DIR
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to enroll $BOOTSTRAP_USER\"; exit 1; fi
echo \"  ✅ $BOOTSTRAP_USER enrolled successfully.\"

# Rename private key
echo \"  📄 Renaming private key...\"
if [ -d $HOME_DIR/$MSP_DIR/keystore ]; then
    KEY_FILE=\$(find $HOME_DIR/$MSP_DIR/keystore -name \"*_sk\" -type f | head -n 1)
    if [ -z \"\$KEY_FILE\" ]; then
        echo \"  ⛔ Error: No private key file found in keystore\"
        ls -la $HOME_DIR/$MSP_DIR/keystore
        exit 1
    fi
    mv \"\$KEY_FILE\" $HOME_DIR/$MSP_DIR/keystore/key.pem
    if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to rename private key\"; exit 1; fi
    echo \"  ✅ Private key renamed successfully.\"
else
    echo \"  ⛔ Error: Keystore directory not found after enrollment\"
    ls -la $HOME_DIR/$MSP_DIR
    exit 1
fi
"""

    # Execute the enrollment script
    ssh_exec_script "$IP" "$ENROLL_SCRIPT" "Failed to enroll bootstrap user" || {
        echo "⛔ Failed to enroll bootstrap user for $ORG at $IP. Check logs on the remote machine."
        continue
    }
    
    echo "✅ Successfully enrolled bootstrap user for $ORG at $IP."
    echo "-----------------------------------------------------"
done

echo "🎉 All organization bootstrap users processed."
