package main

import (
	"fmt"
	"os/exec"
	"sync"
	"time"
)

// Test configuration
const (
	CONCURRENT_TRANSACTIONS = 50
	MAX_GOROUTINES         = 15
)

// Transaction result
type TransactionResult struct {
	ID       string
	Duration time.Duration
	Success  bool
	Error    string
}

// Execute the bash-based chaincode function
func executeZakatTransaction(suffix string) TransactionResult {
	start := time.Now()
	
	// Use the working bash functions from our existing scripts
	cmd := exec.Command("bash", "-c", fmt.Sprintf(`
		# Generate unique ID
		timestamp=$(date +%%s)
		random_num=$((RANDOM %% 9999))
		zakat_id="ZKT-YDSF-MLG-$(date +%%Y%%m)-$(printf "%%04d" $((timestamp %% 10000 + random_num %% 1000)))"
		
		# Choose organization
		if [ $((timestamp %% 2)) -eq 0 ]; then
			org_ip="10.104.0.2"
			cli="cli.org1.fabriczakat.local"
			org_code="MLG"
		else
			org_ip="10.104.0.4"
			cli="cli.org2.fabriczakat.local"
			org_code="JTM"
			zakat_id="ZKT-YDSF-JTM-$(date +%%Y%%m)-$(printf "%%04d" $((timestamp %% 10000 + random_num %% 1000)))"
		fi
		
		# Create transaction using proven working command
		result=$(ssh fabricadmin@$org_ip "docker exec $cli peer chaincode invoke -o orderer.fabriczakat.local:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org1.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem --peerAddresses peer.org2.fabriczakat.local:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.fabriczakat.local/msp/tlscacerts/tls-ca-cert.pem -C zakatchannel -n zakat -c '{\"function\":\"AddZakat\",\"Args\":[\"'$zakat_id'\",\"PROG-2024-0001\",\"Go Stress User %s\",\"750000\",\"maal\",\"transfer\",\"YDSF '$org_code'\",\"REF001\"]}' --waitForEvent" 2>&1)
		
		if echo "$result" | grep -q "Chaincode invoke successful"; then
			echo "SUCCESS:$zakat_id"
		else
			echo "FAILED:$zakat_id:$result"
		fi
	`, suffix))
	
	output, err := cmd.CombinedOutput()
	duration := time.Since(start)
	
	result := TransactionResult{
		Duration: duration,
		Success:  err == nil && containsSuccess(string(output)),
	}
	
	if result.Success {
		result.ID = extractID(string(output))
	} else {
		result.Error = string(output)
	}
	
	return result
}

// Execute query using bash
func executeQuery(zakatID string) TransactionResult {
	start := time.Now()
	
	cmd := exec.Command("bash", "-c", fmt.Sprintf(`
		# Choose organization randomly
		if [ $((RANDOM %% 2)) -eq 0 ]; then
			org_ip="10.104.0.2"
			cli="cli.org1.fabriczakat.local"
		else
			org_ip="10.104.0.4" 
			cli="cli.org2.fabriczakat.local"
		fi
		
		# Query transaction
		result=$(ssh fabricadmin@$org_ip "docker exec $cli peer chaincode query -C zakatchannel -n zakat -c '{\"function\":\"QueryZakat\",\"Args\":[\"%s\"]}'" 2>&1)
		
		if echo "$result" | jq . >/dev/null 2>&1; then
			echo "SUCCESS:$result"
		else
			echo "FAILED:$result"
		fi
	`, zakatID))
	
	output, err := cmd.CombinedOutput()
	duration := time.Since(start)
	
	result := TransactionResult{
		ID:       zakatID,
		Duration: duration,
		Success:  err == nil && containsSuccess(string(output)),
	}
	
	if !result.Success {
		result.Error = string(output)
	}
	
	return result
}

func containsSuccess(s string) bool {
	return len(s) > 8 && s[:8] == "SUCCESS:"
}

func extractID(s string) string {
	if containsSuccess(s) {
		parts := []rune(s)
		for i := 8; i < len(parts); i++ {
			if parts[i] == '\n' || parts[i] == '\r' {
				return string(parts[8:i])
			}
		}
		return string(parts[8:])
	}
	return ""
}

// Test concurrent transactions with goroutines
func testConcurrentTransactions() {
	fmt.Printf("🚀 Starting Go Concurrent Transaction Test (%d transactions)\n", CONCURRENT_TRANSACTIONS)
	fmt.Printf("Using %d max goroutines for true parallelism\n", MAX_GOROUTINES)
	
	start := time.Now()
	
	// Channel to receive results
	results := make(chan TransactionResult, CONCURRENT_TRANSACTIONS)
	
	// Semaphore to limit concurrent goroutines
	sem := make(chan struct{}, MAX_GOROUTINES)
	var wg sync.WaitGroup
	
	// Launch goroutines
	for i := 0; i < CONCURRENT_TRANSACTIONS; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			sem <- struct{}{}        // Acquire semaphore
			defer func() { <-sem }() // Release semaphore
			
			suffix := fmt.Sprintf("GT%d", index)
			result := executeZakatTransaction(suffix)
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
	fmt.Printf("\n📊 Concurrent Transaction Results:\n")
	fmt.Printf("  Total Duration: %.2fs\n", testDuration.Seconds())
	fmt.Printf("  Successful: %d\n", successCount)
	fmt.Printf("  Failed: %d\n", len(allResults)-successCount)
	fmt.Printf("  Average Response Time: %.3fs\n", avgDuration.Seconds())
	fmt.Printf("  🎯 TPS: %.2f transactions/second\n", tps)
	
	successRate := float64(successCount) / float64(len(allResults)) * 100
	if successRate >= 60 {
		fmt.Printf("✅ Concurrent transaction test PASSED (%.1f%% success rate)\n", successRate)
	} else {
		fmt.Printf("❌ Concurrent transaction test FAILED (%.1f%% success rate)\n", successRate)
	}
	
	// Test queries with successful transactions
	if successCount > 0 {
		fmt.Printf("\n🔍 Testing Query Performance with %d successful transactions...\n", successCount)
		
		queryStart := time.Now()
		queryResults := make(chan TransactionResult, successCount)
		var queryWg sync.WaitGroup
		
		count := 0
		for _, result := range allResults {
			if result.Success && count < 20 { // Limit to 20 queries
				queryWg.Add(1)
				go func(id string) {
					defer queryWg.Done()
					sem <- struct{}{}
					defer func() { <-sem }()
					
					queryResult := executeQuery(id)
					queryResults <- queryResult
				}(result.ID)
				count++
			}
		}
		
		go func() {
			queryWg.Wait()
			close(queryResults)
		}()
		
		// Collect query results
		querySuccessCount := 0
		queryCount := 0
		var queryTotalDuration time.Duration
		
		for qResult := range queryResults {
			queryCount++
			if qResult.Success {
				querySuccessCount++
			}
			queryTotalDuration += qResult.Duration
		}
		
		queryTestDuration := time.Since(queryStart)
		queryTPS := float64(querySuccessCount) / queryTestDuration.Seconds()
		
		fmt.Printf("\n📊 Query Performance Results:\n")
		fmt.Printf("  Query Duration: %.2fs\n", queryTestDuration.Seconds())
		fmt.Printf("  Successful Queries: %d/%d\n", querySuccessCount, queryCount)
		fmt.Printf("  🎯 Query TPS: %.2f queries/second\n", queryTPS)
		
		querySuccessRate := float64(querySuccessCount) / float64(queryCount) * 100
		if querySuccessRate >= 70 {
			fmt.Printf("✅ Query performance test PASSED (%.1f%% success rate)\n", querySuccessRate)
		} else {
			fmt.Printf("❌ Query performance test FAILED (%.1f%% success rate)\n", querySuccessRate)
		}
	}
}

func main() {
	fmt.Println("🚀 Go-powered Hyperledger Fabric Stress Test")
	fmt.Println("True goroutine parallelism for maximum TPS")
	fmt.Printf("Target: >60%% transaction success, >70%% query success\n\n")
	
	testConcurrentTransactions()
	
	fmt.Println("\n🎉 Go stress test completed!")
	fmt.Println("This demonstrates the power of goroutines vs bash delays!")
}