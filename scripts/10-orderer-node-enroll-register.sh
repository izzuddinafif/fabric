#!/bin/bash

# Ensure the client config directory exists
if ! [ -d "$HOME/fabric/fabric-ca-client" ]; then
    echo "Directory $HOME/fabric/fabric-ca-client does not exist. Exiting."
    exit 1
fi

# Ensure the TLS root cert exists
if ! [ -f "$HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" ]; then
    echo "TLS root certificate $HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem not found. Did you run script 03?"
    exit 1
fi


MSP_DIR=$HOME/fabric/organizations/ordererOrganization/orderers/orderer.fabriczakat.local/msp

# Check if the target MSP directory exists
if ! [ -d "$MSP_DIR" ]; then
    echo "Directory $MSP_DIR does not exist"
    exit 1
fi

echo "Registering and Enrolling the orderer node identity (orderer.example.local) with the Orderer CA..."


# Set Fabric CA Client home directory
export FABRIC_CA_CLIENT_HOME=$HOME/fabric/fabric-ca-client

# Register the orderer node identity
./fabric-ca-client register -d \
  --id.name orderer.fabriczakat.local \
  --id.secret ordererpw \
  --id.type orderer \   
  --mspdir orderer-ca/rcaadmin-orderer/msp \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  -u https://ca.orderer.fabriczakat.local:7055

# Enroll the orderer node identity
./fabric-ca-client enroll -d \
  -u https://orderer.fabriczakat.local:ordererpw@ca.orderer.fabriczakat.local:7055 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir $MSP_DIR \

# Rename the private key and cert files
mv $MSP_DIR/keystore/*_sk $MSP_DIR/keystore/orderer-key.pem
mv $MSP_DIR/signcerts/* $MSP_DIR/signcerts/orderer-cert.pem


# create a config.yaml file for the orderer node identity
CACERT=$(ls "$MSP_DIR/cacerts"/*.pem | head -n 1)

if [ -z "$CACERT" ]; then
  echo "Error: No .pem found in $MSP_DIR/cacerts"
  exit 1
fi

# create the config.yaml file
./helper/create-config-yaml.sh $CACERT $MSP_DIR


echo "Orderer node identity register enrollment attempt complete."
echo "Check the output above for success or failure messages from the fabric-ca-client."
