#!/bin/bash

# Ensure the client config directory exists
if ! [ -d "$HOME/fabric/fabric-ca-client" ]; then
    echo "⛔ Directory $HOME/fabric/fabric-ca-client does not exist. Exiting."
    exit 1
fi

# Ensure the TLS root cert exists
if ! [ -f "$HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" ]; then
    echo "⛔ TLS root certificate $HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem not found. Did you run script 03?"
    exit 1
fi

# Ensure the orderer bootstrap user MSP exists (registrar for identity)
if ! [ -d "$HOME/fabric/fabric-ca-client/orderer-ca/btstrp-orderer/msp" ]; then
    echo "⛔ Orderer CA bootstrap user MSP not found. Did script 08 run correctly?"
    exit 1
fi

# Ensure the TLS admin MSP exists (registrar for TLS identity)
if ! [ -d "$HOME/fabric/fabric-ca-client/tls-ca/tlsadmin/msp" ]; then
    echo "⛔ TLS admin MSP directory not found. Did script 03 run correctly?"
    exit 1
fi


MSP_DIR=$HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/msp

mkdir -p $MSP_DIR

echo "🔐 Registering the orderer node identity (orderer.fabriczakat.local) with the Orderer CA..."

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
if [ $? -ne 0 ]; then echo "⛔ Failed to register orderer node identity."; exit 1; fi
echo "✅ Orderer node identity registered successfully."

# Enroll the orderer node identity
echo "🔐 Enrolling the orderer node identity..."
./fabric-ca-client enroll -d \
  -u https://orderer.fabriczakat.local:ordererpw@ca.orderer.fabriczakat.local:7055 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir $MSP_DIR
if [ $? -ne 0 ]; then echo "⛔ Failed to enroll orderer node identity."; exit 1; fi
echo "✅ Orderer node identity enrolled successfully."

# Rename the private key and cert files
echo "📄 Renaming orderer node identity key and certificate..."
NODE_KEY_FILE=$(find $MSP_DIR/keystore/ -type f -name "*_sk")
NODE_CERT_FILE=$(find $MSP_DIR/signcerts/ -type f -name "*.pem")

if [ -z "$NODE_KEY_FILE" ]; then echo "⛔ Orderer node private key not found in $MSP_DIR/keystore/"; exit 1; fi
if [ -z "$NODE_CERT_FILE" ]; then echo "⛔ Orderer node certificate not found in $MSP_DIR/signcerts/"; exit 1; fi

mv $NODE_KEY_FILE $MSP_DIR/keystore/orderer-node-key.pem
mv $NODE_CERT_FILE $MSP_DIR/signcerts/orderer-node-cert.pem
if [ $? -ne 0 ]; then echo "⛔ Failed to rename orderer node key/cert files."; exit 1; fi
echo "✅ Orderer node key and certificate renamed successfully."


# create a config.yaml file for the orderer node identity
echo "📄 Creating config.yaml for orderer node MSP..."
CACERT=$(ls "$MSP_DIR/cacerts"/*.pem | head -n 1)

if [ -z "$CACERT" ]; then
  echo "⛔ Error: No CA cert .pem found in $MSP_DIR/cacerts"
  exit 1
fi

# create the config.yaml file
./../scripts/helper/create-config-yaml.sh $CACERT $MSP_DIR
if [ $? -ne 0 ]; then echo "⛔ Failed to create config.yaml for orderer node MSP."; exit 1; fi
echo "✅ config.yaml for orderer node MSP created successfully."


# Register and enroll the orderer node's TLS identity
ORDERER_TLS_DIR=$HOME/fabric/organizations/ordererOrganizations/fabriczakat.local/orderers/orderer.fabriczakat.local/tls

mkdir -p $ORDERER_TLS_DIR

echo "🔐 Registering orderer node TLS identity..."
./fabric-ca-client register -d \
  --id.name orderer.fabriczakat.local \
  --id.secret ordererpw \
  -u https://tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir tls-ca/tlsadmin/msp
if [ $? -ne 0 ]; then echo "⛔ Failed to register orderer node TLS identity."; exit 1; fi
echo "✅ Orderer node TLS identity registered successfully."

echo "🔐 Enrolling orderer node TLS identity..."
./fabric-ca-client enroll -d \
  -u https://orderer.fabriczakat.local:ordererpw@tls.fabriczakat.local:7054 \
  --enrollment.profile tls \
  --csr.hosts orderer.fabriczakat.local \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir $ORDERER_TLS_DIR
if [ $? -ne 0 ]; then echo "⛔ Failed to enroll orderer node TLS identity."; exit 1; fi
echo "✅ Orderer node TLS identity enrolled successfully."

# Rename TLS certs as expected by Fabric
echo "📄 Renaming and copying orderer node TLS files..."
TLS_KEY_FILE=$(find $ORDERER_TLS_DIR/keystore/ -type f -name "*_sk")
TLS_CERT_FILE=$ORDERER_TLS_DIR/signcerts/cert.pem
TLS_CA_CERT_FILE=tls-root-cert/tls-ca-cert.pem

if [ ! -f "$TLS_CERT_FILE" ]; then echo "⛔ Orderer node TLS certificate not found: $TLS_CERT_FILE"; exit 1; fi
if [ -z "$TLS_KEY_FILE" ]; then echo "⛔ Orderer node TLS private key not found in $ORDERER_TLS_DIR/keystore/"; exit 1; fi
if [ ! -f "$TLS_CA_CERT_FILE" ]; then echo "⛔ TLS CA root certificate not found: $TLS_CA_CERT_FILE"; exit 1; fi

cp $TLS_CERT_FILE $ORDERER_TLS_DIR/server.crt
cp $TLS_KEY_FILE $ORDERER_TLS_DIR/server.key
cp $TLS_CA_CERT_FILE $ORDERER_TLS_DIR/ca.crt
if [ $? -ne 0 ]; then echo "⛔ Failed to copy/rename orderer node TLS files."; exit 1; fi
echo "✅ Orderer node TLS files renamed and copied successfully."

# Create tlscacerts directory in orderer node's MSP and copy the TLS CA cert
echo "📄 Copying TLS CA cert to orderer node MSP..."
mkdir -p $MSP_DIR/tlscacerts
cp $ORDERER_TLS_DIR/ca.crt $MSP_DIR/tlscacerts/tls-ca-cert.pem
if [ $? -ne 0 ]; then echo "⛔ Failed to copy TLS CA cert to orderer node MSP."; exit 1; fi
echo "✅ TLS CA cert copied to orderer node MSP successfully."

echo "✅ Orderer node identity and TLS setup complete."
echo "ℹ️ Check the output above for success or failure messages from the fabric-ca-client."

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
#                     ├── tlscacerts/
#                     │   └── tls-ca-cert.pem
#                     ├── IssuerPublicKey
#                     ├── IssuerRevocationPublicKey
#                     └── user/
