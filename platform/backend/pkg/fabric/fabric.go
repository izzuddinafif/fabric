package fabric

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/hyperledger/fabric-sdk-go/pkg/core/config"
	"github.com/hyperledger/fabric-sdk-go/pkg/gateway"
)

// FabricConfig holds Fabric network connection configuration
type FabricConfig struct {
	ConfigPath string // Path to connection profile directory
	WalletPath string // Path to wallet directory
	Channel    string // Channel name (e.g., "zakatchannel")
	Chaincode  string // Chaincode name (e.g., "zakat")
	User       string // User identity name (e.g., "appUserOrg1")
}

var GW *gateway.Gateway

// NewClient creates a new Fabric Gateway client connection
func NewClient(cfg FabricConfig) *gateway.Gateway {
	// Set environment variable for local development
	err := os.Setenv("DISCOVERY_AS_LOCALHOST", "true")
	if err != nil {
		log.Printf("Warning: Failed to set DISCOVERY_AS_LOCALHOST: %v", err)
	}

	// Create file system wallet
	walletPath := cfg.WalletPath
	wallet, err := gateway.NewFileSystemWallet(walletPath)
	if err != nil {
		log.Fatalf("Failed to create wallet from path '%s': %v", walletPath, err)
	}

	// Check if user identity exists in wallet
	if !wallet.Exists(cfg.User) {
		log.Fatalf("User '%s' not found in wallet at '%s'. Please enroll user first.", cfg.User, walletPath)
	}

	// Construct connection profile path
	ccpPath := filepath.Join(cfg.ConfigPath, "connection-org1.yaml")
	if _, err := os.Stat(ccpPath); os.IsNotExist(err) {
		log.Fatalf("Connection profile not found at '%s'", ccpPath)
	}

	log.Printf("Connecting to Fabric network using profile: %s", ccpPath)
	log.Printf("Using wallet path: %s", walletPath)
	log.Printf("Using user identity: %s", cfg.User)

	// Connect to gateway
	gw, err := gateway.Connect(
		gateway.WithConfig(config.FromFile(filepath.Clean(ccpPath))),
		gateway.WithIdentity(wallet, cfg.User),
	)
	if err != nil {
		log.Fatalf("Failed to connect to Fabric gateway: %v", err)
	}

	// Set global gateway
	GW = gw
	log.Println("Fabric Gateway connection established successfully")
	return GW
}

// GetContract returns the chaincode contract for the configured channel and chaincode
func GetContract(cfg FabricConfig) *gateway.Contract {
	if GW == nil {
		log.Fatal("Fabric gateway not initialized. Call NewClient first.")
	}

	// Get network
	network, err := GW.GetNetwork(cfg.Channel)
	if err != nil {
		log.Fatalf("Failed to get network '%s': %v", cfg.Channel, err)
	}

	// Get contract
	contract := network.GetContract(cfg.Chaincode)
	log.Printf("Retrieved contract '%s' from channel '%s'", cfg.Chaincode, cfg.Channel)
	return contract
}

// Close closes the Fabric gateway connection
func Close() {
	if GW != nil {
		GW.Close()
		log.Println("Fabric Gateway connection closed")
	}
}

// GetGateway returns the global gateway instance
func GetGateway() *gateway.Gateway {
	return GW
}

// SubmitTransaction submits a transaction to the chaincode
func SubmitTransaction(contract *gateway.Contract, function string, args ...string) ([]byte, error) {
	if contract == nil {
		return nil, fmt.Errorf("contract is nil")
	}

	log.Printf("Submitting transaction: %s with args: %v", function, args)

	result, err := contract.SubmitTransaction(function, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to submit transaction '%s': %w", function, err)
	}

	log.Printf("Transaction '%s' submitted successfully", function)
	return result, nil
}

// EvaluateTransaction evaluates a transaction (query) on the chaincode
func EvaluateTransaction(contract *gateway.Contract, function string, args ...string) ([]byte, error) {
	if contract == nil {
		return nil, fmt.Errorf("contract is nil")
	}

	log.Printf("Evaluating transaction: %s with args: %v", function, args)

	result, err := contract.EvaluateTransaction(function, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to evaluate transaction '%s': %w", function, err)
	}

	log.Printf("Transaction '%s' evaluated successfully", function)
	return result, nil
}
