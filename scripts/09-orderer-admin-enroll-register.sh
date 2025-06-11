#!/bin/bash
# set -e

# Ensure the client config directory exists
if ! [ -d "$HOME/fabric/fabric-ca-client" ]; then
    echo "⛔ Directory $HOME/fabric/fabric-ca-client does not exist. Exiting."
    exit 1
fi

# Ensure the TLS root cert exists
if ! [ -f "$HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" ]; then
    echo "⛔ TLS root certificate $HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem not found."
    exit 1
fi

# Ensure the orderer bootstrap user MSP exists (registrar)
if ! [ -d "$HOME/fabric/fabric-ca-client/orderer-ca/btstrp-orderer/msp" ]; then
    echo "⛔ Orderer CA bootstrap user MSP not found. Did script 08 run correctly?"
    exit 1
fi

cd $HOME/fabric/fabric-ca-client
# Set Fabric CA Client home directory
export FABRIC_CA_CLIENT_HOME=$HOME/fabric/fabric-ca-client

# Define MSP directories
MSP_DIR_ADMIN_USER=$HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/users/Admin@fabriczakat.local/msp
MSP_DIR_ORG=$HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/msp

# Create necessary directories if they don't exist
mkdir -p $MSP_DIR_ADMIN_USER $MSP_DIR_ORG/cacerts $MSP_DIR_ORG/tlscacerts

# Register the orderer admin identity
echo "🔐 Registering orderer admin identity 'ordereradmin'..."
REGISTER_ADMIN_OUTPUT=$(./fabric-ca-client register -d \
  --id.name ordereradmin \
  --id.secret ordereradminpw \
  --id.type admin \
  --mspdir orderer-ca/btstrp-orderer/msp \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  -u https://ca.orderer.fabriczakat.local:7055 2>&1) # Capture stdout and stderr

REGISTER_ADMIN_EXIT_CODE=$?

if [ $REGISTER_ADMIN_EXIT_CODE -ne 0 ]; then
    if echo "$REGISTER_ADMIN_OUTPUT" | grep -q "Error Code: 74"; then # Check for "already registered"
        echo "INFO: Orderer admin identity 'ordereradmin' is already registered. Proceeding..."
    else
        echo "⛔ Failed to register orderer admin identity 'ordereradmin' with an unexpected error:"
        echo "$REGISTER_ADMIN_OUTPUT"
        exit 1
    fi
else
    echo "✅ Orderer admin identity 'ordereradmin' registered successfully."
fi

# Enroll the orderer admin identity
echo "🔐 Enrolling orderer admin identity 'ordereradmin'..."
./fabric-ca-client enroll -d \
  -u https://ordereradmin:ordereradminpw@ca.orderer.fabriczakat.local:7055 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir $MSP_DIR_ADMIN_USER
if [ $? -ne 0 ]; then echo "⛔ Failed to enroll orderer admin identity."; exit 1; fi
echo "✅ Orderer admin identity 'ordereradmin' enrolled successfully."

# Rename the private key and cert files
echo "📄 Renaming orderer admin private key and certificate..."
ADMIN_KEY_FILE=$(find $MSP_DIR_ADMIN_USER/keystore/ -type f -name "*_sk")
ADMIN_CERT_FILE=$(find $MSP_DIR_ADMIN_USER/signcerts/ -type f -name "*.pem")

if [ -z "$ADMIN_KEY_FILE" ]; then echo "⛔ Orderer admin private key not found in $MSP_DIR_ADMIN_USER/keystore/"; exit 1; fi
if [ -z "$ADMIN_CERT_FILE" ]; then echo "⛔ Orderer admin certificate not found in $MSP_DIR_ADMIN_USER/signcerts/"; exit 1; fi

mv "$ADMIN_KEY_FILE" "$MSP_DIR_ADMIN_USER/keystore/orderer-admin-key.pem"
mv "$ADMIN_CERT_FILE" "$MSP_DIR_ADMIN_USER/signcerts/orderer-admin-cert.pem"
if [ $? -ne 0 ]; then echo "⛔ Failed to rename orderer admin key/cert files."; exit 1; fi
echo "✅ Orderer admin key and certificate renamed successfully."

# Create a config.yaml file for the orderer admin identity's MSP
echo "📄 Creating config.yaml for orderer admin MSP..."
CACERT_ADMIN_USER=$(ls "$MSP_DIR_ADMIN_USER/cacerts"/*.pem | head -n 1)

if [ -z "$CACERT_ADMIN_USER" ]; then
  echo "⛔ Error: No CA cert .pem found in $MSP_DIR_ADMIN_USER/cacerts after enrollment."
  exit 1
fi

# Assuming the helper script is one directory up in 'scripts/helper/' relative to where this script is.
# Adjust path if necessary.
./../scripts/helper/create-config-yaml.sh "$CACERT_ADMIN_USER" "$MSP_DIR_ADMIN_USER"
if [ $? -ne 0 ]; then echo "⛔ Failed to create config.yaml for orderer admin MSP."; exit 1; fi
echo "✅ config.yaml for orderer admin MSP created successfully."

# Create tlscacerts directory in orderer admin's MSP and copy the TLS CA cert
echo "📄 Copying TLS CA cert to orderer admin MSP..."
mkdir -p $MSP_DIR_ADMIN_USER/tlscacerts
cp ./tls-root-cert/tls-ca-cert.pem $MSP_DIR_ADMIN_USER/tlscacerts/tls-ca-cert.pem
if [ $? -ne 0 ]; then echo "⛔ Failed to copy TLS CA cert to orderer admin MSP."; exit 1; fi
echo "✅ TLS CA cert copied to orderer admin MSP successfully."

# Copy CA certs to Org MSP
echo "📄 Copying CA certs to Orderer Org MSP..."
# Ensure source CA cert files exist
if ! [ -f "../fabric-ca-server-orderer/ca-cert.pem" ]; then echo "⛔ Source Orderer CA cert ../fabric-ca-server-orderer/ca-cert.pem not found."; exit 1; fi
if ! [ -f "./tls-root-cert/tls-ca-cert.pem" ]; then echo "⛔ Source TLS root cert ./tls-root-cert/tls-ca-cert.pem not found."; exit 1; fi

cp ../fabric-ca-server-orderer/ca-cert.pem $MSP_DIR_ORG/cacerts/orderer-ca-cert.pem
cp ./tls-root-cert/tls-ca-cert.pem $MSP_DIR_ORG/tlscacerts/tls-ca-cert.pem
if [ $? -ne 0 ]; then echo "⛔ Failed to copy CA certs to Orderer Org MSP."; exit 1; fi
echo "✅ CA certs copied to Orderer Org MSP successfully."

# Create a config.yaml file for the orderer org's MSP
echo "📄 Creating config.yaml for Orderer Org MSP..."
CACERT_ORG=$(ls "$MSP_DIR_ORG/cacerts"/*.pem | head -n 1)

if [ -z "$CACERT_ORG" ]; then
  echo "⛔ Error: No CA cert .pem found in $MSP_DIR_ORG/cacerts"
  exit 1
fi

./../scripts/helper/create-config-yaml.sh "$CACERT_ORG" "$MSP_DIR_ORG"
if [ $? -ne 0 ]; then echo "⛔ Failed to create config.yaml for Orderer Org MSP."; exit 1; fi
echo "✅ config.yaml for Orderer Org MSP created successfully."

echo "✅ Orderer admin identity registration and enrollment process complete."
echo "ℹ️ Check the output above for success or failure messages from the fabric-ca-client."