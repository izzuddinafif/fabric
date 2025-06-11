package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/izzuddinafif/fabric/platform/backend/internal/config"
	"github.com/izzuddinafif/fabric/platform/backend/internal/handlers"
	"github.com/izzuddinafif/fabric/platform/backend/internal/middleware"
	"github.com/izzuddinafif/fabric/platform/backend/internal/services"
	"github.com/izzuddinafif/fabric/platform/backend/pkg/database"
	"github.com/izzuddinafif/fabric/platform/backend/pkg/fabric"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	// Load configuration
	cfg := config.Load()

	// Initialize database connections
	log.Println("Connecting to PostgreSQL...")
	db := database.Connect(cfg.Database)
	defer database.Close()

	log.Println("Connecting to Redis...")
	redis := database.ConnectRedis(cfg.Redis)
	defer database.CloseRedis()

// Initialize Fabric client
log.Println("Connecting to Fabric network...")
fabricGateway := fabric.NewClient(fabric.FabricConfig{
ConfigPath: cfg.Fabric.ConfigPath,
WalletPath: cfg.Fabric.WalletPath,
Channel:    cfg.Fabric.Channel,
Chaincode:  cfg.Fabric.Chaincode,
User:       cfg.Fabric.UserID,
})
defer fabric.Close()

// Get Fabric contract
fabricContract := fabric.GetContract(fabric.FabricConfig{
ConfigPath: cfg.Fabric.ConfigPath,
WalletPath: cfg.Fabric.WalletPath,
Channel:    cfg.Fabric.Channel,
Chaincode:  cfg.Fabric.Chaincode,
User:       cfg.Fabric.UserID,
})

// Initialize services
emailService := services.NewEmailService(cfg.Email)
jwtService := services.NewJWTService(cfg.JWT.Secret, cfg.JWT.Expiry)
fabricService := services.NewFabricService(fabricContract)
validationService := services.NewValidationService(fabricContract, db, emailService, cfg.MockPayment.Delay)
donationService := services.NewDonationService(fabricService, db, redis, validationService)
donationService.SetEmailService(emailService) // Set email service for donation notifications
userService := services.NewUserService(db, redis)


	// Initialize handlers
	authHandler := handlers.NewAuthHandler(userService, jwtService, redis)
	donationHandler := handlers.NewDonationHandler(donationService)
	adminHandler := handlers.NewAdminHandler(donationService, userService, db)

	// Set up Gin router
	if cfg.Server.Mode == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.Default()

	// Global middleware
	r.Use(middleware.CORS())
	r.Use(middleware.Logger())
	r.Use(middleware.ErrorHandler())

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "healthy",
			"service": "zakat-platform-backend",
			"version": "1.0.0",
		})
	})

	r.GET("/ready", func(c *gin.Context) {
		// Check database connectivity
		sqlDB, err := db.DB()
		if err != nil || sqlDB.Ping() != nil {
			c.JSON(503, gin.H{"status": "not ready", "error": "database unavailable"})
			return
		}

		// Check Redis connectivity
		if err := redis.Ping(database.Ctx).Err(); err != nil {
			c.JSON(503, gin.H{"status": "not ready", "error": "redis unavailable"})
			return
		}

		c.JSON(200, gin.H{"status": "ready"})
	})

	// API routes
	api := r.Group("/api")
	{
		// Public donation endpoints
		api.POST("/donations", donationHandler.CreateDonation)
		api.GET("/donations/:id", donationHandler.GetDonation)

		// Authentication endpoints
		auth := api.Group("/auth")
		{
			auth.POST("/admin/login", authHandler.AdminLogin)
			auth.POST("/logout", middleware.AuthRequired(jwtService), authHandler.Logout)
		}

		// Admin endpoints (protected)
		admin := api.Group("/admin")
		admin.Use(middleware.AuthRequired(jwtService))
		admin.Use(middleware.AdminRequired())
		{
			admin.GET("/dashboard", adminHandler.GetDashboard)
			admin.GET("/donations", adminHandler.GetDonations)
			admin.POST("/donations/:id/validate", adminHandler.ValidateDonation)
			admin.POST("/donations/:id/distribute", adminHandler.DistributeDonation)
		}
	}

	// Start server
	port := cfg.Server.Port
	if port == "" {
		port = "3002"
	}

	log.Printf("🚀 Zakat Platform Backend starting on port %s", port)
	log.Printf("📊 Mock payment validation delay: %s", cfg.MockPayment.Delay)
	log.Printf("🔗 Fabric channel: %s", cfg.Fabric.Channel)
	log.Printf("📦 Fabric chaincode: %s", cfg.Fabric.Chaincode)

	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
