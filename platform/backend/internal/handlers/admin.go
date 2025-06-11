package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/izzuddinafif/fabric/platform/backend/internal/models"
	"github.com/izzuddinafif/fabric/platform/backend/internal/services"
)

// AdminHandler handles admin endpoints
type AdminHandler struct {
	donationService *services.DonationService
	userService     *services.UserService
}

// NewAdminHandler creates a new admin handler
func NewAdminHandler(donationService *services.DonationService, userService *services.UserService) *AdminHandler {
	return &AdminHandler{
		donationService: donationService,
		userService:     userService,
	}
}

// GetDashboard handles GET /api/admin/dashboard
func (h *AdminHandler) GetDashboard(c *gin.Context) {
	// This is a simplified dashboard - in a real implementation,
	// you would query the database for actual metrics

	metrics := models.DashboardMetrics{
		PendingDonations:      5,
		TodaysCollection:      1250000.0,
		TotalCollected:        25000000.0,
		TotalDistributed:      20000000.0,
		NetworkHealth:         "healthy",
		BlockchainHeight:      12345,
		ChaincodeInstantiated: true,
	}

	recentActivity := []models.RecentActivity{
		{
			Type:      "donation",
			Message:   "New donation received: Rp 500,000",
			Timestamp: nil, // You would set actual timestamp
		},
		{
			Type:      "validation",
			Message:   "Payment validated for donation ZKT-YDSF-MLG-202406-0001",
			Timestamp: nil,
		},
	}

	response := models.DashboardResponse{
		Metrics:        metrics,
		RecentActivity: recentActivity,
	}

	c.JSON(http.StatusOK, response)
}

// GetDonations handles GET /api/admin/donations
func (h *AdminHandler) GetDonations(c *gin.Context) {
	// Parse pagination parameters
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 || limit > 100 {
		limit = 20
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil || offset < 0 {
		offset = 0
	}

	donations, err := h.donationService.GetDonations(limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get donations"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"donations": donations,
		"pagination": gin.H{
			"limit":  limit,
			"offset": offset,
		},
	})
}

// ValidateDonation handles POST /api/admin/donations/:id/validate
func (h *AdminHandler) ValidateDonation(c *gin.Context) {
	donationID := c.Param("id")
	if donationID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Donation ID is required"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "User ID not found"})
		return
	}

	// For manual validation, we would need additional validation logic
	// This is simplified for the MVP with mock payments
	c.JSON(http.StatusOK, gin.H{
		"message":      "Manual validation not available in MVP - using auto-validation",
		"donation_id":  donationID,
		"validated_by": userID,
	})
}

// DistributeDonation handles POST /api/admin/donations/:id/distribute
func (h *AdminHandler) DistributeDonation(c *gin.Context) {
	donationID := c.Param("id")
	if donationID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Donation ID is required"})
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "User ID not found"})
		return
	}

	// This would implement the distribution logic
	// For MVP, this is simplified
	c.JSON(http.StatusOK, gin.H{
		"message":        "Distribution feature coming in Phase 2",
		"donation_id":    donationID,
		"distributed_by": userID,
	})
}
