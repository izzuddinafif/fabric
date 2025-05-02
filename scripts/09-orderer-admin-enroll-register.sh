#!/bin/bash
# set -e

# Ensure the client config directory exists
if ! [ -d "$HOME/fabric/fabric-ca-client" ]; then
    echo "Directory $HOME/fabric/fabric-ca-client does not exist. Exiting."
    exit 1
fi

# Ensure the TLS root cert exists
if ! [ -f "$HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem" ]; then
    echo "TLS root certificate $HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem not found."
    exit 1
fi

cd $HOME/fabric/fabric-ca-client
# Set Fabric CA Client home directory
export FABRIC_CA_CLIENT_HOME=$HOME/fabric/fabric-ca-client

# Register the orderer identity and admin identity using btstrp-orderer credentials
# The --id.name specifies the identity being registered (orderer.fabriczakat.local)
# The --id.secret specifies the password for the new identity
# The --id.type specifies the role (orderer)
# The --mspdir points to the MSP of the registrar (btstrp-orderer)
# The --tls.certfiles points to the TLS CA's root certificate
# The URL points to the Orderer CA server

MSP_DIR=$HOME/fabric/organizations/ordererOrganization/fabriczakat.local/users/Admin@fabriczakat.local/msp
MSP_DIR_ORG=$HOME/fabric/organizations/ordererOrganization/fabriczakat.local/msp

# organizations/
# └── ordererOrganizations/
#     └── fabriczakat.local/
#         ├── msp/                          ← Org-wide MSP (trust anchors + config.yaml)
#         ├── orderers/
#         │   └── orderer.fabriczakat.local/
#         │       ├── msp/                  ← Identity MSP of the orderer node
#         │       └── tls/                  ← TLS identity of the orderer node
#         └── users/
#             └── Admin@fabriczakat.local/
#                 └── msp/                  ← Admin MSP for lifecycle ops


mkdir -p $MSP_DIR $MSP_DIR_ORG/cacerts $MSP_DIR_ORG/tlscacerts

# Register the orderer admin identity
./fabric-ca-client register -d \
  --id.name ordereradmin \
  --id.secret ordereradminpw \
  --id.type admin \
  --mspdir orderer-ca/btstrp-orderer/msp \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  -u https://ca.orderer.fabriczakat.local:7055

# Enroll the orderer admin identity
./fabric-ca-client enroll -d \
  -u https://ordereradmin:ordereradminpw@ca.orderer.fabriczakat.local:7055 \
  --tls.certfiles tls-root-cert/tls-ca-cert.pem \
  --mspdir $MSP_DIR

# rename the private key and cert files
mv $MSP_DIR/keystore/*_sk $MSP_DIR/keystore/orderer-admin-key.pem
mv $MSP_DIR/signcerts/* $MSP_DIR/signcerts/orderer-admin-cert.pem

# create a config.yaml file for the orderer admin identity
CACERT=$(ls "$MSP_DIR/cacerts"/*.pem | head -n 1)

if [ -z "$CACERT" ]; then
  echo "Error: No .pem found in $MSP_DIR/cacerts"
  exit 1
fi

./../scripts/helper/create-config-yaml.sh $CACERT $MSP_DIR

cp ../fabric-ca-server-orderer/ca-cert.pem $MSP_DIR_ORG/cacerts/orderer-ca-cert.pem
cp ./tls-root-cert/tls-ca-cert.pem $MSP_DIR_ORG/tlscacerts/tls-ca-cert.pem

# create a config.yaml file for the orderer org identity
CACERTORG=$(ls "$MSP_DIR_ORG/cacerts"/*.pem | head -n 1)

if [ -z "$CACERTORG" ]; then
  echo "Error: No .pem found in $MSP_DIR_ORG/cacerts"
  exit 1
fi

./../scripts/helper/create-config-yaml.sh $CACERTORG $MSP_DIR_ORG

# In Fabric CA, identities (names) are registered once, but can be enrolled multiple times,
# each enrollment creates a new cert/key pair. Revoking a cert disables it, but the identity remains.
# To fully disable an identity, revoke all its certs — there's no CLI to delete the identity itself.

echo "Orderer admin identity registration and enrollment attempt complete."
echo "Check the output above for success or failure messages from the fabric-ca-client."

# excerpt from HLF CA documentation:
# While it is possible for the admin of a CA to create an identity and give the public/private key pair to a user out of band, this process would give the CA admin access to the private key of every user. Such an arrangement violates basic security procedures regarding the security of private keys, which should not be exposed for any reason.
# As a result, CA admins register users, a process in which the CA admin gives an enroll ID and secret (these are similar to a username and password) to an identity and assigns it a role and any required attributes. The CA admin then gives this enroll ID and secret to the ultimate user of the identity. The user can then execute a Fabric CA client enroll command using this enroll ID and secret, returning the public/private key pair containing the role and attributes assigned by the CA admin.
# This process preserves both the integrity of the CA (because only CA admins can register users and assign roles and affiliations) and private keys (since only the user of an identity will have access to them).