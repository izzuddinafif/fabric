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
# create other identities using those cert and key. The bootstrap user is rcaadmin-orderer
# that was bootstraped with the orderer-ca server init in the previous step.
# The enroll command will create a new msp directory for the rcaadmin-orderer
# identity in the orderer-ca directory. Thus, the bootstrap user will be
# our registrar for other identities.

# remember that rcaadmin-orderer here is not the same as the one registered
# with the tls-ca server. The rcaadmin-orderer here is a bootstrap user
# that is registered with the orderer-ca server. They have different certificates and keys
# So it has no relation to the rcaadmin-orderer identity that was registered in tls-ca server.

# usually, we need to register an identity before enrolling it. But in this case,
# the identity is already registered since it's a bootstrap user.
# The --tls.certfiles flag points to the TLS CA's root certificate
# The --mspdir flag points to the directory where the bootstrap user's
# certificate and key will be stored.

# In this case, the --mspdir flag works a little differently. 
# For the enroll command, the --mspdir flag indicates where to
# store the generated TLS certificates for the rcaadmin identity.

./fabric-ca-client enroll -d \
  -u https://rcaadmin-orderer:ordererpw@ca.orderer.fabriczakat.local:7055 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir orderer-ca/rcaadmin-orderer/msp


# rename the private key file
mv orderer-ca/rcaadmin-orderer/msp/keystore/*_sk orderer-ca/rcaadmin-orderer/msp/keystore/orderer-key.pem



# excerpt from documentation:
# While it is possible for the admin of a CA to create an identity and give the public/private key pair to a user out of band, this process would give the CA admin access to the private key of every user. Such an arrangement violates basic security procedures regarding the security of private keys, which should not be exposed for any reason.

# As a result, CA admins register users, a process in which the CA admin gives an enroll ID and secret (these are similar to a username and password) to an identity and assigns it a role and any required attributes. The CA admin then gives this enroll ID and secret to the ultimate user of the identity. The user can then execute a Fabric CA client enroll command using this enroll ID and secret, returning the public/private key pair containing the role and attributes assigned by the CA admin.

# This process preserves both the integrity of the CA (because only CA admins can register users and assign roles and affiliations) and private keys (since only the user of an identity will have access to them).