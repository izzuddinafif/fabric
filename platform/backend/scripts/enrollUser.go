package main

import (
	"io/ioutil"
	"log"

	"github.com/hyperledger/fabric-sdk-go/pkg/gateway"
)

const (
	// Organization details
	orgName = "Org1MSP"

	// User credentials - Using existing Admin MSP
	userName = "Admin"

	// Paths
	walletPath = "../wallet" // platform/wallet/
	
	// MSP paths for existing Admin identity
	certPath = "/home/fabricadmin/fabric/organizations/peerOrganizations/org1.fabriczakat.local/users/Admin@org1.fabriczakat.local/msp/signcerts/cert.pem"
	keyPath  = "/home/fabricadmin/fabric/organizations/peerOrganizations/org1.fabriczakat.local/users/Admin@org1.fabriczakat.local/msp/keystore/key.pem"
)

func main() {
	log.Println("Starting wallet creation process...")
	log.Printf("Creating wallet for user: %s", userName)
	log.Printf("Organization: %s", orgName)

	// Create wallet
	log.Printf("Creating wallet at: %s", walletPath)
	wallet, err := gateway.NewFileSystemWallet(walletPath)
	if err != nil {
		log.Fatalf("Failed to create wallet: %v", err)
	}

	// Check if user already exists
	if wallet.Exists(userName) {
		log.Printf("User '%s' already exists in the wallet. Skipping creation.", userName)
		return
	}

	// Read certificate
	log.Printf("Reading certificate from: %s", certPath)
	cert, err := ioutil.ReadFile(certPath)
	if err != nil {
		log.Fatalf("Failed to read certificate: %v", err)
	}

	// Read private key
	log.Printf("Reading private key from: %s", keyPath)
	key, err := ioutil.ReadFile(keyPath)
	if err != nil {
		log.Fatalf("Failed to read private key: %v", err)
	}

	// Create identity object
	log.Println("Creating X509 identity...")
	identity := gateway.NewX509Identity(orgName, string(cert), string(key))

	// Save identity to wallet
	log.Printf("Saving identity to wallet...")
	err = wallet.Put(userName, identity)
	if err != nil {
		log.Fatalf("Failed to put identity in wallet: %v", err)
	}

	log.Printf("✅ Successfully created wallet identity '%s' at '%s'", userName, walletPath)
	log.Println("Identity is now ready to be used by the application.")

	// Verify the creation by checking wallet
	if wallet.Exists(userName) {
		log.Printf("✅ Verification: User '%s' found in wallet", userName)
	} else {
		log.Printf("❌ Verification failed: User '%s' not found in wallet", userName)
	}
}
