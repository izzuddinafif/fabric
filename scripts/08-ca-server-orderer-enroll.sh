#!/bin/bash
# enroll the bootstrap user so we can create other identities
if ! [ -d "$HOME/fabric/fabric-ca-client" ]; then
    echo "Directory $HOME/fabric/fabric-ca-client does not exist. Exiting."
    exit 1
fi

if ! [ -d "$HOME/fabric/fabric-ca-client/tls-root-cert" ]; then
    echo "Directory $HOME/fabric/fabric-ca-client/tls-root-cert does not exist. Exiting."
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
# create other identities using those cert and key. The bootstrap user is the rcaadmin-orderer identity
# that was registered with the orderer-ca server in the previous step.
# The enroll command will create a new msp directory for the rcaadmin-orderer
# identity in the orderer-ca directory.

# remember that rcaadmin-orderer here is not the same as the one registered
# with the tls-ca server. The rcaadmin-orderer here is a bootstrap user
# that is registered with the orderer-ca server. They have different certificates and keys
# So it has no relation to the rcaadmin-orderer identity that was registered in tls-ca server.

# In this case, the --mspdir flag works a little differently. 
# For the enroll command, the --mspdir flag indicates where to
# store the generated TLS certificates for the rcaadmin identity.



./fabric-ca-client enroll -d \
  -u https://rcaadmin-orderer:ordererpw@ca.orderer.fabriczakat.local:7055 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir orderer-ca/rcaadmin-orderer/msp


# rename the private key file
mv orderer-ca/rcaadmin-orderer/msp/keystore/*_sk orderer-ca/rcaadmin-orderer/msp/keystore/orderer-key.pem