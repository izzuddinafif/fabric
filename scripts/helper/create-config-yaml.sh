#!/bin/bash
set -e

CACERT=$1
MSP_DIR=$2

cat > $MSP_DIR/config.yaml <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename "$CACERT")
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename "$CACERT")
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename "$CACERT")
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename "$CACERT")
    OrganizationalUnitIdentifier: orderer
EOF