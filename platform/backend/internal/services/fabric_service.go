package services

import (
"encoding/json"
"fmt"
"log"
"time"

"github.com/hyperledger/fabric-sdk-go/pkg/gateway"
)

// FabricService provides chaincode interaction methods
type FabricService struct {
contract      *gateway.Contract
idGenerator   *IDGeneratorService
}

// NewFabricService creates a new Fabric service
func NewFabricService(contract *gateway.Contract) *FabricService {
return &FabricService{
contract:    contract,
idGenerator: NewIDGeneratorService(),
}
}

// AddZakat creates a new zakat donation in the blockchain
// Maps backend parameters to chaincode signature: AddZakat(id, programID, muzakki, amount, zakatType, paymentMethod, organization, referralCode)
func (f *FabricService) AddZakat(donorName, donorPhone, zakatType string, amount float64, programID, referralCode string) (string, error) {
// Generate unique zakat ID
zakatID := f.idGenerator.GenerateZakatID("YDSF Malang", 1) // Default to Malang for MVP

// Map zakat type to payment method (simplified for MVP)
paymentMethod := "transfer" // Default payment method for MVP
organization := "YDSF Malang" // Default organization for MVP

// Convert amount to string
amountStr := fmt.Sprintf("%.2f", amount)

// Prepare arguments for chaincode in correct order
args := []string{
zakatID,          // id
programID,        // programID (can be empty)
donorName,        // muzakki
amountStr,        // amount
zakatType,        // zakatType (fitrah/maal)
paymentMethod,    // paymentMethod
organization,     // organization
referralCode,     // referralCode (can be empty)
}

log.Printf("🔗 Calling AddZakat chaincode with args: %v", args)

// Call chaincode
_, err := f.contract.SubmitTransaction("AddZakat", args...)
if err != nil {
return "", fmt.Errorf("failed to submit AddZakat transaction: %w", err)
}

log.Printf("✅ Successfully added zakat to blockchain: %s", zakatID)
return zakatID, nil
}

// AutoValidatePayment auto-validates a pending payment
func (f *FabricService) AutoValidatePayment(zakatID, paymentReference string) error {
log.Printf("🔗 Calling AutoValidatePayment for: %s", zakatID)

_, err := f.contract.SubmitTransaction("AutoValidatePayment", zakatID, paymentReference)
if err != nil {
return fmt.Errorf("failed to auto-validate payment: %w", err)
}

log.Printf("✅ Successfully auto-validated payment for: %s", zakatID)
return nil
}

// ValidatePayment manually validates a payment (admin action)
func (f *FabricService) ValidatePayment(zakatID, receiptNumber, validatedBy string) error {
log.Printf("🔗 Calling ValidatePayment for: %s", zakatID)

_, err := f.contract.SubmitTransaction("ValidatePayment", zakatID, receiptNumber, validatedBy)
if err != nil {
return fmt.Errorf("failed to validate payment: %w", err)
}

log.Printf("✅ Successfully validated payment for: %s", zakatID)
return nil
}

// QueryZakat queries a zakat donation by ID
func (f *FabricService) QueryZakat(zakatID string) (map[string]interface{}, error) {
log.Printf("🔍 Querying zakat: %s", zakatID)

result, err := f.contract.EvaluateTransaction("QueryZakat", zakatID)
if err != nil {
return nil, fmt.Errorf("failed to query zakat: %w", err)
}

var zakat map[string]interface{}
err = json.Unmarshal(result, &zakat)
if err != nil {
return nil, fmt.Errorf("failed to unmarshal zakat data: %w", err)
}

return zakat, nil
}

// GetAllZakat gets all zakat donations
func (f *FabricService) GetAllZakat() ([]map[string]interface{}, error) {
log.Printf("🔍 Querying all zakat donations")

result, err := f.contract.EvaluateTransaction("GetAllZakat")
if err != nil {
return nil, fmt.Errorf("failed to get all zakat: %w", err)
}

var zakats []map[string]interface{}
err = json.Unmarshal(result, &zakats)
if err != nil {
return nil, fmt.Errorf("failed to unmarshal zakat data: %w", err)
}

return zakats, nil
}

// GetZakatByStatus gets zakat donations by status
func (f *FabricService) GetZakatByStatus(status string) ([]map[string]interface{}, error) {
log.Printf("🔍 Querying zakat by status: %s", status)

result, err := f.contract.EvaluateTransaction("GetZakatByStatus", status)
if err != nil {
return nil, fmt.Errorf("failed to get zakat by status: %w", err)
}

var zakats []map[string]interface{}
err = json.Unmarshal(result, &zakats)
if err != nil {
return nil, fmt.Errorf("failed to unmarshal zakat data: %w", err)
}

return zakats, nil
}

// DistributeZakat distributes a collected zakat
func (f *FabricService) DistributeZakat(zakatID, recipientName string, amount float64, distributedBy string) error {
// Generate distribution ID
distributionID := f.idGenerator.GenerateDistributionID(1)

// Current timestamp
timestamp := fmt.Sprintf("%d", time.Now().Unix())
amountStr := fmt.Sprintf("%.2f", amount)

log.Printf("🔗 Calling DistributeZakat for: %s", zakatID)

_, err := f.contract.SubmitTransaction("DistributeZakat", 
zakatID, distributionID, recipientName, amountStr, timestamp, distributedBy)
if err != nil {
return fmt.Errorf("failed to distribute zakat: %w", err)
}

log.Printf("✅ Successfully distributed zakat: %s", zakatID)
return nil
}

// CreateProgram creates a new donation program
func (f *FabricService) CreateProgram(name, description string, targetAmount float64, createdBy string) (string, error) {
// Generate program ID
programID := f.idGenerator.GenerateProgramID("2024", 1)

// Convert target amount to string
targetStr := fmt.Sprintf("%.2f", targetAmount)

// Timestamps
startDate := time.Now().Format(time.RFC3339)
endDate := time.Now().AddDate(1, 0, 0).Format(time.RFC3339) // 1 year from now

log.Printf("🔗 Calling CreateProgram: %s", name)

_, err := f.contract.SubmitTransaction("CreateProgram", 
programID, name, description, targetStr, startDate, endDate, createdBy)
if err != nil {
return "", fmt.Errorf("failed to create program: %w", err)
}

log.Printf("✅ Successfully created program: %s", programID)
return programID, nil
}

// GetAllPrograms gets all donation programs
func (f *FabricService) GetAllPrograms() ([]map[string]interface{}, error) {
log.Printf("🔍 Querying all programs")

result, err := f.contract.EvaluateTransaction("GetAllPrograms")
if err != nil {
return nil, fmt.Errorf("failed to get all programs: %w", err)
}

var programs []map[string]interface{}
err = json.Unmarshal(result, &programs)
if err != nil {
return nil, fmt.Errorf("failed to unmarshal program data: %w", err)
}

return programs, nil
}
