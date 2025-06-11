package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/izzuddinafif/fabric/platform/backend/internal/models"
	"github.com/izzuddinafif/fabric/platform/backend/internal/services"
)

// DonationHandler handles donation endpoints
type DonationHandler struct {
	donationService *services.DonationService
}

// NewDonationHandler creates a new donation handler
func NewDonationHandler(donationService *services.DonationService) *DonationHandler {
	return &DonationHandler{
		donationService: donationService,
	}
}

// CreateDonation handles POST /api/donations
func (h *DonationHandler) CreateDonation(c *gin.Context) {
	var req models.CreateDonationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	donation, err := h.donationService.CreateDonation(req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create donation"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message":  "Donation created successfully",
		"donation": donation,
	})
}

// GetDonation handles GET /api/donations/:id
func (h *DonationHandler) GetDonation(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Donation ID is required"})
		return
	}

	donation, err := h.donationService.GetDonation(id)
	if err != nil {
		if err.Error() == "donation not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": "Donation not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get donation"})
		return
	}

	c.JSON(http.StatusOK, donation)
}
