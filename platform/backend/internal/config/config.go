package config

import (
	"os"
	"strconv"
	"time"
)

// Config holds all configuration for the application
type Config struct {
	Server      ServerConfig
	Database    DatabaseConfig
	Redis       RedisConfig
	Fabric      FabricConfig
	Email       EmailConfig
	JWT         JWTConfig
	MockPayment MockPaymentConfig
}

// ServerConfig holds server configuration
type ServerConfig struct {
	Port string
	Mode string // development, production
}

// DatabaseConfig holds PostgreSQL configuration
type DatabaseConfig struct {
	Host     string
	Port     string
	Name     string
	User     string
	Password string
	SSLMode  string
}

// RedisConfig holds Redis configuration
type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

// FabricConfig holds Hyperledger Fabric configuration
type FabricConfig struct {
	ConfigPath string
	WalletPath string
	Channel    string
	Chaincode  string
	UserID     string
	OrgName    string
}

// EmailConfig holds SMTP configuration
type EmailConfig struct {
	SMTPHost  string
	SMTPPort  int
	Username  string
	Password  string
	FromName  string
	FromEmail string
}

// JWTConfig holds JWT configuration
type JWTConfig struct {
	Secret string
	Expiry time.Duration
}

// MockPaymentConfig holds mock payment system configuration
type MockPaymentConfig struct {
	Delay time.Duration
}

// Load loads configuration from environment variables
func Load() *Config {
	return &Config{
		Server: ServerConfig{
			Port: getEnv("PORT", "3002"),
			Mode: getEnv("GIN_MODE", "development"),
		},
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			Name:     getEnv("DB_NAME", "zakatplatform"),
			User:     getEnv("DB_USER", "zakat"),
			Password: getEnv("DB_PASSWORD", "secure_password"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       0,
		},
		Fabric: FabricConfig{
			ConfigPath: getEnv("FABRIC_CONFIG_PATH", "../config"),
			WalletPath: getEnv("FABRIC_WALLET_PATH", "./wallet"),
			Channel:    getEnv("FABRIC_CHANNEL", "zakatchannel"),
			Chaincode:  getEnv("FABRIC_CHAINCODE", "zakat"),
			UserID:     getEnv("FABRIC_USER", "appUserOrg1"),
			OrgName:    getEnv("FABRIC_ORG_NAME", "Org1"),
		},
		Email: EmailConfig{
			SMTPHost:  getEnv("EMAIL_SMTP_HOST", "smtp.gmail.com"),
			SMTPPort:  getEnvAsInt("EMAIL_SMTP_PORT", 587),
			Username:  getEnv("EMAIL_USERNAME", ""),
			Password:  getEnv("EMAIL_PASSWORD", ""),
			FromName:  getEnv("EMAIL_FROM_NAME", "Zakat Platform"),
			FromEmail: getEnv("EMAIL_FROM_EMAIL", "noreply@zakatplatform.org"),
		},
		JWT: JWTConfig{
			Secret: getEnv("JWT_SECRET", "your-secret-key-change-in-production"),
			Expiry: getEnvAsDuration("JWT_EXPIRY", "720h"), // 30 days
		},
		MockPayment: MockPaymentConfig{
			Delay: getEnvAsDuration("MOCK_PAYMENT_DELAY", "30s"),
		},
	}
}

// Helper functions for environment variable parsing
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getEnvAsDuration(key string, defaultValue string) time.Duration {
	if value := os.Getenv(key); value != "" {
		if duration, err := time.ParseDuration(value); err == nil {
			return duration
		}
	}
	if duration, err := time.ParseDuration(defaultValue); err == nil {
		return duration
	}
	return 30 * time.Second // fallback
}

// GetDSN returns PostgreSQL connection string
func (d DatabaseConfig) GetDSN() string {
	return "host=" + d.Host +
		" port=" + d.Port +
		" user=" + d.User +
		" password=" + d.Password +
		" dbname=" + d.Name +
		" sslmode=" + d.SSLMode
}

// GetRedisAddr returns Redis address
func (r RedisConfig) GetRedisAddr() string {
	return r.Host + ":" + r.Port
}
