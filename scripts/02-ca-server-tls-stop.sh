#!/bin/bash
cd $HOME/fabric/fabric-ca-server-tls

# Stop the TLS CA server
if [ -f fabric-ca-server-tls.pid ]; then
    PID=$(cat fabric-ca-server-tls.pid)
    if ps -p $PID > /dev/null; then
        echo "Stopping TLS CA server with PID $PID..."
        sudo kill $PID
        rm fabric-ca-server-tls.pid
        echo "✅ TLS CA server stopped."
    fi
fi

cd ..; rm -rf fabric-ca-server-tls/;