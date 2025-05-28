#!/bin/bash
# enroll the bootstrap user so we can create other identities
if ! [ -d "$HOME/fabric/fabric-ca-client" ]; then
    echo "⛔ Directory $HOME/fabric/fabric-ca-client does not exist. Exiting."
    exit 1
fi

if ! [ -d "$HOME/fabric/fabric-ca-client/tls-root-cert" ]; then
    echo "⛔ Directory $HOME/fabric/fabric-ca-client/tls-root-cert does not exist. Exiting."
    exit 1
fi
if ! [ -f "$HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" ]; then
    echo "⛔ TLS root certificate $HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem not found. Did you run script 03?"
    exit 1
fi

if [ -d "$HOME/fabric/fabric-ca-client/orderer-ca" ]; then
    echo "Directory $HOME/fabric/fabric-ca-client/orderer-ca already exists. Deleting."
    rm -rf $HOME/fabric/fabric-ca-client/orderer-ca
fi

mkdir $HOME/fabric/fabric-ca-client/orderer-ca

cd $HOME/fabric/fabric-ca-client
export FABRIC_CA_CLIENT_HOME=$PWD

# enroll the bootstrap user to get the bootsrap user's cert and key so we can
# create other identities using those cert and key. The bootstrap user is btstrp-orderer
# that was bootstraped with the orderer-ca server init in the previous step.
# The enroll command will create a new msp directory for the btstrp-orderer
# identity in the orderer-ca directory. Thus, the bootstrap user will bex
# our registrar for other identities.

# remember that btstrp-orderer here is not the same as the one registered
# with the tls-ca server. The btstrp-orderer here is a bootstrap user
# that is registered with the orderer-ca server. They have different certificates and keys
# So it has no relation to the btstrp-orderer identity that was registered in tls-ca server.

# usually, we need to register an identity before enrolling it. But in this case,
# the identity is already registered since it's a bootstrap user.
# The --tls.certfiles flag points to the TLS CA's root certificate
# The --mspdir flag points to the directory where the bootstrap user's
# certificate and key will be stored.

# In this case, the --mspdir flag works a little differently.
# For the enroll command, the --mspdir flag indicates where to
# store the generated TLS certificates for the btstrp identity.
MSP_DIR=$HOME/fabric/fabric-ca-client/orderer-ca/btstrp-orderer/msp

echo "🔐 Enrolling bootstrap user 'btstrp-orderer' with Orderer CA..."
./fabric-ca-client enroll -d \
  -u https://btstrp-orderer:btstrp-ordererpw@ca.orderer.fabriczakat.local:7055 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir orderer-ca/btstrp-orderer/msp

if [ $? -ne 0 ]; then
    echo "⛔ Failed to enroll bootstrap user 'btstrp-orderer'."
    exit 1
fi
echo "✅ Bootstrap user 'btstrp-orderer' enrolled successfully."

# rename the private key file
echo "📄 Renaming private key file..."
KEY_FILE=$(find $MSP_DIR/keystore/ -type f -name "*_sk")
if [ -z "$KEY_FILE" ]; then
    echo "⛔ Private key file not found in $MSP_DIR/keystore/"
    exit 1
fi
mv $KEY_FILE $MSP_DIR/keystore/key.pem
if [ $? -ne 0 ]; then
    echo "⛔ Failed to rename private key file."
    exit 1
fi
echo "✅ Private key file renamed successfully."

