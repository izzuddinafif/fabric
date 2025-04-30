#!/bin/bash
cd $HOME/fabric/fabric-ca-server-orderer
export FABRIC_CA_CLIENT_HOME=$HOME/fabric/fabric-ca-client

# Check if the fabric-ca-server is already running
if [ -f fabric-ca-server-orderer.pid ]; then
    PID=$(cat fabric-ca-server-orderer.pid)
    if ps -p $PID > /dev/null; then
        echo "Orderer CA server is already running with PID $PID. Exiting."
        exit 1
    fi
fi

# check if the port 7055 and 9444 are already in use and kill the process if it is
if lsof -i :7055 > /dev/null; then
    echo "Port 7055 is already in use. Killing process."
    sudo kill $(lsof -t -i:7055)
fi
if lsof -i :9444 > /dev/null; then
    echo "Port 9444 is already in use. Killing process."
    sudo kill $(lsof -t -i:9444)
fi

# Edit the fabric-ca-server-config.yaml file
if ! command -v yq &> /dev/null
then
    echo "yq could not be found, installing..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi

if [[ $(yq eval '.tls.enabled' fabric-ca-server-config.yaml) == "false" ]]; then

    yq eval '.port = 7055' -i fabric-ca-server-config.yaml
    yq eval '.tls.enabled = true'                -i fabric-ca-server-config.yaml
    yq eval '.tls.certfile = "tls/cert.pem"'     -i fabric-ca-server-config.yaml
    yq eval '.tls.keyfile = "tls/key.pem"'      -i fabric-ca-server-config.yaml
    yq eval '.ca.name = "orderer-ca"'            -i fabric-ca-server-config.yaml
    yq eval '.operations.listenAddress = "0.0.0.0:9444"' \
                                                -i fabric-ca-server-config.yaml
    yq eval '.csr.hosts = ["localhost", "ca.orderer.fabriczakat.local"]' -i fabric-ca-server-config.yaml
    yq eval '.csr.cn = "orderer-ca"' -i fabric-ca-server-config.yaml
        
    yq eval '.csr.names[0].C = "ID" | .csr.names[0].ST = "East Java" | .csr.names[0].L = "Surabaya" | .csr.names[0].O = "YDSF" | .csr.names[0].OU = "Orderer"' -i fabric-ca-server-config.yaml
    rm -rf msp/ ca-cert.pem # remove old (default) CA certs or enrolment CA (NOT TLS Cert) and keys (MSP folder) and get a new one after starting the server
fi

# start the orderer CA server
nohup ./fabric-ca-server start >> fabric-ca-server-orderer.log 2>&1 &
echo $! > fabric-ca-server-orderer.pid
echo "Orderer CA server started with PID $(cat fabric-ca-server-orderer.pid)"
echo "Orderer CA server logs are being written to fabric-ca-server-orderer.log"
