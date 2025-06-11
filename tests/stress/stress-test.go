package main

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"os/exec"
	"sync"
	"time"
)

// Test configuration
const (
	CONCURRENT_TRANSACTIONS = 5  // Start small for debugging
	VALIDATION_BURST_SIZE   = 3
	QUERY_LOAD_SIZE        = 5
	MAX_GOROUTINES         = 3
)

// Organizations
var orgs = []string{"org1", "org2"}
var orgIPs = map[string]string{
	"org1": "10.104.0.2",
	"org2": "10.104.0.4",
}
var cliContainers = map[string]string{
	"org1": "cli.org1.fabriczakat.local",
	"org2": "cli.org2.fabriczakat.local",
}

// Transaction result
type TransactionResult struct {
	ID          string
	Duration    time.Duration
	Success     bool
	Error       string
	Operation   string
	Timestamp   time.Time
}

// Test results
type TestResults struct {
	TotalTransactions int
	SuccessCount     int
	FailureCount     int
	AverageDuration  time.Duration
	TotalDuration    time.Duration
	TPS              float64
	Results          []TransactionResult
}

// Execute chaincode command
func executeChaincode(org, function, args string, isQuery bool) (string, error) {
	orgIP := orgIPs[org]
	cli := cliContainers[org]
	
	var cmdStr string
	if isQuery {
		cmdStr = fmt.Sprintf(`ssh fabricadmin@%s "docker exec %s peer chaincode query -C zakatchannel -n zakat -c '{\"function\":\"%s\",\"Args\":[%s]}'"`, 
			orgIP, cli, function, args)
	} else {
		cmdStr = fmt.Sprintf(`ssh fabricadmin@%s "docker exec %s peer chaincode invoke -o orderer.fabriczakat.local:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org1.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org2.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem -C zakatchannel -n zakat -c '{\"function\":\"%s\",\"Args\":[%s]}' --waitForEvent"`, 
			orgIP, cli, function, args)
	}
	
	// Debug: print the command being executed
	fmt.Printf("DEBUG: Executing command: %s\n", cmdStr)
	
	cmd := exec.Command("bash", "-c", cmdStr)
	output, err := cmd.CombinedOutput()
	
	// Debug: print output and error
	if err != nil {
		fmt.Printf("DEBUG: Command failed with error: %v\n", err)
		fmt.Printf("DEBUG: Command output: %s\n", string(output))
	}
	
	return string(output), err
}

// Generate random zakat ID
func generateZakatID(org string) string {
	timestamp := time.Now().Unix()
	randomNum, _ := rand.Int(rand.Reader, big.NewInt(9999))
	
	orgCode := "MLG"
	if org == "org2" {
		orgCode = "JTM"
	}
	
	return fmt.Sprintf("ZKT-YDSF-%s-%s-%04d", orgCode, time.Now().Format("200601"), 
		(timestamp%10000)+randomNum.Int64()%1000)
}

// Create zakat transaction
func createZakatTransaction(org string, suffix string) TransactionResult {
	start := time.Now()
	
	zakatID := generateZakatID(org)
	muzakki := fmt.Sprintf("Go Stress Test User %s", suffix)
	amount := "750000"
	
	args := fmt.Sprintf(`"%s","PROG-2024-0001","%s","%s","maal","transfer","YDSF %s","REF001"`, 
		zakatID, muzakki, amount, 
		map[string]string{"org1": "Malang", "org2": "Jatim"}[org])
	
	output, err := executeChaincode(org, "AddZakat", args, false)
	duration := time.Since(start)
	
	result := TransactionResult{
		ID:        zakatID,
		Duration:  duration,
		Success:   err == nil && contains(output, "Chaincode invoke successful"),
		Operation: "AddZakat",
		Timestamp: start,
	}
	
	if !result.Success {
		result.Error = fmt.Sprintf("Error: %v, Output: %s", err, output)
	}
	
	return result
}

// Validate payment
func validatePayment(org, zakatID string) TransactionResult {
	start := time.Now()
	
	receiptNumber := fmt.Sprintf("RCP-GO-STRESS-%d-%d", time.Now().Unix(), 
		func() int64 { n, _ := rand.Int(rand.Reader, big.NewInt(9999)); return n.Int64() }())
	validatedBy := "GoStressTestAdmin"
	
	args := fmt.Sprintf(`"%s","%s","%s"`, zakatID, receiptNumber, validatedBy)
	
	output, err := executeChaincode(org, "ValidatePayment", args, false)
	duration := time.Since(start)
	
	result := TransactionResult{
		ID:        zakatID,
		Duration:  duration,
		Success:   err == nil && contains(output, "Chaincode invoke successful"),
		Operation: "ValidatePayment",
		Timestamp: start,
	}
	
	if !result.Success {
		result.Error = fmt.Sprintf("Error: %v, Output: %s", err, output)
	}
	
	return result
}

// Query zakat
func queryZakat(org, zakatID string) TransactionResult {
	start := time.Now()
	
	args := fmt.Sprintf(`"%s"`, zakatID)
	output, err := executeChaincode(org, "QueryZakat", args, true)
	duration := time.Since(start)
	
	result := TransactionResult{
		ID:        zakatID,
		Duration:  duration,
		Success:   err == nil && isValidJSON(output),
		Operation: "QueryZakat",
		Timestamp: start,
	}
	
	if !result.Success {
		result.Error = fmt.Sprintf("Error: %v, Output: %s", err, output)
	}
	
	return result
}

// Test concurrent transaction creation
func testConcurrentTransactions() TestResults {
	fmt.Printf("=== GO STRESS TEST 1: Concurrent Transaction Creation (%d transactions) ===\n", CONCURRENT_TRANSACTIONS)
	
	start := time.Now()
	results := make(chan TransactionResult, CONCURRENT_TRANSACTIONS)
	
	// Use semaphore to limit concurrent goroutines
	sem := make(chan struct{}, MAX_GOROUTINES)
	var wg sync.WaitGroup
	
	for i := 0; i < CONCURRENT_TRANSACTIONS; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			sem <- struct{}{} // Acquire semaphore
			defer func() { <-sem }() // Release semaphore
			
			org := orgs[index%len(orgs)]
			suffix := fmt.Sprintf("CT%d", index)
			result := createZakatTransaction(org, suffix)
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
	
	return TestResults{
		TotalTransactions: len(allResults),
		SuccessCount:     successCount,
		FailureCount:     len(allResults) - successCount,
		AverageDuration:  avgDuration,
		TotalDuration:    testDuration,
		TPS:              tps,
		Results:          allResults,
	}
}

// Test validation burst
func testValidationBurst(successfulTxs []string) TestResults {
	fmt.Printf("=== GO STRESS TEST 2: Payment Validation Burst Load (%d validations) ===\n", len(successfulTxs))
	
	start := time.Now()
	results := make(chan TransactionResult, len(successfulTxs))
	
	sem := make(chan struct{}, MAX_GOROUTINES)
	var wg sync.WaitGroup
	
	for i, txID := range successfulTxs {
		if i >= VALIDATION_BURST_SIZE {
			break
		}
		
		wg.Add(1)
		go func(index int, zakatID string) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			
			org := orgs[index%len(orgs)]
			result := validatePayment(org, zakatID)
			results <- result
		}(i, txID)
	}
	
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
	avgDuration := time.Duration(0)
	if len(allResults) > 0 {
		avgDuration = totalDuration / time.Duration(len(allResults))
	}
	tps := float64(successCount) / testDuration.Seconds()
	
	return TestResults{
		TotalTransactions: len(allResults),
		SuccessCount:     successCount,
		FailureCount:     len(allResults) - successCount,
		AverageDuration:  avgDuration,
		TotalDuration:    testDuration,
		TPS:              tps,
		Results:          allResults,
	}
}

// Test query performance
func testQueryPerformance(successfulTxs []string) TestResults {
	fmt.Printf("=== GO STRESS TEST 3: Query Performance Under Load (%d queries) ===\n", QUERY_LOAD_SIZE)
	
	start := time.Now()
	results := make(chan TransactionResult, QUERY_LOAD_SIZE)
	
	sem := make(chan struct{}, MAX_GOROUTINES)
	var wg sync.WaitGroup
	
	for i := 0; i < QUERY_LOAD_SIZE; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			
			org := orgs[index%len(orgs)]
			var zakatID string
			if len(successfulTxs) > 0 {
				zakatID = successfulTxs[index%len(successfulTxs)]
			} else {
				zakatID = "ZKT-YDSF-MLG-202506-1453" // Fallback ID
			}
			
			result := queryZakat(org, zakatID)
			results <- result
		}(i)
	}
	
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
	
	return TestResults{
		TotalTransactions: len(allResults),
		SuccessCount:     successCount,
		FailureCount:     len(allResults) - successCount,
		AverageDuration:  avgDuration,
		TotalDuration:    testDuration,
		TPS:              tps,
		Results:          allResults,
	}
}

// Helper functions
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || 
		(len(s) > len(substr) && 
			(s[:len(substr)] == substr || s[len(s)-len(substr):] == substr || 
				func() bool {
					for i := 0; i <= len(s)-len(substr); i++ {
						if s[i:i+len(substr)] == substr {
							return true
						}
					}
					return false
				}())))
}

func isValidJSON(s string) bool {
	var js json.RawMessage
	return json.Unmarshal([]byte(s), &js) == nil
}

func printResults(testName string, results TestResults) {
	fmt.Printf("\n%s Results:\n", testName)
	fmt.Printf("  Total Duration: %.2fs\n", results.TotalDuration.Seconds())
	fmt.Printf("  Successful: %d\n", results.SuccessCount)
	fmt.Printf("  Failed: %d\n", results.FailureCount)
	fmt.Printf("  Average Response Time: %.3fs\n", results.AverageDuration.Seconds())
	fmt.Printf("  TPS: %.2f\n", results.TPS)
	
	successRate := float64(results.SuccessCount) / float64(results.TotalTransactions) * 100
	
	if testName == "Concurrent Transactions" && successRate >= 60 {
		fmt.Printf("✅ Concurrent transaction test PASSED (%.1f%% success rate)\n", successRate)
	} else if testName == "Validation Burst" && successRate >= 50 {
		fmt.Printf("✅ Validation burst test PASSED (%.1f%% success rate)\n", successRate)
	} else if testName == "Query Performance" && successRate >= 70 {
		fmt.Printf("✅ Query performance test PASSED (%.1f%% success rate)\n", successRate)
	} else {
		fmt.Printf("❌ %s test FAILED (%.1f%% success rate)\n", testName, successRate)
	}
}

func main() {
	fmt.Println("🚀 Starting Go-based High Performance Stress Test Suite")
	fmt.Println("Testing zakat network performance with true goroutine parallelism")
	
	startTime := time.Now()
	var passedTests int
	
	// Test 1: Concurrent transactions
	txResults := testConcurrentTransactions()
	printResults("Concurrent Transactions", txResults)
	if float64(txResults.SuccessCount)/float64(txResults.TotalTransactions) >= 0.6 {
		passedTests++
	}
	
	// Extract successful transaction IDs for validation
	var successfulTxs []string
	for _, result := range txResults.Results {
		if result.Success {
			successfulTxs = append(successfulTxs, result.ID)
		}
	}
	
	// Test 2: Validation burst (if we have successful transactions)
	if len(successfulTxs) > 0 {
		validationResults := testValidationBurst(successfulTxs)
		printResults("Validation Burst", validationResults)
		if float64(validationResults.SuccessCount)/float64(validationResults.TotalTransactions) >= 0.5 {
			passedTests++
		}
	}
	
	// Test 3: Query performance
	queryResults := testQueryPerformance(successfulTxs)
	printResults("Query Performance", queryResults)
	if float64(queryResults.SuccessCount)/float64(queryResults.TotalTransactions) >= 0.7 {
		passedTests++
	}
	
	// Final results
	totalDuration := time.Since(startTime)
	fmt.Printf("\n=== GO STRESS TEST RESULTS ===\n")
	fmt.Printf("📊 Final Results:\n")
	fmt.Printf("  Tests Passed: %d/3\n", passedTests)
	fmt.Printf("  Success Rate: %.1f%%\n", float64(passedTests)/3*100)
	fmt.Printf("  Total Test Duration: %.2fs\n", totalDuration.Seconds())
	
	if passedTests == 3 {
		fmt.Printf("🎉 ALL GO STRESS TESTS PASSED!\n")
		fmt.Printf("Network demonstrates excellent performance with goroutine parallelism.\n")
		os.Exit(0)
	} else {
		fmt.Printf("❌ SOME GO STRESS TESTS FAILED\n")
		fmt.Printf("Review results for performance optimization opportunities.\n")
		os.Exit(1)
	}
}