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


MSP_DIR=$HOME/fabric/organizations/ordererOrganization/fabriczakat.local/orderers/orderer.fabriczakat.local/msp

if [ -d "$MSP_DIR" ]; then
    echo "Directory $MSP_DIR already exists. Exiting."
    exit 1
fi

echo "Registering and Enrolling the orderer node identity (orderer.example.local) with the Orderer CA..."

cd $HOME/fabric/fabric-ca-client
# Set Fabric CA Client home directory
export FABRIC_CA_CLIENT_HOME=$HOME/fabric/fabric-ca-client

# Register the orderer node identity
./fabric-ca-client register -d \
  --id.name orderer.fabriczakat.local \
  --id.secret ordererpw \
  --id.type orderer \
  --mspdir orderer-ca/btstrp-orderer/msp \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  -u https://ca.orderer.fabriczakat.local:7055

# Enroll the orderer node identity
./fabric-ca-client enroll -d \
  -u https://orderer.fabriczakat.local:ordererpw@ca.orderer.fabriczakat.local:7055 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir $MSP_DIR \

# Rename the private key and cert files
mv $MSP_DIR/keystore/*_sk $MSP_DIR/keystore/orderer-node-key.pem
mv $MSP_DIR/signcerts/* $MSP_DIR/signcerts/orderer-node-cert.pem


# create a config.yaml file for the orderer node identity
CACERT=$(ls "$MSP_DIR/cacerts"/*.pem | head -n 1)

if [ -z "$CACERT" ]; then
  echo "Error: No .pem found in $MSP_DIR/cacerts"
  exit 1
fi

# create the config.yaml file
./../scripts/helper/create-config-yaml.sh $CACERT $MSP_DIR


# Register and enroll the orderer node's TLS identity
ORDERER_TLS_DIR=$HOME/fabric/organizations/ordererOrganization/fabriczakat.local/orderers/orderer.fabriczakat.local/tls

mkdir -p $ORDERER_TLS_DIR

./fabric-ca-client register -d \
  --id.name orderer.fabriczakat.local \
  --id.secret ordererpw \
  -u https://tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir tls-ca/tlsadmin/msp

./fabric-ca-client enroll -d \
  -u https://orderer.fabriczakat.local:ordererpw@tls.fabriczakat.local:7054 \
  --enrollment.profile tls \
  --csr.hosts orderer.fabriczakat.local \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir $ORDERER_TLS_DIR

# Rename TLS certs as expected by Fabric
cp $ORDERER_TLS_DIR/signcerts/cert.pem $ORDERER_TLS_DIR/server.crt
cp $ORDERER_TLS_DIR/keystore/*_sk $ORDERER_TLS_DIR/server.key
cp tls-root-cert/tls-ca-cert.pem $ORDERER_TLS_DIR/ca.crt

mkdir -p $MSP_DIR/tlscacerts
# we need this one apparently 🙃

cp $ORDERER_TLS_DIR/ca.crt $MSP_DIR/tlscacerts/tls-ca-cert.pem

echo "Orderer node identity register enrollment attempt complete."
echo "Check the output above for success or failure messages from the fabric-ca-client."

# Final structure for our orderer node (1 orderer, 1 admin)

# organizations/
# └── ordererOrganizations/
#     └── fabriczakat.local/
#         ├── msp/                                 ← Org-wide MSP
#         │   ├── cacerts/
#         │   │   └── orderer-ca-cert.pem          ← Root CA cert (identity)
#         │   ├── config.yaml                      ← NodeOU role mapping
#         │   └── tlscacerts/
#         │       └── tls-ca-cert.pem              ← TLS CA cert
#         │
#         ├── orderers/
#         │   └── orderer.fabriczakat.local/
#         │       ├── msp/                         ← Orderer node's identity MSP
#         │       │   ├── cacerts/
#         │       │   │   └── ca-orderer-fabriczakat-local-7055.pem
#         │       │   ├── config.yaml
#         │       │   ├── keystore/
#         │       │   │   └── orderer-node-key.pem
#         │       │   ├── signcerts/
#         │       │   │   └── orderer-node-cert.pem
#         │       │   ├── tlscacerts/
#         │       │   │   └── tls-ca-cert.pem
#         │       │   ├── IssuerPublicKey
#         │       │   ├── IssuerRevocationPublicKey
#         │       │   └── user/
#         │       │
#         │       └── tls/                         ← Orderer's TLS certs
#         │           ├── server.crt               ← TLS cert
#         │           ├── server.key               ← TLS private key
#         │           ├── ca.crt                   ← TLS CA cert
#         │           ├── signcerts/
#         │           │   └── cert.pem             ← Raw enrolled cert
#         │           ├── keystore/
#         │           │   └── <TLS private key>    ← Raw key
#         │           ├── tlscacerts/
#         │           │   └── tls-tls-fabriczakat-local-7054.pem (optional)
#         │           ├── IssuerPublicKey
#         │           ├── IssuerRevocationPublicKey
#         │           └── user/
#         │
#         └── users/
#             └── Admin@fabriczakat.local/
#                 └── msp/                         ← Admin identity MSP
#                     ├── cacerts/
#                     │   └── ca-orderer-fabriczakat-local-7055.pem
#                     ├── config.yaml
#                     ├── keystore/
#                     │   └── orderer-admin-key.pem
#                     ├── signcerts/
#                     │   └── orderer-admin-cert.pem
#                     ├── IssuerPublicKey
#                     ├── IssuerRevocationPublicKey
#                     └── user/
