#!/bin/bash

# Ensure the client config directory exists
if ! [ -d "$HOME/fabric-ca-client" ]; then
    echo "Directory $HOME/fabric-ca-client does not exist. Exiting."
    exit 1
fi

# Ensure the TLS root cert exists
if ! [ -f "$HOME/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" ]; then
    echo "TLS root certificate $HOME/fabric-ca-client/tls-root-cert/tls-ca-cert.pem not found. Did you run script 03?"
    exit 1
fi

# Check if the target MSP directory already exists
if [ -d "$HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp" ]; then
    echo "Directory $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp already exists. Exiting."
    exit 1
fi

echo "Enrolling the orderer node identity (orderer0.example.local) with the Orderer CA..."

# Set Fabric CA Client home directory
export FABRIC_CA_CLIENT_HOME=$HOME/fabric-ca-client

# Enroll the orderer identity
# The -u flag specifies the identity and password registered in the previous step (script 09)
# The --mspdir flag specifies where to store the generated MSP for this identity
# The --tls.certfiles points to the TLS CA's root certificate
# The URL points to the Orderer CA server
$HOME/bin/fabric-ca-client enroll -d \
  -u https://orderer0.example.local:ordererpw@orderer.example.local:7055 \
  --mspdir orderer-ca/orderer0.example.local/msp \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem

# Rename the private key file for consistency
mv $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp/keystore/*_sk $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp/keystore/orderer-key.pem

# Create the admincerts directory if it doesn't exist
mkdir -p $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp/admincerts

# Copy the Orderer CA's root certificate into the orderer's MSP admincerts directory
# This is required for the orderer node to trust identities issued by this CA
cp $HOME/fabric-ca-client/orderer-ca/rcaadmin/msp/cacerts/orderer-example-local-7055.pem $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp/admincerts/orderer-admin-cert.pem

echo "Orderer node identity enrollment attempt complete."
echo "MSP materials stored in $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp"
echo "Check the output above for success or failure messages from the fabric-ca-client."
