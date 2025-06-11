package services

import (
	"database/sql"
	"fmt"

	"github.com/go-redis/redis/v8"
	"github.com/google/uuid"
	"github.com/izzuddinafif/fabric/platform/backend/internal/models"
	"golang.org/x/crypto/bcrypt"
)

// UserService handles user operations
type UserService struct {
	db    *sql.DB
	redis *redis.Client
}

// NewUserService creates a new user service
func NewUserService(db *sql.DB, redis *redis.Client) *UserService {
	return &UserService{
		db:    db,
		redis: redis,
	}
}

// AuthenticateAdmin authenticates an admin user
func (s *UserService) AuthenticateAdmin(phone, password string) (*models.User, error) {
	query := `SELECT id, phone, email, name, role, referral_code, organization, hashed_password, created_at, updated_at
			  FROM users WHERE phone = $1 AND role IN ('officer', 'org_admin', 'super_admin')`

	user := &models.User{}
	var hashedPassword string

	err := s.db.QueryRow(query, phone).Scan(
		&user.ID, &user.Phone, &user.Email, &user.Name, &user.Role,
		&user.ReferralCode, &user.Organization, &hashedPassword,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("invalid credentials")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password)); err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	return user, nil
}

// GetUserByID retrieves a user by ID
func (s *UserService) GetUserByID(id uuid.UUID) (*models.User, error) {
	query := `SELECT id, phone, email, name, role, referral_code, organization, created_at, updated_at
			  FROM users WHERE id = $1`

	user := &models.User{}
	err := s.db.QueryRow(query, id).Scan(
		&user.ID, &user.Phone, &user.Email, &user.Name, &user.Role,
		&user.ReferralCode, &user.Organization, &user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("user not found")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return user, nil
}

// CreateUser creates a new user
func (s *UserService) CreateUser(user *models.User, password string) error {
	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Generate UUID if not provided
	if user.ID == uuid.Nil {
		user.ID = uuid.New()
	}

	query := `INSERT INTO users (id, phone, email, name, role, referral_code, organization, hashed_password, created_at, updated_at)
			  VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`

	_, err = s.db.Exec(query, user.ID, user.Phone, user.Email, user.Name, user.Role,
		user.ReferralCode, user.Organization, hashedPassword, user.CreatedAt, user.UpdatedAt)

	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}

	return nil
}
