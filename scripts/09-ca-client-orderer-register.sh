#!/bin/bash

# Ensure the client config directory exists
if ! [ -d "$HOME/fabric-ca-client" ]; then
    echo "Directory $HOME/fabric-ca-client does not exist. Exiting."
    exit 1
fi

if ! [ -d "$HOME/fabric-ca-client/orderer-ca/rcaadmin-orderer/msp" ]; then
    echo "Directory $HOME/fabric-ca-client/orderer-ca/rcaadmin-orderer/msp does not exist. Did you run script 08?"
    exit 1
fi

# Ensure the TLS root cert exists
if ! [ -f "$HOME/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" ]; then
    echo "TLS root certificate $HOME/fabric-ca-client/tls-root-cert/tls-ca-cert.pem not found. Did you run script 03?"
    exit 1
fi

echo "Registering the orderer node identity (orderer.example.local) with the Orderer CA..."

# Set Fabric CA Client home directory
export FABRIC_CA_CLIENT_HOME=$HOME/fabric-ca-client

# Register the orderer identity using the Orderer CA admin identity
# The --id.name specifies the identity being registered (orderer0.example.local)
# The --id.secret specifies the password for the new identity
# The --id.type specifies the role (orderer)
# The --mspdir points to the MSP of the *registrar* (rcaadmin-orderer)
# The --tls.certfiles points to the TLS CA's root certificate
# The URL points to the Orderer CA server
$HOME/bin/fabric-ca-client register -d \
  --id.name orderer0.example.local \
  --id.secret ordererpw \
  --id.type orderer \
  --mspdir orderer-ca/rcaadmin/msp \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  -u https://orderer.example.local:7055

echo "Orderer node identity registration attempt complete."
echo "Check the output above for success or failure messages from the fabric-ca-client."
