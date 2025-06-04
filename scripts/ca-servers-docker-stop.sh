#!/bin/bash
# Stop CA servers using Docker on their respective hosts
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

echo "🛑 Stopping CA servers on their respective hosts..."

# Stop Organization CAs on their respective machines
for i in "${!ORGS[@]}"; do
    ORG=${ORGS[$i]}
    ORG_IP=${ORG_IPS[$i]}
    
    echo "🏢 Stopping ${ORG} CA server on $ORG_IP..."
    
    # Create temporary env file for compose down
    cat << EOF > /tmp/org-ca.env
CONTAINER_NAME=ca_${ORG,,}.${ORDERER_DOMAIN}
EOF
    
    # Copy env file and stop container
    scp /tmp/org-ca.env fabricadmin@$ORG_IP:~/fabric/docker/ca.env
    rm /tmp/org-ca.env
    ssh fabricadmin@$ORG_IP "cd ~/fabric && docker compose --env-file docker/ca.env -f docker/docker-compose-ca.yaml down"
    if [ $? -ne 0 ]; then
        echo "⚠️ Warning: Error stopping ${ORG} CA on $ORG_IP"
    fi

    # Force remove container if it still exists
    container="ca_${ORG,,}.${ORDERER_DOMAIN}"
    if ssh fabricadmin@$ORG_IP "docker ps -a | grep -q $container"; then
        echo "⚠️ Container $container still exists on $ORG_IP, forcing removal..."
        ssh fabricadmin@$ORG_IP "docker rm -f $container" || true
    fi
done

echo "🏛️ Stopping Orderer CA server on $ORDERER_IP..."
cat << EOF > /tmp/orderer-ca.env
CONTAINER_NAME=ca_orderer.${ORDERER_DOMAIN}
EOF
scp /tmp/orderer-ca.env fabricadmin@$ORDERER_IP:~/fabric/docker/ca.env
rm /tmp/orderer-ca.env
ssh fabricadmin@$ORDERER_IP "cd ~/fabric && docker compose --env-file docker/ca.env -f docker/docker-compose-ca.yaml down"
if [ $? -ne 0 ]; then
    echo "⚠️ Warning: Error stopping Orderer CA"
fi

echo "🔐 Stopping TLS CA server on $ORDERER_IP..."
cat << EOF > /tmp/tls-ca.env
CONTAINER_NAME=ca_tls.${ORDERER_DOMAIN}
EOF
scp /tmp/tls-ca.env fabricadmin@$ORDERER_IP:~/fabric/docker/ca.env
rm /tmp/tls-ca.env
ssh fabricadmin@$ORDERER_IP "cd ~/fabric && docker compose --env-file docker/ca.env -f docker/docker-compose-ca.yaml down"
if [ $? -ne 0 ]; then
    echo "⚠️ Warning: Error stopping TLS CA"
fi

# Force remove containers if they still exist on orderer machine
for container in "ca_tls.${ORDERER_DOMAIN}" "ca_orderer.${ORDERER_DOMAIN}"; do
    if ssh fabricadmin@$ORDERER_IP "docker ps -a | grep -q $container"; then
        echo "⚠️ Container $container still exists on $ORDERER_IP, forcing removal..."
        ssh fabricadmin@$ORDERER_IP "docker rm -f $container" || true
    fi
done

# Verify all CA containers are stopped
echo "🔍 Verifying CA containers are stopped..."

# Check orderer machine
echo "Checking $ORDERER_IP..."
running_containers=$(ssh fabricadmin@$ORDERER_IP "docker ps --format '{{.Names}}' | grep -E 'ca_(tls|orderer)'") || true
if [ ! -z "$running_containers" ]; then
    echo "⚠️ Found running CA containers on $ORDERER_IP:"
    echo "$running_containers"
fi

# Check organization machines
for i in "${!ORGS[@]}"; do
    ORG=${ORGS[$i]}
    ORG_IP=${ORG_IPS[$i]}
    
    echo "Checking $ORG_IP..."
    running_containers=$(ssh fabricadmin@$ORG_IP "docker ps --format '{{.Names}}' | grep 'ca_${ORG,,}'") || true
    if [ ! -z "$running_containers" ]; then
        echo "⚠️ Found running CA containers on $ORG_IP:"
        echo "$running_containers"
    fi
done

echo "✅ All CA servers stopped successfully!"
echo ""
echo "Note: CA directories and certificates are preserved at:"
echo "- Orderer machine ($ORDERER_IP): ~/fabric/ca/"
for i in "${!ORGS[@]}"; do
    echo "- ${ORGS[$i]} machine (${ORG_IPS[$i]}): ~/fabric/ca/"
done
echo ""
echo "Run ca-servers-docker-start.sh to restart the CA servers."
echo "----------------------------------------"

exit 0
