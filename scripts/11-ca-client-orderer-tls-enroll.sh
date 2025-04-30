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

# Ensure the orderer identity MSP directory exists (from script 10)
if ! [ -d "$HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp" ]; then
    echo "Directory $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp does not exist. Did you run script 10?"
    exit 1
fi

# Check if the target TLS directory already exists
if [ -d "$HOME/fabric-ca-client/orderer-ca/orderer0.example.local/tls" ]; then
    echo "Directory $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/tls already exists. Exiting."
    exit 1
fi

echo "Enrolling the orderer node identity (orderer0.example.local) with the TLS CA..."

# Set Fabric CA Client home directory
export FABRIC_CA_CLIENT_HOME=$HOME/fabric-ca-client

# Enroll the orderer identity with the TLS CA
# We use the TLS bootstrap user credentials created in script 04
# The --enrollment.profile tls indicates we are requesting TLS certs
# The --mspdir specifies where to store the generated TLS materials
# The --csr.hosts lists the hostnames for which the TLS cert will be valid
# The --tls.certfiles points to the TLS CA's root certificate
# The URL points to the TLS CA server
$HOME/bin/fabric-ca-client enroll -d \
  -u https://tls-bootstrap-user:tls-bootstrap-pw@tls-ca.example.local:7052 \
  --enrollment.profile tls \
  --mspdir orderer-ca/orderer0.example.local/tls \
  --csr.hosts orderer0.example.local,orderer.example.local \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem

# Rename the private key file (tls.key)
mv $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/tls/keystore/*_sk $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/tls/keystore/tls.key

# Copy the TLS CA's root certificate into the orderer's TLS directory
# This is needed for the orderer to trust other components' TLS certs
cp $HOME/fabric-ca-client/tls-root-cert/tls-ca-cert.pem $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/tls/tlscacerts/tls-ca-cert.pem

# Remove the intermediate CA cert if it exists (not typically needed for TLS)
rm -f $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/tls/intermediatecerts/*

# Copy the orderer's TLS CA root cert also to the main msp/tlscacerts directory
# Some tools might look for it there
cp $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/tls/tlscacerts/tls-ca-cert.pem $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/msp/tlscacerts/tls-ca-cert.pem


echo "Orderer node TLS enrollment attempt complete."
echo "TLS materials stored in $HOME/fabric-ca-client/orderer-ca/orderer0.example.local/tls"
echo "Check the output above for success or failure messages from the fabric-ca-client."
