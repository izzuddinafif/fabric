#!/bin/bash

declare -A ORGS=(
    ["10.104.0.2"]="org1"
    ["10.104.0.4"]="org2"
)

# Fix the TLS CA URL to avoid protocol duplication
TLS_CA_HOST="tls.fabriczakat.local"
TLS_CA_PORT="7054"
TLS_CA_URL="https://${TLS_CA_HOST}:${TLS_CA_PORT}"
TLS_CERT_PATH="/home/fabricadmin/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem"
HOME_DIR="/home/fabricadmin/fabric/fabric-ca-client"

for IP in "${!ORGS[@]}"; do
    ORG="${ORGS[$IP]}"
    DOMAIN="${ORG}.fabriczakat.local"
    CA_HOST="ca.${DOMAIN}"
    CA_PORT="7054"
    BOOTSTRAP_USER="btstrp-${ORG}"
    BOOTSTRAP_MSP="${ORG}-ca/${BOOTSTRAP_USER}/msp"
    PEER_NAME="peer.${DOMAIN}"
    ADMIN_NAME="${ORG}admin"
    PEER_SECRET="${ORG}peerpw"
    ADMIN_SECRET="${ORG}adminpw"

    PEER_MSP="organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/msp"
    ADMIN_MSP="organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp"
    ORG_MSP="organizations/peerOrganizations/${DOMAIN}/msp"
    PEER_TLS_DIR="organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls"

    echo "⚙️ Bootstrapping $ORG identities (peer, admin, TLS) at $IP..."

    ssh "fabricadmin@$IP" """
echo \"  🚀 Starting identity bootstrapping process on $IP for $ORG...\"

# Create directories
echo \"  📁 Ensuring MSP and TLS directories exist...\"
mkdir -p ~/fabric/$PEER_MSP ~/fabric/$ADMIN_MSP ~/fabric/$ORG_MSP/cacerts ~/fabric/$ORG_MSP/tlscacerts ~/fabric/$PEER_TLS_DIR
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to create initial directories\"; exit 1; fi
echo \"  ✅ Initial directories ensured.\"

# Configure HOME so the CA client knows where to store data
cd ~/fabric/fabric-ca-client
export FABRIC_CA_CLIENT_HOME=\$PWD
echo \"  ℹ️ Set FABRIC_CA_CLIENT_HOME to \$PWD\"

# Register peer identity with org CA
echo \"  ✍️ Registering peer identity '$PEER_NAME' with $ORG CA...\"
PEER_REG_OUTPUT=\$(~/bin/fabric-ca-client register -d \\
  --id.name $PEER_NAME \\
  --id.secret $PEER_SECRET \\
  --id.type peer \\
  --mspdir $BOOTSTRAP_MSP \\
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \\
  -u https://$CA_HOST:$CA_PORT 2>&1)

PEER_REG_EXIT=\$?

if [ \$PEER_REG_EXIT -ne 0 ]; then
    if echo \"\$PEER_REG_OUTPUT\" | grep -q \"Error Code: 74\"; then
        echo \"  ✅ Peer identity '$PEER_NAME' already registered (continuing)\"
    else
        echo \"  ⛔ Failed to register peer '$PEER_NAME' with unexpected error:\"
        echo \"\$PEER_REG_OUTPUT\"
        exit 1
    fi
else
    echo \"  ✅ Peer identity '$PEER_NAME' registered successfully\"
fi

# Register admin identity with org CA
echo \"  ✍️ Registering admin identity '$ADMIN_NAME' with $ORG CA...\"
ADMIN_REG_OUTPUT=\$(~/bin/fabric-ca-client register -d \\
  --id.name $ADMIN_NAME \\
  --id.secret $ADMIN_SECRET \\
  --id.type admin \\
  --mspdir $BOOTSTRAP_MSP \\
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \\
  -u https://$CA_HOST:$CA_PORT 2>&1)

ADMIN_REG_EXIT=\$?

if [ \$ADMIN_REG_EXIT -ne 0 ]; then
    if echo \"\$ADMIN_REG_OUTPUT\" | grep -q \"Error Code: 74\"; then
        echo \"  ✅ Admin identity '$ADMIN_NAME' already registered (continuing)\"
    else
        echo \"  ⛔ Failed to register admin '$ADMIN_NAME' with unexpected error:\"
        echo \"\$ADMIN_REG_OUTPUT\"
        exit 1
    fi
else
    echo \"  ✅ Admin identity '$ADMIN_NAME' registered successfully\"
fi

# Enroll peer identity
echo \"  🔐 Enrolling peer identity '$PEER_NAME'...\"
~/bin/fabric-ca-client enroll -d \\
  -u https://$PEER_NAME:$PEER_SECRET@$CA_HOST:$CA_PORT \\
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \\
  --mspdir ~/fabric/$PEER_MSP
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to enroll peer '$PEER_NAME'\"; exit 1; fi
echo \"  ✅ Peer identity '$PEER_NAME' enrolled.\"

# Enroll admin identity
echo \"  🔐 Enrolling admin identity '$ADMIN_NAME'...\"
~/bin/fabric-ca-client enroll -d \\
  -u https://$ADMIN_NAME:$ADMIN_SECRET@$CA_HOST:$CA_PORT \\
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \\
  --mspdir ~/fabric/$ADMIN_MSP
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to enroll admin '$ADMIN_NAME'\"; exit 1; fi
echo \"  ✅ Admin identity '$ADMIN_NAME' enrolled.\"

# Rename keys for consistency
echo \"  📄 Renaming private keys...\"
if [ -d ~/fabric/$PEER_MSP/keystore ]; then
    find ~/fabric/$PEER_MSP/keystore -name \"*_sk\" -exec mv {} ~/fabric/$PEER_MSP/keystore/key.pem \\;
fi
if [ -d ~/fabric/$ADMIN_MSP/keystore ]; then
    find ~/fabric/$ADMIN_MSP/keystore -name \"*_sk\" -exec mv {} ~/fabric/$ADMIN_MSP/keystore/key.pem \\;
fi
echo \"  ✅ Private keys renamed.\"

# Copy certificates for org MSP
echo \"  📄 Copying certificates to Org MSP...\"
cp ~/fabric/$PEER_MSP/cacerts/* ~/fabric/$ORG_MSP/cacerts/
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to copy CA cert to Org MSP\"; exit 1; fi
cp tls-root-cert/tls-ca-cert.pem ~/fabric/$ORG_MSP/tlscacerts/tls-ca-cert.pem
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to copy TLS CA cert to Org MSP\"; exit 1; fi
echo \"  ✅ Certificates copied to Org MSP.\"

# Create MSP config files
echo \"  📝 Creating MSP config.yaml files...\"
CACERT=\$(ls ~/fabric/$ORG_MSP/cacerts/*.pem | head -n 1)
if [ -z \"\$CACERT\" ]; then echo \"  ⛔ CA cert not found in ~/fabric/$ORG_MSP/cacerts/\"; exit 1; fi
CACERT_FILENAME=\$(basename \$CACERT)

# Create ORG MSP config.yaml
cat > ~/fabric/$ORG_MSP/config.yaml <<YAML
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: orderer
YAML
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to create Org MSP config.yaml\"; exit 1; fi

# Create PEER MSP config.yaml
cat > ~/fabric/$PEER_MSP/config.yaml <<YAML
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: orderer
YAML
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to create Peer MSP config.yaml\"; exit 1; fi

# Create ADMIN MSP config.yaml
cat > ~/fabric/$ADMIN_MSP/config.yaml <<YAML
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/\$CACERT_FILENAME
    OrganizationalUnitIdentifier: orderer
YAML
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to create Admin MSP config.yaml\"; exit 1; fi
echo \"  ✅ MSP config.yaml files created.\"

# Verify TLS admin MSP exists
echo \"  🔎 Verifying TLS admin credentials...\"
if [ ! -f \"tls-ca/tlsadmin/msp/signcerts/cert.pem\" ]; then
  echo \"  ⛔ Error: TLS admin credentials not found. Ensure script 03 and 11 ran successfully.\"
  exit 1
fi
echo \"  ✅ TLS admin credentials found.\"

# Register peer with TLS CA using TLS admin identity
echo \"  ✍️ Registering peer '$PEER_NAME' with TLS CA...\"
TLS_REG_OUTPUT=\$(~/bin/fabric-ca-client register -d \\
  --id.name $PEER_NAME \\
  --id.secret $PEER_SECRET \\
  --id.type peer \\
  -u $TLS_CA_URL \\
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \\
  --mspdir tls-ca/tlsadmin/msp 2>&1)

TLS_REG_EXIT=\$?

if [ \$TLS_REG_EXIT -ne 0 ]; then
    if echo \"\$TLS_REG_OUTPUT\" | grep -q \"Error Code: 74\"; then
        echo \"  ✅ Peer '$PEER_NAME' already registered with TLS CA (continuing)\"
    else
        echo \"  ⛔ Failed to register peer '$PEER_NAME' with TLS CA:\"
        echo \"\$TLS_REG_OUTPUT\"
        exit 1
    fi
else
    echo \"  ✅ Peer '$PEER_NAME' registered with TLS CA successfully\"
fi

# Enroll peer with TLS CA
echo \"  🔐 Enrolling peer '$PEER_NAME' with TLS CA...\"
~/bin/fabric-ca-client enroll -d \\
  -u https://$PEER_NAME:$PEER_SECRET@$TLS_CA_HOST:$TLS_CA_PORT \\
  --csr.hosts $PEER_NAME \\
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \\
  --enrollment.profile tls \\
  --mspdir ~/fabric/$PEER_TLS_DIR
if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to enroll peer '$PEER_NAME' with TLS CA\"; exit 1; fi
echo \"  ✅ Peer '$PEER_NAME' enrolled with TLS CA.\"

# Setup the TLS certificates
echo \"  ⚙️ Setting up peer TLS certificates...\"
if [ -d ~/fabric/$PEER_TLS_DIR/keystore ] && [ -d ~/fabric/$PEER_TLS_DIR/signcerts ]; then
  
  # Copy the cert
  cp ~/fabric/$PEER_TLS_DIR/signcerts/cert.pem ~/fabric/$PEER_TLS_DIR/server.crt
  if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to copy TLS server cert\"; exit 1; fi
  
  # Find and copy the key file
  if [ -d ~/fabric/$PEER_TLS_DIR/keystore ]; then
      find ~/fabric/$PEER_TLS_DIR/keystore -name \"*_sk\" -exec cp {} ~/fabric/$PEER_TLS_DIR/server.key \\;
  fi
  
  # Copy the TLS CA cert
  mkdir -p ~/fabric/$PEER_TLS_DIR/tlscacerts
  cp tls-root-cert/tls-ca-cert.pem ~/fabric/$PEER_TLS_DIR/tlscacerts/tls-ca-cert.pem
  if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to copy TLS CA cert to peer TLS tlscacerts\"; exit 1; fi
  cp tls-root-cert/tls-ca-cert.pem ~/fabric/$PEER_TLS_DIR/ca.crt
  if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to copy TLS CA cert to peer TLS ca.crt\"; exit 1; fi
  
  # Copy TLS cert to MSP folder
  mkdir -p ~/fabric/$PEER_MSP/tlscacerts
  cp tls-root-cert/tls-ca-cert.pem ~/fabric/$PEER_MSP/tlscacerts/tls-ca-cert.pem
  if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to copy TLS CA cert to Peer MSP tlscacerts\"; exit 1; fi

  # Also copy TLS cert to Admin MSP folder
  mkdir -p ~/fabric/$ADMIN_MSP/tlscacerts
  cp tls-root-cert/tls-ca-cert.pem ~/fabric/$ADMIN_MSP/tlscacerts/tls-ca-cert.pem
  if [ \$? -ne 0 ]; then echo \"  ⛔ Failed to copy TLS CA cert to Admin MSP tlscacerts\"; exit 1; fi
  
  echo \"  ✅ TLS certificates for $PEER_NAME set up successfully.\"
else
  echo \"  ⛔ Failed to set up TLS certificates for $PEER_NAME - enrollment may have failed.\"
  ls -la ~/fabric/$PEER_TLS_DIR
  exit 1
fi

echo \"✅ Finished enrolling identities and TLS for $ORG on $IP.\"
"""

    # Check the exit status of the SSH command
    if [ $? -eq 0 ]; then
        echo "✅ Successfully bootstrapped identities for $ORG at $IP."
    else
        echo "⛔ Failed to bootstrap identities for $ORG at $IP. Check logs on the remote machine."
    fi
    echo "-----------------------------------------------------"

done

echo "🎉 All organizations have been bootstrapped."