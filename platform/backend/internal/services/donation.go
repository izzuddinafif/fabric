package services

import (
"database/sql"
"fmt"
"log"
"time"

"github.com/go-redis/redis/v8"
"github.com/izzuddinafif/fabric/platform/backend/internal/models"
"gorm.io/gorm"
)

// DonationService handles donation business logic
type DonationService struct {
fabricService     *FabricService
db                *gorm.DB
redis             *redis.Client
validationService *ValidationService
emailService      *EmailService
}

// NewDonationService creates a new donation service
func NewDonationService(fabricService *FabricService, db *gorm.DB, redis *redis.Client, validationService *ValidationService) *DonationService {
return &DonationService{
fabricService:     fabricService,
db:                db,
redis:             redis,
validationService: validationService,
}
}

// SetEmailService sets the email service for donation notifications
func (s *DonationService) SetEmailService(emailService *EmailService) {
s.emailService = emailService
}

// CreateDonation creates a new donation
func (s *DonationService) CreateDonation(req models.CreateDonationRequest) (*models.Donation, error) {
log.Printf("🎯 Creating donation for: %s, Amount: %.2f, Type: %s", req.Name, req.Amount, req.Type)

// Submit to blockchain first to get the generated ID
zakatID, err := s.fabricService.AddZakat(
req.Name,
req.Phone,
req.Type,
req.Amount,
req.ProgramID,
req.ReferralCode,
)
if err != nil {
return nil, fmt.Errorf("failed to submit donation to blockchain: %w", err)
}

	// Create donation record in database
	donation := &models.Donation{
		ID:               zakatID,
		DonorName:        req.Name,
		DonorPhone:       req.Phone,
		DonorEmail:       sql.NullString{String: req.Email, Valid: req.Email != ""},
		Amount:           req.Amount,
		Type:             req.Type,
		ProgramID:        sql.NullString{String: req.ProgramID, Valid: req.ProgramID != ""},
		ReferralCode:     sql.NullString{String: req.ReferralCode, Valid: req.ReferralCode != ""},
		BlockchainStatus: "pending",
		SyncStatus:       "synced", // Already synced to blockchain
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}

// Insert into database using GORM
if err := s.db.Create(donation).Error; err != nil {
return nil, fmt.Errorf("failed to insert donation: %w", err)
}

log.Printf("✅ Donation created successfully: %s", zakatID)

// Send submission email
if s.emailService != nil && req.Email != "" {
go func() {
err := s.emailService.SendDonationSubmittedEmail(req.Email, req.Name, zakatID, req.Amount)
if err != nil {
log.Printf("❌ Failed to send submission email for donation %s: %v", zakatID, err)
} else {
log.Printf("📧 Submission email sent for donation %s", zakatID)
}
}()
}

// Schedule auto-validation (mock payment)
go func() {
s.validationService.ScheduleAutoValidation(zakatID)
}()

return donation, nil
}

// GetDonation retrieves a donation by ID
func (s *DonationService) GetDonation(id string) (*models.Donation, error) {
var donation models.Donation
if err := s.db.Where("id = ?", id).First(&donation).Error; err != nil {
if err == gorm.ErrRecordNotFound {
return nil, fmt.Errorf("donation not found")
}
return nil, fmt.Errorf("failed to get donation: %w", err)
}
return &donation, nil
}

// GetDonations retrieves all donations with pagination
func (s *DonationService) GetDonations(limit, offset int) ([]*models.Donation, error) {
var donations []*models.Donation
if err := s.db.Order("created_at DESC").Limit(limit).Offset(offset).Find(&donations).Error; err != nil {
return nil, fmt.Errorf("failed to get donations: %w", err)
}
return donations, nil
}

// GetDonationsByStatus retrieves donations by blockchain status
func (s *DonationService) GetDonationsByStatus(status string) ([]*models.Donation, error) {
var donations []*models.Donation
if err := s.db.Where("blockchain_status = ?", status).Order("created_at DESC").Find(&donations).Error; err != nil {
return nil, fmt.Errorf("failed to get donations by status: %w", err)
}
return donations, nil
}

// ValidateDonation manually validates a donation (admin action)
func (s *DonationService) ValidateDonation(donationID, receiptNumber, validatedBy string) error {
log.Printf("🔐 Manual validation requested for donation %s by %s", donationID, validatedBy)

// Call fabric service to validate payment
err := s.fabricService.ValidatePayment(donationID, receiptNumber, validatedBy)
if err != nil {
return fmt.Errorf("failed to validate payment on blockchain: %w", err)
}

// Update database record
now := time.Now()
err = s.db.Model(&models.Donation{}).Where("id = ?", donationID).Updates(map[string]interface{}{
"blockchain_status":  "collected",
"payment_reference":  models.NullString{String: receiptNumber, Valid: true},
"validated_by":       models.NullString{String: validatedBy, Valid: true},
"validated_at":       models.NullTime{Time: now, Valid: true},
"updated_at":         now,
}).Error

if err != nil {
log.Printf("❌ Failed to update donation record for %s: %v", donationID, err)
return fmt.Errorf("failed to update donation record: %w", err)
}

log.Printf("✅ Successfully validated donation: %s", donationID)
return nil
}

// DistributeDonation distributes a collected donation
func (s *DonationService) DistributeDonation(donationID, recipientName string, amount float64, distributedBy string) error {
log.Printf("🎯 Distribution requested for donation %s to %s", donationID, recipientName)

// Call fabric service to distribute zakat
err := s.fabricService.DistributeZakat(donationID, recipientName, amount, distributedBy)
if err != nil {
return fmt.Errorf("failed to distribute zakat on blockchain: %w", err)
}

// Update database record
now := time.Now()
err = s.db.Model(&models.Donation{}).Where("id = ?", donationID).Updates(map[string]interface{}{
"blockchain_status": "distributed",
"distributed_by":    models.NullString{String: distributedBy, Valid: true},
"distributed_at":    models.NullTime{Time: now, Valid: true},
"updated_at":        now,
}).Error

if err != nil {
log.Printf("❌ Failed to update donation record for distribution %s: %v", donationID, err)
return fmt.Errorf("failed to update donation record: %w", err)
}

log.Printf("✅ Successfully distributed donation: %s", donationID)
return nil
}

// GetDashboardMetrics gets metrics for admin dashboard
func (s *DonationService) GetDashboardMetrics() (*models.DashboardMetrics, error) {
metrics := &models.DashboardMetrics{}

// Count pending donations
var pendingCount int64
s.db.Model(&models.Donation{}).Where("blockchain_status = ?", "pending").Count(&pendingCount)
metrics.PendingDonations = int(pendingCount)

// Calculate today's collection
today := time.Now().Truncate(24 * time.Hour)
var todaySum struct {
Total float64
}
s.db.Model(&models.Donation{}).
Where("blockchain_status = ? AND created_at >= ?", "collected", today).
Select("COALESCE(SUM(amount), 0) as total").
Scan(&todaySum)
metrics.TodaysCollection = todaySum.Total

// Calculate total collected
var totalSum struct {
Total float64
}
s.db.Model(&models.Donation{}).
Where("blockchain_status IN ?", []string{"collected", "distributed"}).
Select("COALESCE(SUM(amount), 0) as total").
Scan(&totalSum)
metrics.TotalCollected = totalSum.Total

// Calculate total distributed
var distributedSum struct {
Total float64
}
s.db.Model(&models.Donation{}).
Where("blockchain_status = ?", "distributed").
Select("COALESCE(SUM(amount), 0) as total").
Scan(&distributedSum)
metrics.TotalDistributed = distributedSum.Total

// Set network health (simplified for MVP)
metrics.NetworkHealth = "healthy"
metrics.ChaincodeInstantiated = true
metrics.BlockchainHeight = uint64(time.Now().Unix()) // Mock value

return metrics, nil
}

// GetRecentActivity gets recent activity for admin dashboard
func (s *DonationService) GetRecentActivity(limit int) ([]models.RecentActivity, error) {
var donations []models.Donation
if err := s.db.Order("created_at DESC").Limit(limit).Find(&donations).Error; err != nil {
return nil, fmt.Errorf("failed to get recent donations: %w", err)
}

var activities []models.RecentActivity
for _, donation := range donations {
var activityType, message string
switch donation.BlockchainStatus {
case "pending":
activityType = "donation"
message = fmt.Sprintf("New donation from %s: Rp %.2f (%s)", donation.DonorName, donation.Amount, donation.Type)
case "collected":
activityType = "validation"
message = fmt.Sprintf("Payment validated for %s: Rp %.2f", donation.DonorName, donation.Amount)
case "distributed":
activityType = "distribution"
message = fmt.Sprintf("Zakat distributed for %s: Rp %.2f", donation.DonorName, donation.Amount)
default:
continue
}

activities = append(activities, models.RecentActivity{
Type:      activityType,
Message:   message,
Timestamp: donation.CreatedAt,
})
}

return activities, nil
}
