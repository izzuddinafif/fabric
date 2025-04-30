#!/bin/bash
cd $HOME/fabric-ca-server-orderer

# Stop the TLS CA server
if [ -f fabric-ca-server-orderer.pid ]; then
    PID=$(cat fabric-ca-server-orderer.pid)
    if ps -p $PID > /dev/null; then
        echo "Stopping TLS CA server with PID $PID..."
        sudo kill $PID
        rm fabric-ca-server-orderer.pid
        echo "TLS CA server stopped."
    fi
fi

# cd ..; rm -rf fabric-ca-server-orderer/; rm fabric-ca-server-orderer.log