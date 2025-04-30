#!/bin/bash
# TLS CA
if [-d $HOME/fabric/fabric-ca-server-tls]; then
    echo "Directory $HOME/fabric/fabric-ca-server-tls already exists. Exiting."
    exit 1
fi

mkdir $HOME/fabric/fabric-ca-server-tls
cp $HOME/fabric/bin/fabric-ca-server $HOME/fabric/fabric-ca-server-tls
cd $HOME/fabric/fabric-ca-server-tls

./fabric-ca-server init -b tls-admin:tls-adminpw # bootstrap user and set FABRIC_CA_HOME here
