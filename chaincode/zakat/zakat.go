package main

import (
	"encoding/json"
	"fmt"
	"regexp"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing zakat donations
type SmartContract struct {
	contractapi.Contract
}

// Zakat describes a zakat donation transaction
type Zakat struct {
	ID             string  `json:"ID"`                     // Format: ZKT-{ORG}-{YYYY}{MM}-{COUNTER}
	ProgramID      string  `json:"programID,omitempty"`    // Which donation program
	Muzakki        string  `json:"muzakki"`                // Donor's name
	Amount         float64 `json:"amount"`                 // Amount in IDR
	Type           string  `json:"type"`                   // "fitrah" or "maal"
	PaymentMethod  string  `json:"paymentMethod"`          // "transfer", "ewallet", "credit_card"
	Status         string  `json:"status"`                 // "pending", "collected", "distributed"
	Organization   string  `json:"organization"`           // Collecting organization
	ReferralCode   string  `json:"referralCode,omitempty"` // Officer's referral code (optional)
	ReceiptNumber  string  `json:"receiptNumber"`          // Receipt/invoice number
	Timestamp      string  `json:"timestamp"`              // When donation was submitted
	ValidatedBy    string  `json:"validatedBy"`            // Admin who validated
	ValidationDate string  `json:"validationDate"`         // When payment was validated
	Mustahik       string  `json:"mustahik"`               // Recipient's name (if distributed)
	Distribution   float64 `json:"distribution"`           // Distributed amount
	DistributedAt  string  `json:"distributedAt"`          // Distribution timestamp
	DistributionID string  `json:"distributionID"`         // Unique ID for the distribution event
	DistributedBy  string  `json:"distributedBy"`          // Admin/Officer who performed the distribution
}

// DonationProgram describes a donation campaign/program
type DonationProgram struct {
	ID          string  `json:"ID"`          // Format: PROG-{YYYY}-{COUNTER}
	Name        string  `json:"name"`        // Program name
	Description string  `json:"description"` // Program description
	Target      float64 `json:"target"`      // Target amount
	Collected   float64 `json:"collected"`   // Amount collected so far
	Distributed float64 `json:"distributed"` // Amount distributed so far from this program
	StartDate   string  `json:"startDate"`   // Program start date
	EndDate     string  `json:"endDate"`     // Program end date
	Status      string  `json:"status"`      // "active", "completed", "suspended"
	CreatedBy   string  `json:"createdBy"`   // Admin who created the program
	CreatedAt   string  `json:"createdAt"`   // Creation timestamp
}

// Officer describes a petugas/officer with referral tracking
type Officer struct {
	ID             string  `json:"ID"`             // Format: OFF-{YYYY}-{COUNTER}
	Name           string  `json:"name"`           // Officer name
	ReferralCode   string  `json:"referralCode"`   // Unique referral code
	TotalReferred  float64 `json:"totalReferred"`  // Total amount from referrals
	CommissionRate float64 `json:"commissionRate"` // Commission percentage
	Status         string  `json:"status"`         // "active", "inactive"
	CreatedAt      string  `json:"createdAt"`      // Registration timestamp
}

// Enhanced validation functions supporting nanosecond timestamp-based IDs for true uniqueness
func validateZakatID(id string) error {
	if len(id) == 0 {
		return fmt.Errorf("zakat ID cannot be empty")
	}
	
	// New format: ZKT-YDSF-{MLG|JTM}-{UNIXTIMESTAMPNANO}-{SEQUENCE}
	// Also supports legacy format for backward compatibility
	pattern := `^ZKT-YDSF-(MLG|JTM)-\d+-\d+$`
	matched, err := regexp.MatchString(pattern, id)
	if err != nil {
		return fmt.Errorf("error validating zakat ID format: %v", err)
	}
	if !matched {
		return fmt.Errorf("invalid zakat ID format. Expected format: ZKT-YDSF-{MLG|JTM}-{TIMESTAMP}-{SEQUENCE} (example: ZKT-YDSF-MLG-1735689000000000000-0001)")
	}
	return nil
}

func validateProgramID(id string) error {
	if len(id) == 0 {
		return fmt.Errorf("program ID cannot be empty")
	}
	
	// New format: PROG-{TYPE}-{UNIXTIMESTAMPNANO}-{SEQUENCE}
	// Also supports legacy format for backward compatibility
	pattern := `^PROG-[A-Z0-9]+-\d+-\d+$`
	matched, err := regexp.MatchString(pattern, id)
	if err != nil {
		return fmt.Errorf("error validating program ID format: %v", err)
	}
	if !matched {
		return fmt.Errorf("invalid program ID format. Expected format: PROG-{TYPE}-{TIMESTAMP}-{SEQUENCE} (example: PROG-2024-1735689000000000000-0001)")
	}
	return nil
}

func validateOfficerID(id string) error {
	if len(id) == 0 {
		return fmt.Errorf("officer ID cannot be empty")
	}
	
	// New format: OFF-{TYPE}-{UNIXTIMESTAMPNANO}-{SEQUENCE}
	// Also supports legacy format for backward compatibility
	pattern := `^OFF-[A-Z0-9]+-\d+-\d+$`
	matched, err := regexp.MatchString(pattern, id)
	if err != nil {
		return fmt.Errorf("error validating officer ID format: %v", err)
	}
	if !matched {
		return fmt.Errorf("invalid officer ID format. Expected format: OFF-{TYPE}-{TIMESTAMP}-{SEQUENCE} (example: OFF-2024-1735689000000000000-0001)")
	}
	return nil
}

func validateTimestamp(timestamp string) error {
	_, err := time.Parse(time.RFC3339, timestamp)
	if err != nil {
		return fmt.Errorf("invalid timestamp format. Expected ISO 8601 format")
	}
	return nil
}

func validateZakatType(zakatType string) error {
	if zakatType != "fitrah" && zakatType != "maal" {
		return fmt.Errorf("invalid zakat type. Must be either 'fitrah' or 'maal'")
	}
	return nil
}

func validatePaymentMethod(method string) error {
	validMethods := []string{"transfer", "ewallet", "credit_card", "debit_card", "cash"}
	for _, valid := range validMethods {
		if method == valid {
			return nil
		}
	}
	return fmt.Errorf("invalid payment method. Must be one of: transfer, ewallet, credit_card, debit_card, cash")
}

func validateStatus(status string) error {
	if status != "pending" && status != "collected" && status != "distributed" {
		return fmt.Errorf("invalid status. Must be 'pending', 'collected', or 'distributed'")
	}
	return nil
}

func validateProgramStatus(status string) error {
	if status != "active" && status != "completed" && status != "suspended" {
		return fmt.Errorf("invalid program status. Must be 'active', 'completed', or 'suspended'")
	}
	return nil
}

func validateOfficerStatus(status string) error {
	if status != "active" && status != "inactive" {
		return fmt.Errorf("invalid officer status. Must be 'active' or 'inactive'")
	}
	return nil
}

func validateAmount(amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("invalid amount. Must be greater than 0")
	}
	return nil
}

func validateOrganization(org string) error {
	if org != "YDSF Malang" && org != "YDSF Jatim" {
		return fmt.Errorf("invalid organization. Must be either 'YDSF Malang' or 'YDSF Jatim'")
	}
	return nil
}

// ID Generation functions with nanosecond timestamp for true uniqueness
func generateZakatID(orgCode string, sequence int) string {
	nanoTimestamp := time.Now().UnixNano()
	return fmt.Sprintf("ZKT-YDSF-%s-%d-%04d", orgCode, nanoTimestamp, sequence)
}

func generateProgramID(programType string, sequence int) string {
	nanoTimestamp := time.Now().UnixNano()
	return fmt.Sprintf("PROG-%s-%d-%04d", programType, nanoTimestamp, sequence)
}

func generateOfficerID(officerType string, sequence int) string {
	nanoTimestamp := time.Now().UnixNano()
	return fmt.Sprintf("OFF-%s-%d-%04d", officerType, nanoTimestamp, sequence)
}

// Helper function to generate unique distribution ID
func generateDistributionID(sequence int) string {
	nanoTimestamp := time.Now().UnixNano()
	return fmt.Sprintf("DIST-%d-%04d", nanoTimestamp, sequence)
}

// InitLedger initializes the ledger with sample data if it hasn't been initialized yet.
// It checks for the existence of a sample program (PROG-2024-0001).
// If the program exists, it logs that initialization is being skipped.
// Otherwise, it creates a sample DonationProgram and a sample Officer.
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	sampleProgramID := "PROG-2024-0001"
	programExists, err := ctx.GetStub().GetState(sampleProgramID)
	if err != nil {
		return fmt.Errorf("failed to check sample program existence: %w", err)
	}

	if programExists != nil {
		// Consider using a logging mechanism if available, e.g., ctx.GetClientIdentity().GetID() for context
		fmt.Printf("Initialization skipped: Sample program %s already exists.\n", sampleProgramID)
		return nil
	}

	fmt.Printf("Initializing ledger with sample data as program %s does not exist.\n", sampleProgramID)
	timestamp := time.Now().Format(time.RFC3339)

	// Create sample program with legacy ID for backward compatibility
	program := DonationProgram{
		ID:          sampleProgramID,
		Name:        "Bantuan Pendidikan Anak Yatim",
		Description: "Program bantuan pendidikan untuk anak-anak yatim yang membutuhkan.",
		Target:      100000000, // 100 Million IDR
		Collected:   0,
		Distributed: 0, // Initialize Distributed to 0
		StartDate:   "2024-01-01T00:00:00Z",
		EndDate:     "2024-12-31T23:59:59Z",
		Status:      "active",
		CreatedBy:   "system", // Or a specific admin user ID
		CreatedAt:   timestamp,
	}

	programJSON, err := json.Marshal(program)
	if err != nil {
		return fmt.Errorf("failed to marshal sample program: %w", err)
	}

	err = ctx.GetStub().PutState(program.ID, programJSON)
	if err != nil {
		return fmt.Errorf("failed to put sample program %s: %w", program.ID, err)
	}
	fmt.Printf("Successfully created sample program: %s\n", program.ID)

	// Create sample officer with legacy ID for backward compatibility
	officer := Officer{
		ID:             "OFF-2024-0001",
		Name:           "Ahmad Petugas",
		ReferralCode:   "REF001", // Ensure this is unique if used as a lookup key
		TotalReferred:  0,
		CommissionRate: 0.05, // 5%
		Status:         "active",
		CreatedAt:      timestamp,
	}

	officerJSON, err := json.Marshal(officer)
	if err != nil {
		return fmt.Errorf("failed to marshal sample officer: %w", err)
	}

	err = ctx.GetStub().PutState(officer.ID, officerJSON)
	if err != nil {
		return fmt.Errorf("failed to put sample officer %s: %w", officer.ID, err)
	}
	fmt.Printf("Successfully created sample officer: %s\n", officer.ID)

	fmt.Println("Ledger initialization complete.")
	return nil
}

// PROGRAM MANAGEMENT FUNCTIONS

// CreateProgram creates a new donation program
func (s *SmartContract) CreateProgram(ctx contractapi.TransactionContextInterface, id string, name string, description string, target float64, startDate string, endDate string, createdBy string) error {
	if err := validateProgramID(id); err != nil {
		return err
	}
	if err := validateTimestamp(startDate); err != nil {
		return err
	}
	if err := validateTimestamp(endDate); err != nil {
		return err
	}
	if err := validateAmount(target); err != nil {
		return err
	}

	exists, err := ctx.GetStub().GetState(id)
	if err != nil {
		return fmt.Errorf("failed to check program existence: %v", err)
	}
	if exists != nil {
		return fmt.Errorf("program %s already exists", id)
	}

	program := DonationProgram{
		ID:          id,
		Name:        name,
		Description: description,
		Target:      target,
		Collected:   0,
		Distributed: 0, // Initialize Distributed to 0 for new programs
		StartDate:   startDate,
		EndDate:     endDate,
		Status:      "active",
		CreatedBy:   createdBy,
		CreatedAt:   time.Now().Format(time.RFC3339),
	}

	programJSON, err := json.Marshal(program)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, programJSON)
}

// GetProgram returns a program by ID
func (s *SmartContract) GetProgram(ctx contractapi.TransactionContextInterface, id string) (DonationProgram, error) {
	programJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return DonationProgram{}, fmt.Errorf("failed to read program: %v", err)
	}
	if programJSON == nil {
		return DonationProgram{}, fmt.Errorf("program %s does not exist", id)
	}

	var program DonationProgram
	err = json.Unmarshal(programJSON, &program)
	if err != nil {
		return DonationProgram{}, fmt.Errorf("failed to unmarshal program: %v", err)
	}

	return program, nil
}

// GetAllPrograms returns all programs
func (s *SmartContract) GetAllPrograms(ctx contractapi.TransactionContextInterface) ([]DonationProgram, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("PROG-", "PROG-\uffff")
	if err != nil {
		return []DonationProgram{}, err
	}
	defer resultsIterator.Close()

	var programs []DonationProgram
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return []DonationProgram{}, err
		}

		var program DonationProgram
		err = json.Unmarshal(queryResponse.Value, &program)
		if err != nil {
			return []DonationProgram{}, err
		}
		programs = append(programs, program)
	}

	// Always return a non-nil slice
	if programs == nil {
		programs = []DonationProgram{}
	}
	return programs, nil
}

// OFFICER MANAGEMENT FUNCTIONS

// RegisterOfficer registers a new officer
func (s *SmartContract) RegisterOfficer(ctx contractapi.TransactionContextInterface, id string, name string, referralCode string) error {
	if err := validateOfficerID(id); err != nil {
		return err
	}

	exists, err := ctx.GetStub().GetState(id)
	if err != nil {
		return fmt.Errorf("failed to check officer existence: %v", err)
	}
	if exists != nil {
		return fmt.Errorf("officer %s already exists", id)
	}

	// Check if referral code already exists (should be unique)
	// This requires a query, which can be expensive. Consider if this check is critical path or can be handled by UI/app layer.
	// For now, let's assume referral codes are managed to be unique.
	// officerByReferral, _ := s.GetOfficerByReferral(ctx, referralCode)
	// if officerByReferral.ID != "" {
	// 	return fmt.Errorf("referral code %s is already in use by officer %s", referralCode, officerByReferral.ID)
	// }

	officer := Officer{
		ID:             id,
		Name:           name,
		ReferralCode:   referralCode,
		TotalReferred:  0,
		CommissionRate: 0.05, // Default 5%
		Status:         "active",
		CreatedAt:      time.Now().Format(time.RFC3339),
	}

	officerJSON, err := json.Marshal(officer)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, officerJSON)
}

// GetOfficerByReferral returns officer by referral code
func (s *SmartContract) GetOfficerByReferral(ctx contractapi.TransactionContextInterface, referralCode string) (Officer, error) {
	queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", referralCode)
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return Officer{}, fmt.Errorf("failed to query officer: %v", err)
	}
	defer resultsIterator.Close()

	if !resultsIterator.HasNext() {
		return Officer{}, fmt.Errorf("officer with referral code %s does not exist", referralCode)
	}

	queryResponse, err := resultsIterator.Next()
	if err != nil {
		return Officer{}, err
	}

	var officer Officer
	err = json.Unmarshal(queryResponse.Value, &officer)
	if err != nil {
		return Officer{}, fmt.Errorf("failed to unmarshal officer: %v", err)
	}

	// It's possible for multiple officers to have the same referral code if not enforced at RegisterOfficer.
	// This query will return the first one found. If uniqueness is critical, RegisterOfficer should prevent duplicates.
	if resultsIterator.HasNext() {
		// Log a warning if multiple officers found with the same referral code
		fmt.Printf("Warning: Multiple officers found with referral code %s. Returning the first one.\n", referralCode)
	}

	return officer, nil
}

// ZAKAT MANAGEMENT FUNCTIONS

// AddZakat adds a new zakat donation with "pending" status.
// programID and referralCode can be empty strings if not applicable.
// If programID is provided, it validates that the program exists.
// Zakat ID format is validated (e.g., ZKT-{ORG}-{YYYYMM}-{COUNTER}).
func (s *SmartContract) AddZakat(ctx contractapi.TransactionContextInterface, id string, programID string, muzakki string, amount float64, zakatType string, paymentMethod string, organization string, referralCode string) error {
	// Validate inputs
	if err := validateZakatID(id); err != nil {
		return err
	}
	if err := validateAmount(amount); err != nil {
		return err
	}
	if err := validateZakatType(zakatType); err != nil {
		return err
	}
	if err := validatePaymentMethod(paymentMethod); err != nil {
		return err
	}
	if err := validateOrganization(organization); err != nil {
		return err
	}
	if muzakki == "" {
		return fmt.Errorf("muzakki name cannot be empty")
	}

	// Check if program exists (if programID is provided and not an empty string)
	if programID != "" {
		if err := validateProgramID(programID); err != nil { // Also validate format of programID if provided
			return fmt.Errorf("invalid program ID format for '%s': %w", programID, err)
		}
		program, err := s.GetProgram(ctx, programID)
		if err != nil {
			return fmt.Errorf("failed to validate program ID '%s': %w", programID, err)
		}
		if program.ID == "" { // Should be redundant if GetProgram errors on not found
			return fmt.Errorf("program with ID '%s' does not exist", programID)
		}
	}

	// Check if officer exists by referral code (if referralCode is provided and not an empty string)
	if referralCode != "" {
		officer, err := s.GetOfficerByReferral(ctx, referralCode)
		if err != nil {
			return fmt.Errorf("failed to validate referral code '%s': %w", referralCode, err)
		}
		if officer.ID == "" { // Should be redundant if GetOfficerByReferral errors on not found
			return fmt.Errorf("officer with referral code '%s' does not exist", referralCode)
		}
	}

	// Check if zakat already exists
	exists, err := s.ZakatExists(ctx, id)
	if err != nil {
		return fmt.Errorf("failed to check zakat existence for ID '%s': %w", id, err)
	}
	if exists {
		return fmt.Errorf("zakat %s already exists", id)
	}

	// Create zakat with pending status
	zakat := Zakat{
		ID:            id,
		ProgramID:     programID, // Will be empty if not provided
		Muzakki:       muzakki,
		Amount:        amount,
		Type:          zakatType,
		PaymentMethod: paymentMethod,
		Status:        "pending", // Initial status
		Organization:  organization,
		ReferralCode:  referralCode, // Will be empty if not provided
		Timestamp:     time.Now().Format(time.RFC3339),
		// Initialize distribution fields with defaults for schema validation
		ReceiptNumber:  "",
		ValidatedBy:    "",
		ValidationDate: "",
		Mustahik:       "",
		Distribution:   0,
		DistributedAt:  "",
		DistributionID: "",
		DistributedBy:  "",
	}

	zakatJSON, err := json.Marshal(zakat)
	if err != nil {
		return fmt.Errorf("failed to marshal zakat data: %w", err)
	}

	err = ctx.GetStub().PutState(id, zakatJSON)
	if err != nil {
		return fmt.Errorf("failed to put zakat %s to state: %w", id, err)
	}
	fmt.Printf("Successfully added Zakat: %s\n", id)
	return nil
}

// AutoValidatePayment automatically validates a pending payment with system-generated receipt.
// This function checks if the zakat is in pending status and calls ValidatePayment.
// Used by the auto-validation system for mock payments.
func (s *SmartContract) AutoValidatePayment(ctx contractapi.TransactionContextInterface, zakatID string, paymentGatewayRef string) error {
	if zakatID == "" {
		return fmt.Errorf("zakat ID cannot be empty")
	}

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

// ValidatePayment validates a pending payment. This function is typically restricted to admin users.
// It updates the Zakat status to "collected", records receipt details, and updates
// associated program and officer records if applicable.
func (s *SmartContract) ValidatePayment(ctx contractapi.TransactionContextInterface, zakatID string, receiptNumber string, validatedBy string) error {
	if zakatID == "" {
		return fmt.Errorf("zakat ID cannot be empty")
	}
	if receiptNumber == "" {
		return fmt.Errorf("receipt number cannot be empty")
	}
	if validatedBy == "" {
		return fmt.Errorf("validatedBy (admin user) cannot be empty")
	}

	zakat, err := s.QueryZakat(ctx, zakatID)
	if err != nil {
		return fmt.Errorf("failed to query zakat %s: %w", zakatID, err)
	}

	if zakat.Status != "pending" {
		return fmt.Errorf("zakat %s is not in pending status, current status: %s", zakatID, zakat.Status)
	}

	// Update Zakat details
	zakat.Status = "collected"
	zakat.ReceiptNumber = receiptNumber
	zakat.ValidatedBy = validatedBy
	zakat.ValidationDate = time.Now().Format(time.RFC3339)
	// Ensure distribution fields are initialized for schema compliance
	zakat.Mustahik = ""
	zakat.Distribution = 0
	zakat.DistributedAt = ""
	zakat.DistributionID = ""
	zakat.DistributedBy = ""

	// Update program collected amount if ProgramID is present
	if zakat.ProgramID != "" {
		program, err := s.GetProgram(ctx, zakat.ProgramID)
		if err != nil {
			return fmt.Errorf("failed to get program %s for Zakat %s: %w", zakat.ProgramID, zakatID, err)
		}
		program.Collected += zakat.Amount
		programJSON, err := json.Marshal(program)
		if err != nil {
			return fmt.Errorf("failed to marshal updated program %s: %w", zakat.ProgramID, err)
		}
		err = ctx.GetStub().PutState(program.ID, programJSON)
		if err != nil {
			return fmt.Errorf("failed to put updated program %s to state: %w", program.ID, err)
		}
		fmt.Printf("Successfully updated program %s collected amount.\n", program.ID)
	}

	// Update officer total referred amount if ReferralCode is present
	if zakat.ReferralCode != "" {
		officer, err := s.GetOfficerByReferral(ctx, zakat.ReferralCode)
		if err != nil {
			return fmt.Errorf("failed to get officer with referral code %s for Zakat %s: %w", zakat.ReferralCode, zakatID, err)
		}
		officer.TotalReferred += zakat.Amount
		officerJSON, err := json.Marshal(officer)
		if err != nil {
			return fmt.Errorf("failed to marshal updated officer %s: %w", officer.ID, err)
		}
		err = ctx.GetStub().PutState(officer.ID, officerJSON)
		if err != nil {
			return fmt.Errorf("failed to put updated officer %s to state: %w", officer.ID, err)
		}
		fmt.Printf("Successfully updated officer %s total referred amount.\n", officer.ID)
	}

	zakatJSON, err := json.Marshal(zakat)
	if err != nil {
		return fmt.Errorf("failed to marshal updated zakat %s: %w", zakatID, err)
	}

	err = ctx.GetStub().PutState(zakatID, zakatJSON)
	if err != nil {
		return fmt.Errorf("failed to put updated zakat %s to state: %w", zakatID, err)
	}
	fmt.Printf("Successfully validated payment for Zakat: %s\n", zakatID)
	return nil
}

// QueryZakat returns zakat by ID
func (s *SmartContract) QueryZakat(ctx contractapi.TransactionContextInterface, id string) (Zakat, error) {
	zakatJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return Zakat{}, fmt.Errorf("failed to read zakat: %v", err)
	}
	if zakatJSON == nil {
		return Zakat{}, fmt.Errorf("zakat %s does not exist", id)
	}

	var zakat Zakat
	err = json.Unmarshal(zakatJSON, &zakat)
	if err != nil {
		return Zakat{}, fmt.Errorf("failed to unmarshal zakat: %v", err)
	}

	return zakat, nil
}

// GetAllZakat returns all zakat records on the ledger
func (s *SmartContract) GetAllZakat(ctx contractapi.TransactionContextInterface) ([]Zakat, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("ZKT-", "ZKT-\uffff")
	if err != nil {
		return []Zakat{}, err // Ensure empty slice on error
	}
	defer resultsIterator.Close()

	var zakats []Zakat
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return []Zakat{}, err // Ensure empty slice on error
		}

		var zakat Zakat
		err = json.Unmarshal(queryResponse.Value, &zakat)
		if err != nil {
			return []Zakat{}, err // Ensure empty slice on error
		}
		zakats = append(zakats, zakat)
	}

	if zakats == nil {
		zakats = []Zakat{}
	}

	return zakats, nil
}

// GetZakatByStatus returns zakat transactions by status
func (s *SmartContract) GetZakatByStatus(ctx contractapi.TransactionContextInterface, status string) ([]Zakat, error) {
	if err := validateStatus(status); err != nil {
		return nil, err
	}

	queryString := fmt.Sprintf("{\"selector\":{\"status\":\"%s\"}}", status)
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to query zakat by status: %v", err)
	}
	defer resultsIterator.Close()

	var zakats []Zakat
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var zakat Zakat
		err = json.Unmarshal(queryResponse.Value, &zakat)
		if err != nil {
			return nil, err
		}
		zakats = append(zakats, zakat)
	}

	return zakats, nil
}

// GetZakatByProgram returns zakat transactions for a specific program
func (s *SmartContract) GetZakatByProgram(ctx contractapi.TransactionContextInterface, programID string) ([]Zakat, error) {
	queryString := fmt.Sprintf("{\"selector\":{\"programID\":\"%s\"}}", programID)
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to query zakat by program: %v", err)
	}
	defer resultsIterator.Close()

	var zakats []Zakat
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var zakat Zakat
		err = json.Unmarshal(queryResponse.Value, &zakat)
		if err != nil {
			return nil, err
		}
		zakats = append(zakats, zakat)
	}

	return zakats, nil
}

// GetZakatByOfficer returns zakat transactions referred by an officer
func (s *SmartContract) GetZakatByOfficer(ctx contractapi.TransactionContextInterface, referralCode string) ([]Zakat, error) {
	queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", referralCode)
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to query zakat by officer: %v", err)
	}
	defer resultsIterator.Close()

	var zakats []Zakat
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var zakat Zakat
		err = json.Unmarshal(queryResponse.Value, &zakat)
		if err != nil {
			return nil, err
		}
		zakats = append(zakats, zakat)
	}

	return zakats, nil
}

// GetZakatByMuzakki returns zakat transactions by muzakki name
func (s *SmartContract) GetZakatByMuzakki(ctx contractapi.TransactionContextInterface, muzakkiName string) ([]Zakat, error) {
	if muzakkiName == "" {
		return nil, fmt.Errorf("muzakki name cannot be empty")
	}

	queryString := fmt.Sprintf("{\"selector\":{\"muzakki\":\"%s\"}}", muzakkiName)
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to query zakat by muzakki: %w", err)
	}
	defer resultsIterator.Close()

	var zakats []Zakat
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("error iterating over zakat by muzakki results: %w", err)
		}

		var zakat Zakat
		err = json.Unmarshal(queryResponse.Value, &zakat)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshal zakat data for muzakki query: %w", err)
		}
		zakats = append(zakats, zakat)
	}

	if len(zakats) == 0 {
		fmt.Printf("No zakat records found for muzakki: %s\n", muzakkiName)
	} else {
		fmt.Printf("Found %d zakat records for muzakki: %s\n", len(zakats), muzakkiName)
	}

	return zakats, nil
}

// DistributeZakat distributes collected zakat.
// It updates the Zakat status to "distributed", records distribution details,
// and updates the associated program's distributed amount.
func (s *SmartContract) DistributeZakat(ctx contractapi.TransactionContextInterface, zakatID string, distributionID string, recipientName string, amount float64, distributionTimestamp string, distributedBy string) error {
	// Validate inputs
	if zakatID == "" {
		return fmt.Errorf("zakat ID cannot be empty")
	}
	if distributionID == "" {
		return fmt.Errorf("distribution ID cannot be empty")
	}
	if recipientName == "" {
		return fmt.Errorf("recipient name (mustahik) cannot be empty")
	}
	if err := validateAmount(amount); err != nil { // amount must be > 0
		return fmt.Errorf("invalid distribution amount: %w", err)
	}
	if err := validateTimestamp(distributionTimestamp); err != nil {
		return fmt.Errorf("invalid distribution timestamp: %w", err)
	}
	if distributedBy == "" {
		return fmt.Errorf("distributedBy (admin/officer) cannot be empty")
	}

	zakat, err := s.QueryZakat(ctx, zakatID)
	if err != nil {
		return fmt.Errorf("failed to query zakat %s for distribution: %w", zakatID, err)
	}

	if zakat.Status != "collected" {
		return fmt.Errorf("zakat %s must be in 'collected' status before distribution. Current status: %s", zakatID, zakat.Status)
	}

	// The current model assumes a single distribution event per Zakat record changes its status to "distributed".
	// If partial distributions were allowed while keeping Zakat "collected", logic would need to track remaining balance.
	// For now, this 'amount' is the amount of *this* distribution.
	// We should ensure this distribution amount does not exceed the original Zakat amount.
	if amount > zakat.Amount {
		return fmt.Errorf("distribution amount %.2f exceeds original zakat amount %.2f for Zakat ID %s", amount, zakat.Amount, zakatID)
	}
	// If there were previous distributions on this Zakat (not current model), this check would be more complex.

	// Update Zakat details for distribution
	zakat.Status = "distributed" // Mark as fully distributed by this action
	zakat.Mustahik = recipientName
	zakat.Distribution = amount // Record the amount that was distributed in this event
	zakat.DistributedAt = distributionTimestamp
	zakat.DistributionID = distributionID
	zakat.DistributedBy = distributedBy

	// Update program distributed amount if ProgramID is present
	if zakat.ProgramID != "" {
		program, err := s.GetProgram(ctx, zakat.ProgramID)
		if err != nil {
			return fmt.Errorf("failed to get program %s for Zakat %s distribution update: %w", zakat.ProgramID, zakatID, err)
		}
		program.Distributed += amount // Add this distribution's amount to program's total distributed
		programJSON, err := json.Marshal(program)
		if err != nil {
			return fmt.Errorf("failed to marshal updated program %s after distribution: %w", zakat.ProgramID, err)
		}
		err = ctx.GetStub().PutState(program.ID, programJSON)
		if err != nil {
			return fmt.Errorf("failed to put updated program %s to state after distribution: %w", program.ID, err)
		}
		fmt.Printf("Successfully updated program %s distributed amount.\n", program.ID)
	}

	zakatJSON, err := json.Marshal(zakat)
	if err != nil {
		return fmt.Errorf("failed to marshal updated zakat %s for distribution: %w", zakatID, err)
	}

	err = ctx.GetStub().PutState(zakatID, zakatJSON)
	if err != nil {
		return fmt.Errorf("failed to put updated zakat %s to state after distribution: %w", zakatID, err)
	}
	fmt.Printf("Successfully distributed Zakat: %s (Distribution ID: %s) to Recipient: %s, Amount: %.2f by %s\n", zakatID, distributionID, recipientName, amount, distributedBy)
	return nil
}

// ZakatExists checks if zakat exists
func (s *SmartContract) ZakatExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	zakatJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}
	return zakatJSON != nil, nil
}

// REPORTING FUNCTIONS

// GetDailyReport generates daily donation report
func (s *SmartContract) GetDailyReport(ctx contractapi.TransactionContextInterface, date string) (map[string]interface{}, error) {
	targetDate, err := time.Parse("2006-01-02", date)
	if err != nil {
		return nil, fmt.Errorf("invalid date format for report. Please use YYYY-MM-DD: %w", err)
	}

	startOfDayRFC3339 := targetDate.Format(time.RFC3339)
	nextDay := targetDate.Add(24 * time.Hour)
	startOfNextDayRFC3339 := nextDay.Format(time.RFC3339)

	queryString := fmt.Sprintf(`{
"selector": {
"validationDate": {
"$gte": "%s",
"$lt": "%s"
},
"status": "collected"
}
}`, startOfDayRFC3339, startOfNextDayRFC3339)
	fmt.Printf("GetDailyReport query: %s\n", queryString)

	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to query daily report: %v", err)
	}
	defer resultsIterator.Close()

	var totalAmount float64
	var transactionCount int
	var byType = make(map[string]float64)
	var byProgram = make(map[string]float64) // Keyed by ProgramID, value is sum of amounts

	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var zakat Zakat
		err = json.Unmarshal(queryResponse.Value, &zakat)
		if err != nil {
			return nil, err
		}

		// Ensure only "collected" Zakat transactions are processed, though query should handle this.
		// This is an additional safeguard or for logic if query was broader.
		if zakat.Status == "collected" {
			totalAmount += zakat.Amount
			transactionCount++
			byType[zakat.Type] += zakat.Amount
			if zakat.ProgramID != "" {
				byProgram[zakat.ProgramID] += zakat.Amount
			} else {
				byProgram["<No Program>"] += zakat.Amount // Group Zakat not tied to a program
			}
		}
	}

	report := map[string]interface{}{
		"date":             date,
		"totalAmount":      totalAmount,
		"transactionCount": transactionCount,
		"byType":           byType,
		"byProgram":        byProgram,
	}

	return report, nil
}

// ClearAllZakat removes all Zakat records from the ledger
func (s *SmartContract) ClearAllZakat(ctx contractapi.TransactionContextInterface) error {
	resultsIterator, err := ctx.GetStub().GetStateByRange("ZKT-", "ZKT-\uffff")
	if err != nil {
		return fmt.Errorf("failed to get Zakat records for deletion: %w", err)
	}
	defer resultsIterator.Close()

	deletedCount := 0
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return fmt.Errorf("failed to iterate Zakat records for deletion: %w", err)
		}

		err = ctx.GetStub().DelState(queryResponse.Key)
		if err != nil {
			return fmt.Errorf("failed to delete Zakat record %s: %w", queryResponse.Key, err)
		}
		deletedCount++
	}

	fmt.Printf("Successfully deleted %d Zakat records\n", deletedCount)
	return nil
}

// ClearAllPrograms removes all DonationProgram records from the ledger
func (s *SmartContract) ClearAllPrograms(ctx contractapi.TransactionContextInterface) error {
	resultsIterator, err := ctx.GetStub().GetStateByRange("PROG-", "PROG-\uffff")
	if err != nil {
		return fmt.Errorf("failed to get Program records for deletion: %w", err)
	}
	defer resultsIterator.Close()

	deletedCount := 0
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return fmt.Errorf("failed to iterate Program records for deletion: %w", err)
		}

		err = ctx.GetStub().DelState(queryResponse.Key)
		if err != nil {
			return fmt.Errorf("failed to delete Program record %s: %w", queryResponse.Key, err)
		}
		deletedCount++
	}

	fmt.Printf("Successfully deleted %d Program records\n", deletedCount)
	return nil
}

// ClearAllOfficers removes all Officer records from the ledger
func (s *SmartContract) ClearAllOfficers(ctx contractapi.TransactionContextInterface) error {
	resultsIterator, err := ctx.GetStub().GetStateByRange("OFF-", "OFF-\uffff")
	if err != nil {
		return fmt.Errorf("failed to get Officer records for deletion: %w", err)
	}
	defer resultsIterator.Close()

	deletedCount := 0
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return fmt.Errorf("failed to iterate Officer records for deletion: %w", err)
		}

		err = ctx.GetStub().DelState(queryResponse.Key)
		if err != nil {
			return fmt.Errorf("failed to delete Officer record %s: %w", queryResponse.Key, err)
		}
		deletedCount++
	}

	fmt.Printf("Successfully deleted %d Officer records\n", deletedCount)
	return nil
}

// GetAllOfficers returns all officer records
func (s *SmartContract) GetAllOfficers(ctx contractapi.TransactionContextInterface) ([]Officer, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("OFF-", "OFF-\uffff")
	if err != nil {
		return []Officer{}, err
	}
	defer resultsIterator.Close()

	var officers []Officer
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return []Officer{}, err
		}

		var officer Officer
		err = json.Unmarshal(queryResponse.Value, &officer)
		if err != nil {
			return []Officer{}, err
		}
		officers = append(officers, officer)
	}

	if officers == nil {
		officers = []Officer{}
	}
	return officers, nil
}

// UpdateProgramStatus updates the status of a donation program
func (s *SmartContract) UpdateProgramStatus(ctx contractapi.TransactionContextInterface, programID string, newStatus string) error {
	if err := validateProgramStatus(newStatus); err != nil {
		return err
	}

	program, err := s.GetProgram(ctx, programID)
	if err != nil {
		return fmt.Errorf("failed to get program %s: %w", programID, err)
	}

	program.Status = newStatus
	programJSON, err := json.Marshal(program)
	if err != nil {
		return fmt.Errorf("failed to marshal updated program: %w", err)
	}

	err = ctx.GetStub().PutState(programID, programJSON)
	if err != nil {
		return fmt.Errorf("failed to update program status: %w", err)
	}

	fmt.Printf("Successfully updated program %s status to %s\n", programID, newStatus)
	return nil
}

// UpdateOfficerStatus updates the status of an officer
func (s *SmartContract) UpdateOfficerStatus(ctx contractapi.TransactionContextInterface, officerID string, newStatus string) error {
	if err := validateOfficerStatus(newStatus); err != nil {
		return err
	}

	officerJSON, err := ctx.GetStub().GetState(officerID)
	if err != nil {
		return fmt.Errorf("failed to read officer: %v", err)
	}
	if officerJSON == nil {
		return fmt.Errorf("officer %s does not exist", officerID)
	}

	var officer Officer
	err = json.Unmarshal(officerJSON, &officer)
	if err != nil {
		return fmt.Errorf("failed to unmarshal officer: %v", err)
	}

	officer.Status = newStatus
	updatedOfficerJSON, err := json.Marshal(officer)
	if err != nil {
		return fmt.Errorf("failed to marshal updated officer: %w", err)
	}

	err = ctx.GetStub().PutState(officerID, updatedOfficerJSON)
	if err != nil {
		return fmt.Errorf("failed to update officer status: %w", err)
	}

	fmt.Printf("Successfully updated officer %s status to %s\n", officerID, newStatus)
	return nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		fmt.Printf("Error creating zakat chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting zakat chaincode: %s", err.Error())
	}
}
