package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/izzuddinafif/fabric/platform/backend/internal/models"
	"github.com/izzuddinafif/fabric/platform/backend/internal/services"
)

// AuthHandler handles authentication endpoints
type AuthHandler struct {
	userService *services.UserService
	jwtService  *services.JWTService
	redis       *redis.Client
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler(userService *services.UserService, jwtService *services.JWTService, redis *redis.Client) *AuthHandler {
	return &AuthHandler{
		userService: userService,
		jwtService:  jwtService,
		redis:       redis,
	}
}

// AdminLogin handles admin login
func (h *AuthHandler) AdminLogin(c *gin.Context) {
	var req models.AdminLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Authenticate user
	user, err := h.userService.AuthenticateAdmin(req.Phone, req.Password)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Generate JWT token
	token, err := h.jwtService.GenerateToken(user.ID.String(), user.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	response := models.AdminLoginResponse{
		Token: token,
		User:  *user,
	}

	c.JSON(http.StatusOK, response)
}

// Logout handles user logout
func (h *AuthHandler) Logout(c *gin.Context) {
	// In a stateless JWT system, logout is typically handled client-side
	// Here we could implement token blacklisting if needed
	c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
}
