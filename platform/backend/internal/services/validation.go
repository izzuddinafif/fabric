package services

import (
"fmt"
"log"
"time"

"github.com/hyperledger/fabric-sdk-go/pkg/gateway"
"gorm.io/gorm"
)

// ValidationService handles auto-validation of donations
type ValidationService struct {
fabricContract *gateway.Contract
db             *gorm.DB
emailService   *EmailService
delayDuration  time.Duration
}

// NewValidationService creates a new validation service
func NewValidationService(fabricContract *gateway.Contract, db *gorm.DB, emailService *EmailService, delay time.Duration) *ValidationService {
return &ValidationService{
fabricContract: fabricContract,
db:             db,
emailService:   emailService,
delayDuration:  delay,
}
}

// ScheduleAutoValidation schedules automatic validation for a donation after the configured delay
func (vs *ValidationService) ScheduleAutoValidation(donationID string) {
log.Printf("🕒 Scheduling auto-validation for donation %s in %v", donationID, vs.delayDuration)

go func() {
// Wait for the mock payment delay
time.Sleep(vs.delayDuration)

log.Printf("⚡ Starting auto-validation for donation %s", donationID)

// Call the chaincode AutoValidatePayment function
paymentRef := fmt.Sprintf("MOCK-PAYMENT-%d", time.Now().UnixNano())
_, err := vs.fabricContract.SubmitTransaction("AutoValidatePayment", donationID, paymentRef)
if err != nil {
log.Printf("❌ Failed to auto-validate donation %s: %v", donationID, err)
return
}

log.Printf("✅ Successfully auto-validated donation %s", donationID)

// Send validation confirmation email
vs.sendValidationEmail(donationID)
}()
}

// sendValidationEmail sends email notification after successful validation
func (vs *ValidationService) sendValidationEmail(donationID string) {
	if vs.emailService == nil {
		log.Printf("📧 Email service not configured, skipping validation email for donation %s", donationID)
		return
	}

	// Query donation details from database to get donor email and amount
	donation, err := vs.getDonationFromDB(donationID)
	if err != nil {
		log.Printf("❌ Failed to get donation details for email notification: %v", err)
		return
	}

	// Skip if no email provided
	if !donation.DonorEmail.Valid || donation.DonorEmail.String == "" {
		log.Printf("📧 No email address for donation %s, skipping validation email", donationID)
		return
	}

	// Generate receipt number (mock)
	receiptNumber := fmt.Sprintf("MOCK-PAYMENT-REF-%d", time.Now().UnixNano())

// Send validation email
err = vs.emailService.SendDonationValidatedEmail(
donation.DonorEmail.String,
"Donor", // We don't have donor name in this simplified struct
donationID,
donation.Amount,
)
	if err != nil {
		log.Printf("❌ Failed to send validation email for donation %s: %v", donationID, err)
	} else {
		log.Printf("✅ Validation email sent successfully for donation %s", donationID)
	}
}

// getDonationFromDB retrieves donation details from PostgreSQL database
func (vs *ValidationService) getDonationFromDB(donationID string) (*Donation, error) {
	var donation Donation
	err := vs.db.Where("id = ?", donationID).First(&donation).Error
	if err != nil {
		return nil, fmt.Errorf("failed to find donation %s in database: %w", donationID, err)
	}
	return &donation, nil
}

// Donation represents the database model (should match models.Donation)
// This is a simplified version for email purposes
type Donation struct {
	ID         string `gorm:"primaryKey"`
	DonorEmail struct {
		String string
		Valid  bool
	} `gorm:"column:donor_email"`
	Amount float64 `gorm:"column:amount"`
}

// ManualValidation allows admin to manually validate a donation
func (vs *ValidationService) ManualValidation(donationID string, receiptNumber string, validatedBy string) error {
	log.Printf("🔐 Manual validation requested for donation %s by %s", donationID, validatedBy)

	_, err := vs.fabricContract.SubmitTransaction("ValidatePayment", donationID, receiptNumber, validatedBy)
	if err != nil {
		return fmt.Errorf("failed to manually validate donation %s: %w", donationID, err)
	}

	log.Printf("✅ Successfully manually validated donation %s", donationID)

	// Send validation email
	vs.sendValidationEmail(donationID)

	return nil
}

// GetValidationStatus checks if a donation has been validated
func (vs *ValidationService) GetValidationStatus(donationID string) (bool, error) {
	// Query the chaincode to get current status
	result, err := vs.fabricContract.EvaluateTransaction("QueryZakat", donationID)
	if err != nil {
		return false, fmt.Errorf("failed to query zakat status: %w", err)
	}

	// In a real implementation, you would parse the JSON result to check status
	// For now, we'll assume if no error, the donation exists and may be validated
	return len(result) > 0, nil
}
