#!/bin/bash
# IMPORTANT SCRIPT!
cd $HOME/fabric/fabric-ca-client/
export FABRIC_CA_CLIENT_HOME=$PWD

if ! [ -x "$HOME/fabric/bin/fabric-ca-client" ]; then
    cp $HOME/fabric/bin/fabric-ca-client $HOME/fabric/fabric-ca-client/
    exit 1
fi

if [ -d "$HOME/fabric/fabric-ca-client/tls-ca/rcaadmin-*" ]; then
    echo "Directory $HOME/fabric/fabric-ca-client/tls-ca/rcaadmin-* already exists. Deleting."
    rm -rf $HOME/fabric/fabric-ca-client/tls-ca/rcaadmin-*
fi

# register the bootstrap users

# for Org1-CA
# -d means debug mode
./fabric-ca-client register -d \
    --id.name rcaadmin-org1 \
    --id.secret org1pw \
    -u https://tls.fabriczakat.local:7054  \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --mspdir tls-ca/tlsadmin/msp

# for Org2-CA
./fabric-ca-client register -d \
    --id.name rcaadmin-org2 \
    --id.secret org2pw \
    -u https://tls.fabriczakat.local:7054  \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --mspdir tls-ca/tlsadmin/msp

# for Orderer-CA
./fabric-ca-client register -d \
    --id.name rcaadmin-orderer \
    --id.secret ordererpw \
    -u https://tls.fabriczakat.local:7054  \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --mspdir tls-ca/tlsadmin/msp


# enroll the bootstrap users

# In this case, the --mspdir flag works a little differently. 
# For the enroll command, the --mspdir flag indicates where to
# store the generated TLS certificates for the rcaadmin identity.

# Org1-CA’s TLS cert
./fabric-ca-client enroll \
  -u https://rcaadmin-org1:org1pw@tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls \
  --csr.hosts 'ca.org1.fabriczakat.local' \
  --mspdir tls-ca/rcaadmin-org1/msp

# Org2-CA’s TLS cert
./fabric-ca-client enroll \
  -u https://rcaadmin-org2:org2pw@tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls \
  --csr.hosts 'ca.org2.fabriczakat.local' \
  --mspdir tls-ca/rcaadmin-org2/msp

# Orderer-CA’s TLS cert
./fabric-ca-client enroll \
  -u https://rcaadmin-orderer:ordererpw@tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls \
  --csr.hosts 'ca.orderer.fabriczakat.local' \
  --mspdir tls-ca/rcaadmin-orderer/msp


# rename the private key files to key.pem
# Org1-CA
mv tls-ca/rcaadmin-org1/msp/keystore/*_sk tls-ca/rcaadmin-org1/msp/keystore/key.pem
# Org2-CA
mv tls-ca/rcaadmin-org2/msp/keystore/*_sk tls-ca/rcaadmin-org2/msp/keystore/key.pem
# Orderer-CA
mv tls-ca/rcaadmin-orderer/msp/keystore/*_sk tls-ca/rcaadmin-orderer/msp/keystore/key.pem
