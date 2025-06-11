# MVP Stage 1 Implementation Tasks

## Overview
Complete task breakdown for implementing MVP Stage 1 of the Zakat Platform - a blockchain-based donation management system with auto-validation, admin dashboard, and email notifications.

## Task Summary (17 Tasks Total)

### 🔧 Phase 1.1: Backend Infrastructure & Fabric Integration (5 tasks)

#### Task 1.1.1: Implement PostgreSQL Connection Management
**Complexity:** 7  
**Description:** Create the `platform/backend/pkg/database/` directory. Implement Go functions for connecting to the PostgreSQL database using configuration from `.env`. This should include connection pooling and error handling.

```go
package database

import (
	"fmt"
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"github.com/zakat-platform/internal/config"
)

var DB *gorm.DB

func Connect(cfg config.DatabaseConfig) *gorm.DB {
	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=disable TimeZone=Asia/Shanghai",
		cfg.Host, cfg.User, cfg.Password, cfg.Name, cfg.Port)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	DB = db
	log.Println("Database connection established")
	return DB
}
```

#### Task 1.1.2: Implement Redis Connection Management
**Complexity:** 6  
**Description:** In `platform/backend/pkg/database/`, implement Go functions for connecting to Redis using configuration from `.env`. Handle connection pooling and basic error handling.

```go
package database

import (
	"context"
	"log"

	"github.com/go-redis/redis/v8"
	"github.com/zakat-platform/internal/config"
)

var RDB *redis.Client
var Ctx = context.Background()

func ConnectRedis(cfg config.RedisConfig) *redis.Client {
	RDB = redis.NewClient(&redis.Options{
		Addr:     cfg.Host + ":" + cfg.Port,
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	_, err := RDB.Ping(Ctx).Result()
	if err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	log.Println("Redis connection established")
	return RDB
}
```

#### Task 1.1.3: Implement Hyperledger Fabric SDK Client
**Complexity:** 8  
**Description:** Create the `platform/backend/pkg/fabric/` directory. Implement the Hyperledger Fabric Go SDK client for connecting to the network, managing user identities/wallets, and invoking the `zakat` chaincode.

```go
package fabric

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/hyperledger/fabric-sdk-go/pkg/core/config"
	"github.com/hyperledger/fabric-sdk-go/pkg/gateway"
	"github.com/zakat-platform/internal/config"
)

var GW *gateway.Gateway

func NewClient(cfg config.FabricConfig) *gateway.Gateway {
	err := os.Setenv("DISCOVERY_AS_LOCALHOST", "true")
	if err != nil {
		log.Fatalf("Error setting DISCOVERY_AS_LOCALHOST: %v", err)
	}

	walletPath := cfg.WalletPath
	wallet, err := gateway.NewFileSystemWallet(walletPath)
	if err != nil {
		log.Fatalf("Failed to create wallet: %v", err)
	}

	if !wallet.Exists(cfg.User) {
		log.Fatalf("User '%s' not found in wallet. Please enroll user first.", cfg.User)
	}

	ccpPath := filepath.Join(cfg.ConfigPath, "connection-org1.yaml")
	gw, err := gateway.Connect(
		gateway.WithConfig(config.FromFile(filepath.Clean(ccpPath))),
		gateway.WithIdentity(wallet, cfg.User),
	)
	if err != nil {
		log.Fatalf("Failed to connect to gateway: %v", err)
	}
	GW = gw
	log.Println("Fabric Gateway connection established")
	return GW
}

func GetContract() *gateway.Contract {
	network, err := GW.GetNetwork("zakatchannel")
	if err != nil {
		log.Fatalf("Failed to get network: %v", err)
	}
	contract := network.GetContract("zakat")
	return contract
}
```

#### Task 1.1.4: Enroll Fabric Application User Identity
**Complexity:** 8  
**Description:** Create a Go script to enroll a new application user identity (`appUserOrg1`) with the Org1 CA and store credentials in the wallet.

#### Task 1.1.5: Integrate Database and Fabric Clients into Main Application
**Complexity:** 7  
**Description:** Modify `main.go` to initialize PostgreSQL, Redis, and Fabric SDK clients. Update configuration loading. Add `FABRIC_USER=appUserOrg1` to `.env`.

### 🤖 Phase 1.2: Auto-Validation System & Chaincode (3 tasks)

#### Task 1.2.1: Add AutoValidatePayment Function to Chaincode
**Complexity:** 6  
**Description:** Add `AutoValidatePayment` function to `chaincode/zakat/zakat.go` that checks zakat status and calls existing `ValidatePayment` function.

```go
func (s *SmartContract) AutoValidatePayment(ctx contractapi.TransactionContextInterface, zakatID string, paymentGatewayRef string) error {
	zakat, err := s.QueryZakat(ctx, zakatID)
	if err != nil {
		return fmt.Errorf("failed to query zakat %s: %w", zakatID, err)
	}

	if zakat.Status != "pending" {
		return fmt.Errorf("zakat %s is not in pending status, current status: %s", zakatID, zakat.Status)
	}

	// Auto-validate with system-generated receipt
	receiptNumber := fmt.Sprintf("MOCK-PAYMENT-REF-%d", time.Now().UnixNano())
	if paymentGatewayRef != "" {
		receiptNumber = paymentGatewayRef
	}

	// Call existing ValidatePayment function
	return s.ValidatePayment(ctx, zakatID, receiptNumber, "system-auto")
}
```

#### Task 1.2.2: Increment Chaincode Version and Redeploy
**Complexity:** 7  
**Description:** Update chaincode version to 2.1, repackage, install, approve, and commit using deployment scripts.

#### Task 1.2.3: Implement ValidationService for Auto-Validation Logic
**Complexity:** 7  
**Description:** Create `ValidationService` that schedules auto-validation after configured delay (30s). Add `MOCK_PAYMENT_DELAY=30s` to `.env`.

### 📧 Phase 1.3: Email Notification System (1 task)

#### Task 1.3.1: Enhance EmailService and Define Templates
**Complexity:** 5  
**Description:** Add `SendDonationSubmittedEmail` and `SendDonationValidatedEmail` methods to existing EmailService.

### 👤 Phase 1.4: Admin Authentication & Dashboard (3 tasks)

#### Task 1.4.1: Adapt UserService to use GORM
**Complexity:** 6  
**Description:** Convert UserService from `*sql.DB` to `*gorm.DB` for consistency with database package.

#### Task 1.4.2: Create Initial Admin User Seeding Script
**Complexity:** 5  
**Description:** Create script to seed initial admin user for testing.

#### Task 1.4.3: Refine Admin Dashboard Endpoints
**Complexity:** 7  
**Description:** Update dashboard to show real data (pending donations count, recent activity).

### 💰 Phase 1.5: Donation Service Integration (2 tasks)

#### Task 1.5.1: Adapt DonationService to use GORM and New Fabric Client
**Complexity:** 8  
**Description:** Update DonationService to use GORM and new Fabric contract client.

#### Task 1.5.2: Integrate Validation and Email Services into CreateDonation
**Complexity:** 5  
**Description:** Add email notifications and auto-validation scheduling to donation creation flow.

### 🌐 Phase 1.6: Frontend Verification (1 task)

#### Task 1.6.1: Verify Frontend Integration and API Connectivity
**Complexity:** 4  
**Description:** Test frontend components integration with backend API. **Status: ✅ Frontend is already excellent and MVP-ready.**

### 🚀 Phase 1.7: Deployment & Testing (2 tasks)

#### Task 1.7.1: Deploy Platform Services Using Docker Compose
**Complexity:** 6  
**Description:** Use `docker-compose.platform.yml` to deploy all services and ensure connectivity.

#### Task 1.7.2: End-to-End Testing and Validation
**Complexity:** 8  
**Description:** Comprehensive testing of complete donation flow, admin features, and blockchain integration.

## Frontend Status: ✅ EXCELLENT
The frontend is already MVP-ready with:
- Complete Islamic theming (green/gold colors)
- Functional donation form with validation
- Donation tracking system
- Responsive design
- Proper API integration

## Key MVP Features
- Guest donation submission with auto-validation
- Admin authentication and dashboard
- Email notifications (submission + validation confirmations)
- Blockchain transaction recording
- Real-time donation tracking
- Mock payment system (30-second delay)

## Implementation Priority
1. Backend Infrastructure (Tasks 1.1.1-1.1.5)
2. Chaincode Enhancement (Tasks 1.2.1-1.2.3)
3. Services Integration (Tasks 1.3.1, 1.4.1-1.4.3, 1.5.1-1.5.2)
4. Deployment & Testing (Tasks 1.7.1-1.7.2)

## Environment Variables to Add
```bash
# Fabric Configuration
FABRIC_USER=appUserOrg1

# Mock Payment System
MOCK_PAYMENT_DELAY=30s
