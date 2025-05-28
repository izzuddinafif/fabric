#!/bin/bash

declare -A ORGS=(
    ["10.104.0.2"]="org1"
    ["10.104.0.4"]="org2"
)

for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    BOOTSTRAP_USER="btstrp-${ORG}"
    BOOTSTRAP_PASS="${ORG}pw"
    MSP_DIR="${ORG}-ca/${BOOTSTRAP_USER}/msp"
    CA_HOST="ca.${ORG}.fabriczakat.local"
    CA_PORT="7054"
    HOME_DIR="/home/fabricadmin/fabric/fabric-ca-client"
    
    echo "Processing bootstrap user for $ORG at $IP..."
    
    # The TLS certificates are on the remote machine, not locally
    # Check if the certificate exists on the remote machine
    REMOTE_TLS_CERT_PATH="/home/fabricadmin/fabric/fabric-ca-server-${ORG}/tls/cert.pem"
    echo "  🔎 Checking for remote TLS certificate at $REMOTE_TLS_CERT_PATH on $IP..."
    TLS_CERT_EXISTS=$(ssh "fabricadmin@$IP" "[ -f $REMOTE_TLS_CERT_PATH ] && echo 'true' || echo 'false'")
    
    if [ "$TLS_CERT_EXISTS" = "false" ]; then
        echo "  ⛔ Error: TLS certificate not found at $REMOTE_TLS_CERT_PATH on remote machine $IP. Cannot proceed."
        continue
    fi
    echo "  ✅ Remote TLS certificate found."
    
    # Check if enrollment already exists on the remote machine
    echo "  🔎 Checking for existing enrollment for $BOOTSTRAP_USER on $IP..."
    ENROLL_EXISTS=$(ssh "fabricadmin@$IP" "[ -f $HOME_DIR/$MSP_DIR/signcerts/cert.pem ] && [ -f $HOME_DIR/$MSP_DIR/keystore/key.pem ] && echo 'true' || echo 'false'")
    
    if [ "$ENROLL_EXISTS" = "true" ]; then
        echo "  ✅ Enrollment for $BOOTSTRAP_USER in $ORG already exists on $IP. Skipping enrollment."
        continue
    fi
    echo "  ℹ️ Enrollment not found. Proceeding with enrollment..."
    
    echo "🔐 Enrolling bootstrap user $BOOTSTRAP_USER for $ORG at $IP..."
    
    ssh "fabricadmin@$IP" """
set -e

echo \"  🚀 Starting bootstrap user enrollment process on $IP for $ORG...\"

# Create required directories
echo \"  📁 Ensuring directory exists: $HOME_DIR/${ORG}-ca/${BOOTSTRAP_USER}\"
mkdir -p $HOME_DIR/${ORG}-ca/${BOOTSTRAP_USER}
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to create directory $HOME_DIR/${ORG}-ca/${BOOTSTRAP_USER}\"; exit 1; fi
echo \"  ✅ Directory ensured.\"

# The TLS certificate is already on the remote machine
TLS_VERIFICATION_CERT=\"$REMOTE_TLS_CERT_PATH\"

# Verify the certificate exists
echo \"  🔎 Verifying TLS verification certificate: \$TLS_VERIFICATION_CERT\"
if [ ! -f \"\$TLS_VERIFICATION_CERT\" ]; then
    echo \"  ⛔ Error: TLS verification certificate not found at \$TLS_VERIFICATION_CERT\"
    exit 1
fi
echo \"  ✅ TLS verification certificate found.\"

# Run the enrollment command with debug to see more details
echo \"  🔐 Enrolling $BOOTSTRAP_USER...\"
~/bin/fabric-ca-client enroll -d \\
  --home $HOME_DIR \\
  -u https://$BOOTSTRAP_USER:$BOOTSTRAP_PASS@$CA_HOST:$CA_PORT \\
  --tls.certfiles \"\$TLS_VERIFICATION_CERT\" \\
  --mspdir $MSP_DIR
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to enroll $BOOTSTRAP_USER\"; exit 1; fi
echo \"  ✅ $BOOTSTRAP_USER enrolled successfully.\"

# Rename the private key for consistency
echo \"  📄 Renaming private key...\"
if [ -d $HOME_DIR/$MSP_DIR/keystore ]; then
    KEY_FILE=\$(find $HOME_DIR/$MSP_DIR/keystore -name \"*_sk\" -type f | head -n 1)
    if [ -z \"\$KEY_FILE\" ]; then
        echo \"  ⛔ Error: No private key file (*_sk) found in $HOME_DIR/$MSP_DIR/keystore\"
        ls -la $HOME_DIR/$MSP_DIR/keystore
        exit 1
    fi
    mv \"\$KEY_FILE\" $HOME_DIR/$MSP_DIR/keystore/key.pem
    if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to rename private key\"; exit 1; fi
    echo \"  ✅ Private key renamed successfully.\"
else
    echo \"  ⛔ Error: Keystore directory not found after enrollment at $HOME_DIR/$MSP_DIR/keystore\"
    ls -la $HOME_DIR/$MSP_DIR
    exit 1
fi
"""

    # Check the exit status of the SSH command
    if [ $? -eq 0 ]; then
        echo "✅ Successfully enrolled bootstrap user for $ORG at $IP."
    else
        echo "⛔ Failed to enroll bootstrap user for $ORG at $IP. Check logs on the remote machine."
    fi
    echo "-----------------------------------------------------"

done

echo "🎉 All organization bootstrap users processed."
