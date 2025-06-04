#!/bin/bash
# Start CA servers using Docker on their respective hosts
set -e

# Source the configuration file
source "$(dirname "$0")/config/orgs-config.sh"

echo "🚀 Starting CA servers on their respective hosts..."

# Start TLS CA on the orderer machine
echo "🔐 Starting TLS CA server on $ORDERER_IP..."

# Copy Docker Compose template and create directories
ssh fabricadmin@$ORDERER_IP "mkdir -p ~/fabric/docker ~/fabric/ca/tls"
scp docker/templates/docker-compose-ca.yaml fabricadmin@$ORDERER_IP:~/fabric/docker/

# Create TLS CA environment file
cat << EOF > /tmp/tls-ca.env
CONTAINER_NAME=ca_tls.${ORDERER_DOMAIN}
CA_NAME=tls-ca
CSR_CN=tls-ca
CSR_HOSTS=0.0.0.0,tls-ca.${ORDERER_DOMAIN}
BOOTSTRAP_USER=tls-admin
BOOTSTRAP_PASS=tls-adminpw
CA_VOLUME=../fabric/ca/tls
EOF

# Copy environment file and start TLS CA
scp /tmp/tls-ca.env fabricadmin@$ORDERER_IP:~/fabric/docker/ca.env
rm /tmp/tls-ca.env
ssh fabricadmin@$ORDERER_IP "cd ~/fabric && docker compose --env-file docker/ca.env -f docker/docker-compose-ca.yaml up -d"
if [ $? -ne 0 ]; then
    echo "⛔ Failed to start TLS CA on $ORDERER_IP"
    exit 1
fi
echo "✅ TLS CA server started on $ORDERER_IP"

# Start Orderer CA on the orderer machine
echo "🏛️ Starting Orderer CA server on $ORDERER_IP..."

# Create directories
ssh fabricadmin@$ORDERER_IP "mkdir -p ~/fabric/ca/orderer"

# Create Orderer CA environment file
cat << EOF > /tmp/orderer-ca.env
CONTAINER_NAME=ca_orderer.${ORDERER_DOMAIN}
CA_NAME=orderer-ca
CSR_CN=orderer-ca
CSR_HOSTS=0.0.0.0,${ORDERER_HOSTNAME}
CA_VOLUME=../fabric/ca/orderer
EOF

# Copy environment file and start Orderer CA
scp /tmp/orderer-ca.env fabricadmin@$ORDERER_IP:~/fabric/docker/ca.env
rm /tmp/orderer-ca.env
ssh fabricadmin@$ORDERER_IP "cd ~/fabric && docker compose --env-file docker/ca.env -f docker/docker-compose-ca.yaml up -d"
if [ $? -ne 0 ]; then
    echo "⛔ Failed to start Orderer CA on $ORDERER_IP"
    exit 1
fi
echo "✅ Orderer CA server started on $ORDERER_IP"

# Start Organization CAs on their respective machines
for i in "${!ORGS[@]}"; do
    ORG=${ORGS[$i]}
    ORG_IP=${ORG_IPS[$i]}
    ORG_DOMAIN=${ORG_DOMAINS[$i]}
    
    echo "🏢 Starting ${ORG} CA server on $ORG_IP..."
    
    # Create directories and copy template
    ssh fabricadmin@$ORG_IP "mkdir -p ~/fabric/docker ~/fabric/ca/${ORG,,}"
    scp docker/templates/docker-compose-ca.yaml fabricadmin@$ORG_IP:~/fabric/docker/

    # Create environment file for org CA
    cat << EOF > /tmp/org-ca.env
CONTAINER_NAME=ca_${ORG,,}.${ORDERER_DOMAIN}
CA_NAME=${ORG,,}-ca
CSR_CN=${ORG,,}-ca
CSR_HOSTS=0.0.0.0,${ORG_DOMAIN}
CA_VOLUME=../fabric/ca/${ORG,,}
EOF
    
    # Copy environment file and start Org CA
    scp /tmp/org-ca.env fabricadmin@$ORG_IP:~/fabric/docker/ca.env
    rm /tmp/org-ca.env
    ssh fabricadmin@$ORG_IP "cd ~/fabric && docker compose --env-file docker/ca.env -f docker/docker-compose-ca.yaml up -d"
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to start ${ORG} CA on $ORG_IP"
        exit 1
    fi
    echo "✅ ${ORG} CA server started on $ORG_IP"
done

# Verify all CA containers are running
echo "🔍 Verifying CA containers..."

# Check TLS and Orderer CAs
for container in "ca_tls.${ORDERER_DOMAIN}" "ca_orderer.${ORDERER_DOMAIN}"; do
    if ! ssh fabricadmin@$ORDERER_IP "docker ps | grep -q $container"; then
        echo "⛔ Container $container is not running on $ORDERER_IP"
        echo "📋 Container logs:"
        ssh fabricadmin@$ORDERER_IP "docker logs $container"
        exit 1
    fi
done

# Check Organization CAs
for i in "${!ORGS[@]}"; do
    ORG=${ORGS[$i]}
    ORG_IP=${ORG_IPS[$i]}
    container="ca_${ORG,,}.${ORDERER_DOMAIN}"
    
    if ! ssh fabricadmin@$ORG_IP "docker ps | grep -q $container"; then
        echo "⛔ Container $container is not running on $ORG_IP"
        echo "📋 Container logs:"
        ssh fabricadmin@$ORG_IP "docker logs $container"
        exit 1
    fi

    echo "✅ Container $container is running on $ORG_IP"
done

echo "🎉 All CA servers started successfully!"
echo ""
echo "CA Server Endpoints:"
echo "- TLS CA: $ORDERER_IP:7054"
echo "- Orderer CA: $ORDERER_IP:7054"
for i in "${!ORGS[@]}"; do
    echo "- ${ORGS[$i]} CA: ${ORG_IPS[$i]}:7054"
done
echo ""
echo "Next Steps:"
echo "1. Register and enroll entities"
echo "2. Generate TLS certificates"
echo "3. Deploy the orderer and peers"
echo "----------------------------------------"

exit 0
