#!/bin/bash
if [ -d "$HOME/fabric/fabric-ca-client" ]; then
    echo "Directory $HOME/fabric/fabric-ca-client already exists. Exiting."
    exit 1
fi

if ! [ -d "$HOME/fabric/fabric-ca-server-tls" ]; then
    echo "Directory $HOME/fabric/fabric-ca-server-tls does not exist. Exiting."
    exit 1
fi

mkdir $HOME/fabric/fabric-ca-client
mkdir $HOME/fabric/fabric-ca-client/tls-ca
mkdir $HOME/fabric/fabric-ca-client/tls-root-cert

cp $HOME/fabric/fabric-ca-server-tls/ca-cert.pem $HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem
cp $HOME/fabric/bin/fabric-ca-client $HOME/fabric/fabric-ca-client/

cd $HOME/fabric/fabric-ca-client/
export FABRIC_CA_CLIENT_HOME=$PWD

./fabric-ca-client enroll -d -u https://tls-admin:tls-adminpw@tls.fabriczakat.local:7054 --tls.certfiles tls-root-cert/tls-ca-cert.pem --mspdir tls-ca/tlsadmin/msp \
--enrollment.profile tls
# If you removed signing.profiles.ca block from the TLS CA configuration .yaml file, you could omit the --enrollment.profile tls flag
