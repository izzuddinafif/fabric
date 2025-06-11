#!/bin/bash

# Check if TLS CA server is running
if ! nc -z tls.fabriczakat.local 7054; then
    echo "⛔ TLS CA server is not running. Exiting."
    exit 1
fi

echo "⏳ Waiting for TLS CA server to be ready..."
echo "✅ Port 7054 on tls.fabriczakat.local is open."

# Check if fabric-ca-server-tls directory exists
if ! [ -d "$HOME/fabric/fabric-ca-server-tls" ]; then
    echo "⛔ Directory $HOME/fabric/fabric-ca-server-tls does not exist. Exiting."
    exit 1
fi

# Create the fabric-ca-client directory if it doesn't exist
if [ ! -d "$HOME/fabric/fabric-ca-client" ]; then
    echo "📁 Creating fabric-ca-client directory..."
    mkdir -p $HOME/fabric/fabric-ca-client
fi

# Check if TLS enrollment has already been done
if [ -d "$HOME/fabric/fabric-ca-client/tls-ca/tlsadmin/msp" ]; then
    echo "✅ TLS admin already enrolled. Skipping enrollment."
    exit 0
fi

# Create the necessary directories
echo "📁 Setting up directories for TLS admin enrollment..."
mkdir -p $HOME/fabric/fabric-ca-client/tls-ca
mkdir -p $HOME/fabric/fabric-ca-client/tls-root-cert

# Copy the necessary files
echo "📄 Copying CA certificate and client binary..."
cp $HOME/fabric/fabric-ca-server-tls/ca-cert.pem $HOME/fabric/fabric-ca-client/tls-root-cert/tls-ca-cert.pem

# Copy fabric-ca-client binary if needed
if [ ! -f "$HOME/fabric/fabric-ca-client/fabric-ca-client" ]; then
    if [ -f "$HOME/bin/fabric-ca-client" ]; then
        cp $HOME/bin/fabric-ca-client $HOME/fabric/fabric-ca-client/
    elif [ -f "$HOME/fabric/bin/fabric-ca-client" ]; then
        cp $HOME/fabric/bin/fabric-ca-client $HOME/fabric/fabric-ca-client/
    else
        echo "⛔ fabric-ca-client binary not found. Please ensure it's installed."
        exit 1
    fi
fi

# Set up environment and perform enrollment
cd $HOME/fabric/fabric-ca-client/
export FABRIC_CA_CLIENT_HOME=$PWD

echo "🔐 Enrolling TLS admin..."
./fabric-ca-client enroll -d -u https://tls-admin:tls-adminpw@tls.fabriczakat.local:7054 --tls.certfiles tls-root-cert/tls-ca-cert.pem --mspdir tls-ca/tlsadmin/msp --enrollment.profile tls

if [ $? -eq 0 ]; then
    echo "✅ TLS admin enrolled successfully."

    # Verify the MSP directory was created
    if [ -d "$FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp" ]; then
        echo "✅ TLS admin MSP directory created successfully."
    else
        echo "⛔ TLS admin MSP directory was not created. Enrollment may have failed."
        exit 1
    fi
else
    echo "⛔ Failed to enroll TLS admin. Exit code: $?"
    exit 1
fi
