#!/bin/bash
# TLS CA
if [ -d $HOME/fabric/fabric-ca-server-tls ]; then
    echo "Directory $HOME/fabric/fabric-ca-server-tls already exists."
    echo "Assuming TLS CA server is already initialized."
    echo "✅ TLS CA initialization can be skipped."
    exit 0
fi

mkdir $HOME/fabric/fabric-ca-server-tls
cp $HOME/bin/fabric-ca-server $HOME/fabric/fabric-ca-server-tls
cd $HOME/fabric/fabric-ca-server-tls

./fabric-ca-server init -b tls-admin:tls-adminpw # bootstrap user and set FABRIC_CA_HOME here
echo "✅ TLS CA server initialized successfully."
