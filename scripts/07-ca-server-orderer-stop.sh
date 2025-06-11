#!/bin/bash
cd $HOME/fabric/fabric-ca-server-orderer

# Stop the TLS CA server
if [ -f fabric-ca-server-orderer.pid ]; then
    PID=$(cat fabric-ca-server-orderer.pid)
    if ps -p $PID > /dev/null; then
        echo "🛑 Stopping Orderer CA server with PID $PID..."
        sudo kill $PID
        # Wait a moment for the process to terminate
        sleep 1
        if ps -p $PID > /dev/null; then
            echo "⚠️ Orderer CA server (PID $PID) did not stop gracefully, sending SIGKILL..."
            sudo kill -9 $PID
        fi
        rm fabric-ca-server-orderer.pid
        echo "✅ Orderer CA server stopped."
    else
        echo "⚠️ PID file found, but no process with PID $PID is running. Removing stale PID file."
        rm fabric-ca-server-orderer.pid
    fi
else
    echo "✅ Orderer CA server is not running (no PID file found)."
fi

# cd ..; rm -rf fabric-ca-server-orderer/; rm fabric-ca-server-orderer.log