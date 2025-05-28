#!/bin/bash
cd $HOME/fabric/fabric-ca-server-tls

# Edit the fabric-ca-server-config.yaml file
if ! command -v yq &> /dev/null
then
    echo "yq could not be found, installing..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi

if [ -f fabric-ca-server-tls.pid ]; then
    PID=$(cat fabric-ca-server-tls.pid)
    if ps -p $PID > /dev/null; then
        echo "✅ TLS CA server is already running with PID $PID. Exiting."
        exit 0
    fi
fi

# check if the port 7054 is already in use and kill the process if it is
if lsof -i :7054 > /dev/null; then
    echo "Port 7054 is already in use. Killing process."
    sudo kill $(lsof -t -i:7054)
fi
# check if the port 9443 is already in use and kill the process if it is
if lsof -i :9443 > /dev/null; then
    echo "Port 9443 is already in use. Killing process."
    sudo kill $(lsof -t -i:9443)
fi

if [[ $(yq eval '.tls.enabled' fabric-ca-server-config.yaml) == "false" ]]; then
    yq eval '.tls.enabled = true' -i fabric-ca-server-config.yaml 
    yq eval 'del(.signing.profiles.ca)' -i fabric-ca-server-config.yaml # we only need tls signing profile for tls ca server
    yq eval '.ca.name = "tls-ca"' -i fabric-ca-server-config.yaml
    yq eval '.csr.hosts = ["localhost", "tls.fabriczakat.local"]' -i fabric-ca-server-config.yaml
    yq eval '.csr.names[0].C = "ID" | .csr.names[0].ST = "East Java" | .csr.names[0].L = "Surabaya"' -i fabric-ca-server-config.yaml

    rm -rf msp/ ca-cert.pem IssuerPublicKey IssuerRevocationPublicKey fabric-ca-server.db # remove old (default) certs and keys (MSP folder) and get a new one after starting the server
fi

# Start the TLS CA server
nohup ./fabric-ca-server start >> fabric-ca-server-tls.log 2>&1 &
echo $! > fabric-ca-server-tls.pid
echo "✅ TLS CA server started with PID $(cat fabric-ca-server-tls.pid)"
echo "TLS CA server logs are being written to fabric-ca-server-tls.log"