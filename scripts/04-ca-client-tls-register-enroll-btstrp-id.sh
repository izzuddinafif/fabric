#!/bin/bash
# IMPORTANT SCRIPT!

# Make sure the directory exists before changing to it
if [ ! -d "$HOME/fabric/fabric-ca-client" ]; then
    echo "Directory $HOME/fabric/fabric-ca-client/ does not exist."
    echo "Creating directory..."
    mkdir -p $HOME/fabric/fabric-ca-client/
fi

cd $HOME/fabric/fabric-ca-client/
export FABRIC_CA_CLIENT_HOME=$PWD

# Ensure fabric-ca-client binary exists
if [ ! -x "$FABRIC_CA_CLIENT_HOME/fabric-ca-client" ]; then
    if [ -x "$HOME/fabric/bin/fabric-ca-client" ]; then
        cp $HOME/fabric/bin/fabric-ca-client $FABRIC_CA_CLIENT_HOME/
    elif [ -x "$HOME/bin/fabric-ca-client" ]; then
        cp $HOME/bin/fabric-ca-client $FABRIC_CA_CLIENT_HOME/
    else
        echo "⛔ Error: fabric-ca-client binary not found."
        exit 1
    fi
fi

# Ensure TLS root certificate exists
if [ ! -d "$FABRIC_CA_CLIENT_HOME/tls-root-cert" ]; then
    mkdir -p $FABRIC_CA_CLIENT_HOME/tls-root-cert
fi

if [ ! -f "$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem" ]; then
    if [ -f "$HOME/fabric/fabric-ca-server-tls/ca-cert.pem" ]; then
        cp $HOME/fabric/fabric-ca-server-tls/ca-cert.pem $FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem
    else
        echo "⛔ Error: TLS CA certificate not found."
        exit 1
    fi
fi

# Ensure TLS admin MSP directory exists (required for register command)
if [ ! -d "$FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp" ]; then
    echo "⛔ Error: TLS admin MSP directory not found. Script 03 may not have completed successfully."
    exit 1
fi

# Create tls-ca directory if it doesn't exist
if [ ! -d "$FABRIC_CA_CLIENT_HOME/tls-ca" ]; then
    mkdir -p $FABRIC_CA_CLIENT_HOME/tls-ca
fi

# Delete rcaadmin directories if they exist
if [ -d "$FABRIC_CA_CLIENT_HOME/tls-ca/rcaadmin-org1" ] || [ -d "$FABRIC_CA_CLIENT_HOME/tls-ca/rcaadmin-org2" ] || [ -d "$FABRIC_CA_CLIENT_HOME/tls-ca/rcaadmin-orderer" ]; then
    echo "Directory $FABRIC_CA_CLIENT_HOME/tls-ca/rcaadmin-* exists. Deleting."
    rm -rf $FABRIC_CA_CLIENT_HOME/tls-ca/rcaadmin-*
fi

# register the bootstrap users
# for Org1-CA
echo "🔐 Registering bootstrap user rcaadmin-org1 with TLS CA..."
REGISTER_OUTPUT_ORG1=$(./fabric-ca-client register -d \
    --id.name rcaadmin-org1 \
    --id.secret org1pw \
    -u https://tls.fabriczakat.local:7054  \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --mspdir tls-ca/tlsadmin/msp 2>&1) # Capture stdout and stderr

REGISTER_EXIT_CODE_ORG1=$?

if [ $REGISTER_EXIT_CODE_ORG1 -ne 0 ]; then
    if echo "$REGISTER_OUTPUT_ORG1" | grep -q "Error Code: 74"; then
        echo "INFO: Identity 'rcaadmin-org1' is already registered. Proceeding..."
    else
        echo "⛔ Failed to register rcaadmin-org1 with an unexpected error:"
        echo "$REGISTER_OUTPUT_ORG1"
        exit 1
    fi
fi

# Repeat similar blocks for rcaadmin-org2 and rcaadmin-orderer
# for Org2-CA
echo "🔐 Registering bootstrap user rcaadmin-org2 with TLS CA..."
REGISTER_OUTPUT_ORG2=$(./fabric-ca-client register -d \
    --id.name rcaadmin-org2 \
    --id.secret org2pw \
    -u https://tls.fabriczakat.local:7054  \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --mspdir tls-ca/tlsadmin/msp 2>&1)

REGISTER_EXIT_CODE_ORG2=$?

if [ $REGISTER_EXIT_CODE_ORG2 -ne 0 ]; then
    if echo "$REGISTER_OUTPUT_ORG2" | grep -q "Error Code: 74"; then
        echo "INFO: Identity 'rcaadmin-org2' is already registered. Proceeding..."
    else
        echo "⛔ Failed to register rcaadmin-org2 with an unexpected error:"
        echo "$REGISTER_OUTPUT_ORG2"
        exit 1
    fi
fi

# for Orderer-CA
echo "🔐 Registering bootstrap user rcaadmin-orderer with TLS CA..."
REGISTER_OUTPUT_ORDERER=$(./fabric-ca-client register -d \
    --id.name rcaadmin-orderer \
    --id.secret ordererpw \
    -u https://tls.fabriczakat.local:7054  \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --mspdir tls-ca/tlsadmin/msp 2>&1)

REGISTER_EXIT_CODE_ORDERER=$?

if [ $REGISTER_EXIT_CODE_ORDERER -ne 0 ]; then
    if echo "$REGISTER_OUTPUT_ORDERER" | grep -q "Error Code: 74"; then
        echo "INFO: Identity 'rcaadmin-orderer' is already registered. Proceeding..."
    else
        echo "⛔ Failed to register rcaadmin-orderer with an unexpected error:"
        echo "$REGISTER_OUTPUT_ORDERER"
        exit 1
    fi
fi

echo "✅ Bootstrap users registration check complete."


# enroll the bootstrap users
echo "🔐 Enrolling bootstrap users (rcaadmin-*) with TLS CA..."
# In this case, the --mspdir flag works a little differently.
# For the enroll command, the --mspdir flag indicates where to
# store the generated TLS certificates for the rcaadmin identity.

# Org1-CA's TLS cert
./fabric-ca-client enroll \
  -u https://rcaadmin-org1:org1pw@tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls \
  --csr.hosts 'ca.org1.fabriczakat.local' \
  --mspdir tls-ca/rcaadmin-org1/msp
if [ $? -ne 0 ]; then echo "⛔ Failed to enroll rcaadmin-org1"; exit 1; fi

# Org2-CA's TLS cert
./fabric-ca-client enroll \
  -u https://rcaadmin-org2:org2pw@tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls \
  --csr.hosts 'ca.org2.fabriczakat.local' \
  --mspdir tls-ca/rcaadmin-org2/msp
if [ $? -ne 0 ]; then echo "⛔ Failed to enroll rcaadmin-org2"; exit 1; fi

# Orderer-CA's TLS cert
./fabric-ca-client enroll \
  -u https://rcaadmin-orderer:ordererpw@tls.fabriczakat.local:7054 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --enrollment.profile tls \
  --csr.hosts 'ca.orderer.fabriczakat.local' \
  --mspdir tls-ca/rcaadmin-orderer/msp
if [ $? -ne 0 ]; then echo "⛔ Failed to enroll rcaadmin-orderer"; exit 1; fi
echo "✅ Bootstrap users enrolled successfully."


# Check for private key files before attempting to rename them
echo "📄 Renaming private key files..."
# Org1-CA
if [ -d "tls-ca/rcaadmin-org1/msp/keystore" ]; then
    # Use find to locate the key file, then rename it
    find tls-ca/rcaadmin-org1/msp/keystore -name "*_sk" -exec mv {} tls-ca/rcaadmin-org1/msp/keystore/key.pem \;
fi

# Org2-CA
if [ -d "tls-ca/rcaadmin-org2/msp/keystore" ]; then
    find tls-ca/rcaadmin-org2/msp/keystore -name "*_sk" -exec mv {} tls-ca/rcaadmin-org2/msp/keystore/key.pem \;
fi

# Orderer-CA
if [ -d "tls-ca/rcaadmin-orderer/msp/keystore" ]; then
    find tls-ca/rcaadmin-orderer/msp/keystore -name "*_sk" -exec mv {} tls-ca/rcaadmin-orderer/msp/keystore/key.pem \;
fi
echo "✅ Private key files renamed successfully."
echo "✅ Bootstrap user registration and enrollment complete."
