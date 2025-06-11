package main

import (
	"flag"
	"fmt"
	"os/exec"
	"sync"
	"time"
)

// Test configuration - Optimized for maximum performance and uniqueness
const (
	CONCURRENT_TRANSACTIONS = 75 // Per VPS - Increased for higher TPS targeting
	VALIDATION_BURST_SIZE   = 40 // Number of validations to test
	MAX_GOROUTINES         = 30 // Higher concurrency for maximum throughput
)

// Transaction result
type TransactionResult struct {
	ID       string
	Duration time.Duration
	Success  bool
	Error    string
	VPS      string
}

// VPS configuration
type VPSConfig struct {
	Name         string
	CLI          string
	OrgCode      string
	Organization string
}

// Execute chaincode locally (no SSH)
func executeLocalChaincode(config VPSConfig, function, args string, isQuery bool) (string, error) {
	var cmdStr string
	if isQuery {
		cmdStr = fmt.Sprintf(`docker exec %s peer chaincode query -C zakatchannel -n zakat -c '{"function":"%s","Args":[%s]}'`, 
			config.CLI, function, args)
	} else {
		cmdStr = fmt.Sprintf(`docker exec %s peer chaincode invoke -o orderer.fabriczakat.local:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org1.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org2.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem -C zakatchannel -n zakat -c '{"function":"%s","Args":[%s]}' --waitForEvent`, 
			config.CLI, function, args)
	}
	
	cmd := exec.Command("bash", "-c", cmdStr)
	output, err := cmd.CombinedOutput()
	return string(output), err
}

// Generate unique zakat ID with enhanced nanosecond timestamp format
func generateZakatID(config VPSConfig, index int) string {
	now := time.Now()
	nanoTimestamp := now.UnixNano()
	
	// Use new enhanced format: ZKT-YDSF-{MLG|JTM}-{NANOTIMESTAMP}-{SEQUENCE}
	// This ensures true uniqueness across all VPS and goroutines
	return fmt.Sprintf("ZKT-YDSF-%s-%d-%04d", config.OrgCode, nanoTimestamp, index)
}

// Create zakat transaction locally using proper v2.0 parameters
func createZakatTransactionLocal(config VPSConfig, index int) TransactionResult {
	start := time.Now()
	
	zakatID := generateZakatID(config, index)
	muzakki := fmt.Sprintf("DistributedStress-%s-User-%d", config.Name, index)
	amount := "750000"
	
	// Skip program and officer updates to avoid MVCC conflicts during stress testing
	// Empty strings will bypass the update logic in the chaincode
	programID := ""     // No program updates
	referralCode := ""  // No officer updates
	
	// Proper AddZakat v2.0 parameters: id, programID, muzakki, amount, zakatType, paymentMethod, organization, referralCode
	args := fmt.Sprintf(`"%s","%s","%s","%s","maal","transfer","%s","%s"`, 
		zakatID, programID, muzakki, amount, config.Organization, referralCode)
	
	output, err := executeLocalChaincode(config, "AddZakat", args, false)
	duration := time.Since(start)
	
	result := TransactionResult{
		ID:       zakatID,
		Duration: duration,
		Success:  err == nil && contains(output, "Chaincode invoke successful"),
		VPS:      config.Name,
	}
	
	if !result.Success {
		result.Error = fmt.Sprintf("Error: %v, Output: %s", err, output)
	}
	
	return result
}

// Query zakat locally
func queryZakatLocal(config VPSConfig, zakatID string) TransactionResult {
	start := time.Now()
	
	args := fmt.Sprintf(`"%s"`, zakatID)
	output, err := executeLocalChaincode(config, "QueryZakat", args, true)
	duration := time.Since(start)
	
	result := TransactionResult{
		ID:       zakatID,
		Duration: duration,
		Success:  err == nil && isValidJSON(output),
		VPS:      config.Name,
	}
	
	if !result.Success {
		result.Error = fmt.Sprintf("Error: %v, Output: %s", err, output)
	}
	
	return result
}

// Validate payment locally (v2.0 workflow: pending → collected)
func validatePaymentLocal(config VPSConfig, zakatID string) TransactionResult {
	start := time.Now()
	
	receiptNumber := fmt.Sprintf("RCP-STRESS-%s-%d", config.Name, time.Now().Unix())
	validatedBy := fmt.Sprintf("StressAdmin-%s", config.Name)
	
	// ValidatePayment parameters: zakatID, receiptNumber, validatedBy
	args := fmt.Sprintf(`"%s","%s","%s"`, zakatID, receiptNumber, validatedBy)
	
	output, err := executeLocalChaincode(config, "ValidatePayment", args, false)
	duration := time.Since(start)
	
	result := TransactionResult{
		ID:       zakatID,
		Duration: duration,
		Success:  err == nil && contains(output, "Chaincode invoke successful"),
		VPS:      config.Name,
	}
	
	if !result.Success {
		result.Error = fmt.Sprintf("Error: %v, Output: %s", err, output)
	}
	
	return result
}

// Distribute zakat locally (v2.0 workflow: collected → distributed)
func distributeZakatLocal(config VPSConfig, zakatID string) TransactionResult {
	start := time.Now()
	
	distributionID := fmt.Sprintf("DIST-%s-%d", config.Name, time.Now().Unix())
	recipientName := fmt.Sprintf("Mustahik-%s-%d", config.Name, time.Now().Unix()%1000)
	amount := "250000" // Partial distribution
	distributionTimestamp := time.Now().Format(time.RFC3339)
	distributedBy := fmt.Sprintf("DistributionAdmin-%s", config.Name)
	
	// DistributeZakat parameters: zakatID, distributionID, recipientName, amount, distributionTimestamp, distributedBy
	args := fmt.Sprintf(`"%s","%s","%s","%s","%s","%s"`, 
		zakatID, distributionID, recipientName, amount, distributionTimestamp, distributedBy)
	
	output, err := executeLocalChaincode(config, "DistributeZakat", args, false)
	duration := time.Since(start)
	
	result := TransactionResult{
		ID:       zakatID,
		Duration: duration,
		Success:  err == nil && contains(output, "Chaincode invoke successful"),
		VPS:      config.Name,
	}
	
	if !result.Success {
		result.Error = fmt.Sprintf("Error: %v, Output: %s", err, output)
	}
	
	return result
}

// Test status filtering (v2.0 advanced querying)
func testStatusQueryLocal(config VPSConfig, status string) TransactionResult {
	start := time.Now()
	
	args := fmt.Sprintf(`"%s"`, status)
	output, err := executeLocalChaincode(config, "GetZakatByStatus", args, true)
	duration := time.Since(start)
	
	result := TransactionResult{
		ID:       fmt.Sprintf("STATUS-%s", status),
		Duration: duration,
		Success:  err == nil && isValidJSON(output),
		VPS:      config.Name,
	}
	
	if !result.Success {
		result.Error = fmt.Sprintf("Error: %v, Output: %s", err, output)
	}
	
	return result
}

// Clear existing data before test
func clearExistingData(config VPSConfig) error {
	fmt.Printf("🧹 [%s] Clearing existing Zakat data for clean test...\n", config.Name)
	
	output, err := executeLocalChaincode(config, "ClearAllZakat", "", false)
	if err != nil {
		return fmt.Errorf("failed to clear existing data: %v, output: %s", err, output)
	}
	
	if contains(output, "Chaincode invoke successful") {
		fmt.Printf("✅ [%s] Successfully cleared existing data\n", config.Name)
		return nil
	}
	
	return fmt.Errorf("unexpected output from ClearAllZakat: %s", output)
}

// Test concurrent transactions on this VPS
func testConcurrentTransactionsLocal(config VPSConfig) {
	fmt.Printf("🚀 [%s] Starting Distributed Stress Test (%d transactions)\n", config.Name, CONCURRENT_TRANSACTIONS)
	fmt.Printf("🏃 [%s] Using %d goroutines for maximum parallelism\n", config.Name, MAX_GOROUTINES)
	
	// Clear existing data first to prevent duplicate conflicts
	if err := clearExistingData(config); err != nil {
		fmt.Printf("❌ [%s] Failed to clear existing data: %v\n", config.Name, err)
		fmt.Printf("⚠️  [%s] Continuing with test - may encounter duplicate errors\n", config.Name)
	}
	
	start := time.Now()
	
	// Channel to receive results
	results := make(chan TransactionResult, CONCURRENT_TRANSACTIONS)
	
	// Semaphore to limit concurrent goroutines
	sem := make(chan struct{}, MAX_GOROUTINES)
	var wg sync.WaitGroup
	
	// Launch goroutines for transaction creation
	for i := 0; i < CONCURRENT_TRANSACTIONS; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			sem <- struct{}{}        // Acquire semaphore
			defer func() { <-sem }() // Release semaphore
			
			result := createZakatTransactionLocal(config, index)
			results <- result
		}(i)
	}
	
	// Wait for all goroutines to complete
	go func() {
		wg.Wait()
		close(results)
	}()
	
	// Collect results
	var allResults []TransactionResult
	successCount := 0
	var totalDuration time.Duration
	
	for result := range results {
		allResults = append(allResults, result)
		if result.Success {
			successCount++
		}
		totalDuration += result.Duration
	}
	
	testDuration := time.Since(start)
	avgDuration := totalDuration / time.Duration(len(allResults))
	tps := float64(successCount) / testDuration.Seconds()
	
	// Print results
	fmt.Printf("\n📊 [%s] Transaction Results:\n", config.Name)
	fmt.Printf("  Total Duration: %.2fs\n", testDuration.Seconds())
	fmt.Printf("  Successful: %d\n", successCount)
	fmt.Printf("  Failed: %d\n", len(allResults)-successCount)
	fmt.Printf("  Average Response Time: %.3fs\n", avgDuration.Seconds())
	fmt.Printf("  🎯 LOCAL TPS: %.2f transactions/second\n", tps)
	
	successRate := float64(successCount) / float64(len(allResults)) * 100
	if successRate >= 60 {
		fmt.Printf("✅ [%s] Transaction test PASSED (%.1f%% success rate)\n", config.Name, successRate)
	} else {
		fmt.Printf("❌ [%s] Transaction test FAILED (%.1f%% success rate)\n", config.Name, successRate)
	}
	
	// Test complete v2.0 workflow with successful transactions
	if successCount > 0 {
		fmt.Printf("\n🔄 [%s] Testing Complete v2.0 Workflow (pending → collected → distributed)...\n", config.Name)
		
		// Collect successful transaction IDs
		var successfulTxIDs []string
		for _, result := range allResults {
			if result.Success {
				successfulTxIDs = append(successfulTxIDs, result.ID)
			}
		}
		
		// Test 1: Payment Validation (pending → collected)
		fmt.Printf("📝 [%s] Testing Payment Validation (%d validations)...\n", config.Name, len(successfulTxIDs))
		validationStart := time.Now()
		validationResults := make(chan TransactionResult, len(successfulTxIDs))
		var validationWg sync.WaitGroup
		
		validationCount := 0
		for _, txID := range successfulTxIDs {
			if validationCount >= VALIDATION_BURST_SIZE {
				break
			}
			validationWg.Add(1)
			go func(id string) {
				defer validationWg.Done()
				sem <- struct{}{}
				defer func() { <-sem }()
				
				validationResult := validatePaymentLocal(config, id)
				validationResults <- validationResult
			}(txID)
			validationCount++
		}
		
		go func() {
			validationWg.Wait()
			close(validationResults)
		}()
		
		// Collect validation results
		validationSuccessCount := 0
		var validatedTxIDs []string
		var validationTotalDuration time.Duration
		
		for vResult := range validationResults {
			if vResult.Success {
				validationSuccessCount++
				validatedTxIDs = append(validatedTxIDs, vResult.ID)
			}
			validationTotalDuration += vResult.Duration
		}
		
		validationTestDuration := time.Since(validationStart)
		validationTPS := float64(validationSuccessCount) / validationTestDuration.Seconds()
		
		fmt.Printf("📊 [%s] Validation Results:\n", config.Name)
		fmt.Printf("  Validation Duration: %.2fs\n", validationTestDuration.Seconds())
		fmt.Printf("  Successful Validations: %d/%d\n", validationSuccessCount, validationCount)
		fmt.Printf("  🎯 Validation TPS: %.2f validations/second\n", validationTPS)
		
		// Test 2: Distribution (collected → distributed)
		distributionSuccessCount := 0
		distributionTPS := 0.0
		if len(validatedTxIDs) > 0 {
			fmt.Printf("📦 [%s] Testing Distribution (%d distributions)...\n", config.Name, len(validatedTxIDs))
			distributionStart := time.Now()
			distributionResults := make(chan TransactionResult, len(validatedTxIDs))
			var distributionWg sync.WaitGroup
			
			for _, txID := range validatedTxIDs {
				distributionWg.Add(1)
				go func(id string) {
					defer distributionWg.Done()
					sem <- struct{}{}
					defer func() { <-sem }()
					
					distributionResult := distributeZakatLocal(config, id)
					distributionResults <- distributionResult
				}(txID)
			}
			
			go func() {
				distributionWg.Wait()
				close(distributionResults)
			}()
			
			// Collect distribution results
			for dResult := range distributionResults {
				if dResult.Success {
					distributionSuccessCount++
				}
			}
			
			distributionTestDuration := time.Since(distributionStart)
			distributionTPS = float64(distributionSuccessCount) / distributionTestDuration.Seconds()
			
			fmt.Printf("📊 [%s] Distribution Results:\n", config.Name)
			fmt.Printf("  Distribution Duration: %.2fs\n", distributionTestDuration.Seconds())
			fmt.Printf("  Successful Distributions: %d/%d\n", distributionSuccessCount, len(validatedTxIDs))
			fmt.Printf("  🎯 Distribution TPS: %.2f distributions/second\n", distributionTPS)
		}
		
		// Test 3: Advanced Querying (v2.0 features)
		fmt.Printf("🔍 [%s] Testing Advanced v2.0 Queries...\n", config.Name)
		queryStart := time.Now()
		
		// Test status queries
		pendingQuery := testStatusQueryLocal(config, "pending")
		collectedQuery := testStatusQueryLocal(config, "collected")
		distributedQuery := testStatusQueryLocal(config, "distributed")
		
		queryTestDuration := time.Since(queryStart)
		advancedQuerySuccessCount := 0
		if pendingQuery.Success {
			advancedQuerySuccessCount++
		}
		if collectedQuery.Success {
			advancedQuerySuccessCount++
		}
		if distributedQuery.Success {
			advancedQuerySuccessCount++
		}
		
		queryTPS := float64(advancedQuerySuccessCount) / queryTestDuration.Seconds()
		
		fmt.Printf("📊 [%s] Advanced Query Results:\n", config.Name)
		fmt.Printf("  Query Duration: %.2fs\n", queryTestDuration.Seconds())
		fmt.Printf("  Successful Queries: %d/3\n", advancedQuerySuccessCount)
		fmt.Printf("  🎯 Query TPS: %.2f queries/second\n", queryTPS)
		
		// Overall workflow success rate
		workflowSuccessRate := float64(distributionSuccessCount) / float64(successCount) * 100
		if workflowSuccessRate >= 50 {
			fmt.Printf("✅ [%s] Complete v2.0 workflow test PASSED (%.1f%% end-to-end success)\n", config.Name, workflowSuccessRate)
		} else {
			fmt.Printf("❌ [%s] Complete v2.0 workflow test FAILED (%.1f%% end-to-end success)\n", config.Name, workflowSuccessRate)
		}
		
		// Enhanced summary for aggregation
		fmt.Printf("\n🎯 [%s] ENHANCED v2.0 SUMMARY FOR AGGREGATION:\n", config.Name)
		fmt.Printf("TRANSACTIONS_SUCCESS:%d\n", successCount)
		fmt.Printf("TRANSACTIONS_TOTAL:%d\n", len(allResults))
		fmt.Printf("TRANSACTIONS_TPS:%.2f\n", tps)
		fmt.Printf("VALIDATIONS_SUCCESS:%d\n", validationSuccessCount)
		fmt.Printf("VALIDATIONS_TOTAL:%d\n", validationCount)
		fmt.Printf("VALIDATIONS_TPS:%.2f\n", validationTPS)
		fmt.Printf("DISTRIBUTIONS_SUCCESS:%d\n", distributionSuccessCount)
		fmt.Printf("DISTRIBUTIONS_TOTAL:%d\n", len(validatedTxIDs))
		fmt.Printf("DISTRIBUTIONS_TPS:%.2f\n", distributionTPS)
		fmt.Printf("QUERIES_SUCCESS:%d\n", advancedQuerySuccessCount)
		fmt.Printf("QUERIES_TOTAL:3\n")
		fmt.Printf("QUERIES_TPS:%.2f\n", queryTPS)
		fmt.Printf("WORKFLOW_SUCCESS_RATE:%.2f\n", workflowSuccessRate)
		fmt.Printf("TOTAL_DURATION:%.2f\n", testDuration.Seconds())
	}
}

// Helper functions
func contains(s, substr string) bool {
	return len(s) >= len(substr) && 
		func() bool {
			for i := 0; i <= len(s)-len(substr); i++ {
				if s[i:i+len(substr)] == substr {
					return true
				}
			}
			return false
		}()
}

func isValidJSON(s string) bool {
	return len(s) > 0 && s[0] == '{' && s[len(s)-1] == '}'
}

func main() {
	// Parse command line flags
	vpsName := flag.String("vps", "", "VPS name (org1 or org2)")
	flag.Parse()
	
	if *vpsName == "" {
		fmt.Println("Usage: ./distributed-stress-test -vps=org1|org2")
		return
	}
	
	var config VPSConfig
	switch *vpsName {
	case "org1":
		config = VPSConfig{
			Name:         "Org1-VPS",
			CLI:          "cli.org1.fabriczakat.local",
			OrgCode:      "MLG",
			Organization: "YDSF Malang",
		}
	case "org2":
		config = VPSConfig{
			Name:         "Org2-VPS", 
			CLI:          "cli.org2.fabriczakat.local",
			OrgCode:      "JTM",
			Organization: "YDSF Jatim",
		}
	default:
		fmt.Printf("Unknown VPS: %s\n", *vpsName)
		return
	}
	
	fmt.Printf("🌟 Distributed Hyperledger Fabric Stress Test\n")
	fmt.Printf("🏢 VPS: %s\n", config.Name)
	fmt.Printf("🎯 Target: True distributed testing without SSH overhead\n\n")
	
	testConcurrentTransactionsLocal(config)
	
	fmt.Printf("\n🎉 [%s] Distributed stress test completed!\n", config.Name)
	fmt.Printf("💡 Combine results from all VPS instances for total TPS\n")
}