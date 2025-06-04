#!/bin/bash

# Source helper scripts
source "$(dirname "$0")/helper/ssh-utils.sh"

# Fixed TLS CA details
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
    CA_URL="https://${CA_HOST}:${CA_PORT}"
    
    # Define identity names and credentials
    BOOTSTRAP_USER="btstrp-${ORG}"
    BOOTSTRAP_MSP="${ORG}-ca/${BOOTSTRAP_USER}/msp"
    PEER_NAME="peer.${DOMAIN}"
    ADMIN_NAME="${ORG}admin"
    PEER_SECRET="${ORG}peerpw"
    ADMIN_SECRET="${ORG}adminpw"

    # Define MSP directories
    PEER_MSP="organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/msp"
    ADMIN_MSP="organizations/peerOrganizations/${DOMAIN}/users/Admin@${DOMAIN}/msp"
    ORG_MSP="organizations/peerOrganizations/${DOMAIN}/msp"
    PEER_TLS_DIR="organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls"

    echo "⚙️ Bootstrapping $ORG identities (peer, admin, TLS) at $IP..."

    # Setup script for initial directory creation
    SETUP_SCRIPT="""
set -e
cd ~/fabric
# Create directories
mkdir -p $PEER_MSP $ADMIN_MSP $ORG_MSP/cacerts $ORG_MSP/tlscacerts $PEER_TLS_DIR

# Set fabric-ca-client home
cd $HOME_DIR
export FABRIC_CA_CLIENT_HOME=\$PWD
"""
    ssh_exec_script "$IP" "$SETUP_SCRIPT" "Failed to create directories" || continue

    # Register peer identity with org CA
    register_identity "$IP" "$PEER_NAME" "$PEER_SECRET" "peer" "$CA_URL" "$BOOTSTRAP_MSP" "tls-root-cert/tls-ca-cert.pem" || continue
    echo "  ✅ Peer identity registered"

    # Register admin identity with org CA
    register_identity "$IP" "$ADMIN_NAME" "$ADMIN_SECRET" "admin" "$CA_URL" "$BOOTSTRAP_MSP" "tls-root-cert/tls-ca-cert.pem" || continue
    echo "  ✅ Admin identity registered"

    # Enroll peer identity
    enroll_identity "$IP" "$PEER_NAME" "$PEER_SECRET" "$CA_HOST:$CA_PORT" "~/fabric/$PEER_MSP" "tls-root-cert/tls-ca-cert.pem" || continue
    echo "  ✅ Peer identity enrolled"

    # Enroll admin identity
    enroll_identity "$IP" "$ADMIN_NAME" "$ADMIN_SECRET" "$CA_HOST:$CA_PORT" "~/fabric/$ADMIN_MSP" "tls-root-cert/tls-ca-cert.pem" || continue
    echo "  ✅ Admin identity enrolled"

    # Rename private keys
    copy_msp_files "$IP" "~/fabric/$PEER_MSP" "~/fabric/$PEER_MSP" "key" || continue
    copy_msp_files "$IP" "~/fabric/$ADMIN_MSP" "~/fabric/$ADMIN_MSP" "key" || continue
    echo "  ✅ Private keys renamed"

    # Copy certificates for org MSP
    CERT_SCRIPT="""
cd ~/fabric
cp $PEER_MSP/cacerts/* $ORG_MSP/cacerts/
cp tls-root-cert/tls-ca-cert.pem $ORG_MSP/tlscacerts/tls-ca-cert.pem
"""
    ssh_exec_script "$IP" "$CERT_SCRIPT" "Failed to copy certificates" || continue
    echo "  ✅ Certificates copied to Org MSP"

    # Get CA cert filename for MSP config
    CACERT_SCRIPT="ls ~/fabric/$ORG_MSP/cacerts/*.pem | head -n 1 | xargs basename"
    CACERT_FILENAME=$(ssh_exec "$IP" "$CACERT_SCRIPT")

    # Create MSP config files
    create_msp_config "$IP" "~/fabric/$ORG_MSP" "$CACERT_FILENAME" || continue
    create_msp_config "$IP" "~/fabric/$PEER_MSP" "$CACERT_FILENAME" || continue
    create_msp_config "$IP" "~/fabric/$ADMIN_MSP" "$CACERT_FILENAME" || continue
    echo "  ✅ MSP config files created"

    # Verify TLS admin credentials
    if ! verify_remote_file "$IP" "tls-ca/tlsadmin/msp/signcerts/cert.pem"; then
        echo "  ⛔ Error: TLS admin credentials not found. Ensure script 03 and 11 ran successfully."
        continue
    fi
    echo "  ✅ TLS admin credentials found"

    # Register peer with TLS CA
    register_identity "$IP" "$PEER_NAME" "$PEER_SECRET" "peer" "$TLS_CA_URL" "tls-ca/tlsadmin/msp" "tls-root-cert/tls-ca-cert.pem" || continue
    echo "  ✅ Peer registered with TLS CA"

    # Enroll peer with TLS CA
    enroll_identity "$IP" "$PEER_NAME" "$PEER_SECRET" "$TLS_CA_HOST:$TLS_CA_PORT" "~/fabric/$PEER_TLS_DIR" "tls-root-cert/tls-ca-cert.pem" "--csr.hosts $PEER_NAME --enrollment.profile tls" || continue
    echo "  ✅ Peer enrolled with TLS CA"

    # Setup TLS certificates
    TLS_SETUP_SCRIPT="""
cd ~/fabric
cp $PEER_TLS_DIR/signcerts/cert.pem $PEER_TLS_DIR/server.crt
KEY_FILE=\$(find $PEER_TLS_DIR/keystore -type f | head -n 1)
cp "\$KEY_FILE" $PEER_TLS_DIR/server.key

# Setup TLS CA certs in various locations
mkdir -p $PEER_TLS_DIR/tlscacerts $PEER_MSP/tlscacerts $ADMIN_MSP/tlscacerts
cp tls-root-cert/tls-ca-cert.pem $PEER_TLS_DIR/tlscacerts/tls-ca-cert.pem
cp tls-root-cert/tls-ca-cert.pem $PEER_TLS_DIR/ca.crt
cp tls-root-cert/tls-ca-cert.pem $PEER_MSP/tlscacerts/tls-ca-cert.pem
cp tls-root-cert/tls-ca-cert.pem $ADMIN_MSP/tlscacerts/tls-ca-cert.pem
"""
    ssh_exec_script "$IP" "$TLS_SETUP_SCRIPT" "Failed to setup TLS certificates" || continue
    echo "  ✅ TLS certificates setup completed"

    echo "✅ Successfully bootstrapped identities for $ORG at $IP."
    echo "-----------------------------------------------------"
done

echo "🎉 All organizations have been bootstrapped."
