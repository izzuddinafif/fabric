package services

import (
	"fmt"
	"time"
)

// IDGeneratorService handles generation of unique IDs for the zakat platform
type IDGeneratorService struct{}

// NewIDGeneratorService creates a new ID generator service
func NewIDGeneratorService() *IDGeneratorService {
	return &IDGeneratorService{}
}

// GenerateZakatID generates a new zakat ID in the format:
// ZKT-YDSF-{MLG|JTM}-{UNIXTIMESTAMPNANO}-{SEQUENCE}
func (g *IDGeneratorService) GenerateZakatID(organization string, sequence int) string {
	// Map organization to org code
	var orgCode string
	switch organization {
	case "YDSF Malang":
		orgCode = "MLG"
	case "YDSF Jatim":
		orgCode = "JTM"
	default:
		orgCode = "MLG" // Default to Malang
	}

	// Generate nanosecond timestamp for uniqueness
	nanoTimestamp := time.Now().UnixNano()

	return fmt.Sprintf("ZKT-YDSF-%s-%d-%04d", orgCode, nanoTimestamp, sequence)
}

// GenerateProgramID generates a new program ID in the format:
// PROG-{TYPE}-{UNIXTIMESTAMPNANO}-{SEQUENCE}
func (g *IDGeneratorService) GenerateProgramID(programType string, sequence int) string {
	nanoTimestamp := time.Now().UnixNano()
	return fmt.Sprintf("PROG-%s-%d-%04d", programType, nanoTimestamp, sequence)
}

// GenerateOfficerID generates a new officer ID in the format:
// OFF-{TYPE}-{UNIXTIMESTAMPNANO}-{SEQUENCE}
func (g *IDGeneratorService) GenerateOfficerID(officerType string, sequence int) string {
	nanoTimestamp := time.Now().UnixNano()
	return fmt.Sprintf("OFF-%s-%d-%04d", officerType, nanoTimestamp, sequence)
}

// GenerateDistributionID generates a new distribution ID in the format:
// DIST-{UNIXTIMESTAMPNANO}-{SEQUENCE}
func (g *IDGeneratorService) GenerateDistributionID(sequence int) string {
	nanoTimestamp := time.Now().UnixNano()
	return fmt.Sprintf("DIST-%d-%04d", nanoTimestamp, sequence)
}

// GetOrganizationFromZakatID extracts organization from a zakat ID
func (g *IDGeneratorService) GetOrganizationFromZakatID(zakatID string) string {
	// Parse ZKT-YDSF-{MLG|JTM}-{TIMESTAMP}-{SEQUENCE}
	if len(zakatID) >= 12 {
		orgCode := zakatID[9:12] // Extract MLG or JTM
		switch orgCode {
		case "MLG":
			return "YDSF Malang"
		case "JTM":
			return "YDSF Jatim"
		}
	}
	return "YDSF Malang" // Default
}

// GetSequenceFromID extracts the sequence number from any ID
func (g *IDGeneratorService) GetSequenceFromID(id string) int {
	// IDs end with -SEQUENCE format, extract last 4 digits
	if len(id) >= 4 {
		var sequence int
		fmt.Sscanf(id[len(id)-4:], "%04d", &sequence)
		return sequence
	}
	return 1 // Default sequence
}
