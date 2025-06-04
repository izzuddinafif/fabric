#!/bin/bash
# Configuration file for organization IPs and names

# Organization names
ORGS=("Org1" "Org2")

# Org IPs - Change these when moving to new VPSes
ORG_IPS=("10.104.0.2" "10.104.0.4")

# Orderer configuration
ORDERER_IP="10.104.0.3"
ORDERER_DOMAIN="fabriczakat.local"
ORDERER_NAME="orderer"
ORDERER_HOSTNAME="${ORDERER_NAME}.${ORDERER_DOMAIN}"

# Organization domains and hostnames
ORG_DOMAIN="fabriczakat.local"

# Generate arrays for domains and hostnames
declare -a ORG_DOMAINS
declare -a ORG_HOSTNAMES
for org in "${ORGS[@]}"; do
    ORG_DOMAINS+=("${org,,}.${ORG_DOMAIN}")  # e.g., org1.fabriczakat.local
    ORG_HOSTNAMES+=("peer.${org,,}.${ORG_DOMAIN}")  # e.g., peer.org1.fabriczakat.local
done
