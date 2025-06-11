package models

import (
"database/sql"
"time"

"github.com/google/uuid"
)

// Custom nullable types for GORM compatibility
type NullString struct {
String string
Valid  bool
}

type NullTime struct {
Time  time.Time
Valid bool
}

type NullUUID struct {
UUID  uuid.UUID
Valid bool
}

type NullFloat64 struct {
Float64 float64
Valid   bool
}

// User represents a user in the system
type User struct {
	ID             uuid.UUID      `json:"id"`
	Phone          string         `json:"phone"`
	Email          sql.NullString `json:"email"`
	Name           string         `json:"name"`
	Role           string         `json:"role"` // donor, officer, org_admin, super_admin
	ReferralCode   sql.NullString `json:"referral_code"`
	Organization   sql.NullString `json:"organization"`
	PasswordHash   string         `json:"-"` // Not exposed in API
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
}

// Donation represents a zakat donation
type Donation struct {
	ID               string         `json:"id"` // ZKT-YDSF-MLG-202406-0001
	DonorID          uuid.NullUUID  `json:"donor_id"`
	DonorName        string         `json:"donor_name"`
	DonorPhone       string         `json:"donor_phone"`
	DonorEmail       sql.NullString `json:"donor_email"`
	Amount           float64        `json:"amount"`
	Type             string         `json:"type"` // fitrah, maal
	ProgramID        sql.NullString `json:"program_id"`
	ReferralCode     sql.NullString `json:"referral_code"`
	BlockchainStatus string         `json:"blockchain_status"` // pending, collected, distributed
	SyncStatus       string         `json:"sync_status"`       // synced, pending_sync, error
	PaymentReference sql.NullString `json:"payment_reference"`
	ValidatedAt      sql.NullTime   `json:"validated_at"`
	ValidatedBy      sql.NullString `json:"validated_by"`
	DistributedAt    sql.NullTime   `json:"distributed_at"`
	DistributedBy    sql.NullString `json:"distributed_by"`
	BlockchainTxID   sql.NullString `json:"blockchain_tx_id"`
	CreatedAt        time.Time      `json:"created_at"`
	UpdatedAt        time.Time      `json:"updated_at"`
}

// Program represents a zakat program
type Program struct {
	ID              string          `json:"id"`
	Name            string          `json:"name"`
	Description     sql.NullString  `json:"description"`
	Organization    string          `json:"organization"`
	TargetAmount    sql.NullFloat64 `json:"target_amount"`
	CollectedAmount float64         `json:"collected_amount"`
	IsActive        bool            `json:"is_active"`
	CreatedAt       time.Time       `json:"created_at"`
}

// Distribution represents a zakat distribution
type Distribution struct {
	ID               string         `json:"id"`
	DonationID       string         `json:"donation_id"`
	RecipientName    string         `json:"recipient_name"`
	RecipientDetails sql.NullString `json:"recipient_details"` // JSONB
	Amount           float64        `json:"amount"`
	DistributionDate sql.NullTime   `json:"distribution_date"`
	DistributedBy    sql.NullString `json:"distributed_by"`
	BlockchainTxID   sql.NullString `json:"blockchain_tx_id"`
	CreatedAt        time.Time      `json:"created_at"`
}

// AuditLog represents an audit log entry
type AuditLog struct {
	ID          uuid.UUID `json:"id"`
	EntityType  string    `json:"entity_type"`
	EntityID    string    `json:"entity_id"`
	Action      string    `json:"action"`
	PerformedBy string    `json:"performed_by"` // User ID or system
	Details     string    `json:"details"`      // JSONB
	CreatedAt   time.Time `json:"created_at"`
}

// APIRequest and APIResponse structs for handlers

// CreateDonationRequest for POST /api/donations
type CreateDonationRequest struct {
	Name         string  `json:"name" binding:"required"`
	Phone        string  `json:"phone" binding:"required"`
	Email        string  `json:"email"`
	Amount       float64 `json:"amount" binding:"required,gt=0"`
	Type         string  `json:"type" binding:"required,oneof=fitrah maal"`
	ProgramID    string  `json:"program_id"`
	ReferralCode string  `json:"referral_code"`
}

// AdminLoginRequest for POST /api/auth/admin/login
type AdminLoginRequest struct {
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// AdminLoginResponse for POST /api/auth/admin/login
type AdminLoginResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

// DashboardMetrics for GET /api/admin/dashboard
type DashboardMetrics struct {
	PendingDonations      int     `json:"pending_donations"`
	TodaysCollection      float64 `json:"todays_collection"`
	TotalCollected        float64 `json:"total_collected"`
	TotalDistributed      float64 `json:"total_distributed"`
	NetworkHealth         string  `json:"network_health"` // healthy, warning, error
	BlockchainHeight      uint64  `json:"blockchain_height"`
	ChaincodeInstantiated bool    `json:"chaincode_instantiated"`
}

// RecentActivity for GET /api/admin/dashboard
type RecentActivity struct {
	Type      string    `json:"type"` // donation, validation, distribution, system
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
}

// DashboardResponse for GET /api/admin/dashboard
type DashboardResponse struct {
	Metrics        DashboardMetrics `json:"metrics"`
	RecentActivity []RecentActivity `json:"recent_activity"`
}
