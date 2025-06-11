# Zakat Chaincode v2.0

## Overview
This Hyperledger Fabric chaincode (v2.0) manages Zakat transactions, donation programs, and officer referral tracking for YDSF Malang and YDSF Jatim organizations. It provides a transparent and immutable record of Zakat collection, validation, and distribution with comprehensive business process support.

## Version 2.0 - Major Architecture Upgrade
This represents a **complete architectural overhaul** from the simple v1.0 implementation. Version 2.0 introduces a comprehensive donation management system with enterprise-grade features:

### Key Improvements from v1.0:
- **Multi-Entity Architecture**: Expanded from single Zakat entity to three interconnected entities (Zakat, DonationProgram, Officer)
- **Payment Workflow**: Implemented 3-stage status workflow (pending → collected → distributed) vs simple 2-stage in v1.0
- **Program Management**: Added complete donation campaign/program tracking (not present in v1.0)
- **Officer Referral System**: New referral tracking with commission calculations (not present in v1.0) 
- **Admin Validation**: Payment validation workflow requiring admin approval (auto-collected in v1.0)
- **Advanced Querying**: 8 query functions vs 2 in v1.0 (by status, program, officer, muzakki, etc.)
- **Comprehensive Reporting**: Daily reporting with analytics (not present in v1.0)
- **Enhanced Data Model**: 16 fields per Zakat vs 9 in v1.0, with optional field optimization
- **Production-Ready Validation**: Extensive input validation and business rule enforcement
- **Automatic Updates**: Program and officer totals auto-update on payment validation

## Features

### Core Business Features
- **Three-Stage Donation Workflow**: pending → collected → distributed (vs 2-stage in v1.0)
- **Donation Program Management**: Create and track donation campaigns with targets and progress
- **Officer Referral System**: Track officer referrals with automatic commission calculations
- **Payment Validation Workflow**: Admin-controlled payment validation process
- **Comprehensive Distribution Tracking**: Record detailed distribution information with recipient tracking
- **Multi-Organization Support**: Handle YDSF Malang and YDSF Jatim operations

### Technical Features
- **Advanced Querying**: Filter by status, program, officer, donor name, and date ranges
- **Automated Calculations**: Auto-update program collected amounts and officer referral totals
- **Receipt Management**: Track receipt numbers and validation timestamps
- **Daily Reporting**: Generate comprehensive daily donation reports with analytics
- **Data Integrity**: Extensive validation rules and business logic enforcement
- **Schema Optimization**: JSON field optimization with `omitempty` tags for optional fields

## Requirements
- Hyperledger Fabric 2.4.0+
- Go 1.20+
- CouchDB (for rich queries)

## Data Models

### Zakat Transaction
```go
type Zakat struct {
    ID              string  `json:"ID"`                           // Format: ZKT-YDSF-{ORG}-{YYYY}{MM}-{COUNTER}
    ProgramID       string  `json:"programID,omitempty"`          // Which donation program (optional)
    Muzakki         string  `json:"muzakki"`                      // Donor's name
    Amount          float64 `json:"amount"`                       // Amount in IDR
    Type            string  `json:"type"`                         // "fitrah" or "maal"
    PaymentMethod   string  `json:"paymentMethod"`                // Payment method used
    Status          string  `json:"status"`                       // "pending", "collected", "distributed"
    Organization    string  `json:"organization"`                 // Collecting organization
    ReferralCode    string  `json:"referralCode,omitempty"`       // Officer's referral code (optional)
    ReceiptNumber   string  `json:"receiptNumber"`                // Receipt/invoice number (populated after validation)
    Timestamp       string  `json:"timestamp"`                    // When donation was submitted
    ValidatedBy     string  `json:"validatedBy"`                  // Admin who validated (populated after validation)
    ValidationDate  string  `json:"validationDate"`               // When payment was validated (populated after validation)
    Mustahik        string  `json:"mustahik"`                     // Recipient's name (populated after distribution)
    Distribution    float64 `json:"distribution"`                 // Distributed amount (populated after distribution)
    DistributedAt   string  `json:"distributedAt"`                // Distribution timestamp (populated after distribution)
    DistributionID  string  `json:"distributionID"`               // Unique ID for the distribution event
    DistributedBy   string  `json:"distributedBy"`                // Admin/Officer who performed the distribution
}
```

### Donation Program
```go
type DonationProgram struct {
    ID          string  `json:"ID"`          // Format: PROG-YYYY-NNNN
    Name        string  `json:"name"`        // Program name
    Description string  `json:"description"` // Program description
    Target      float64 `json:"target"`      // Target amount
    Collected   float64 `json:"collected"`   // Amount collected so far
    Distributed float64 `json:"distributed"` // Amount distributed so far from this program
    StartDate   string  `json:"startDate"`   // Program start date
    EndDate     string  `json:"endDate"`     // Program end date
    Status      string  `json:"status"`      // "active", "completed", "suspended"
    CreatedBy   string  `json:"createdBy"`   // Admin who created the program
    CreatedAt   string  `json:"createdAt"`   // Creation timestamp
}
```

### Officer
```go
type Officer struct {
    ID             string  `json:"ID"`             // Format: OFF-YYYY-NNNN
    Name           string  `json:"name"`           // Officer name
    ReferralCode   string  `json:"referralCode"`   // Unique referral code
    TotalReferred  float64 `json:"totalReferred"`  // Total amount from referrals
    CommissionRate float64 `json:"commissionRate"` // Commission percentage
    Status         string  `json:"status"`         // "active", "inactive"
    CreatedAt      string  `json:"createdAt"`      // Registration timestamp
}
```

## ID Formats

### Zakat Transaction ID
- Format: `ZKT-YDSF-{ORG}-{YYYY}{MM}-{COUNTER}`
- Example: `ZKT-YDSF-MLG-202311-0001`
- Components:
  - `ZKT`: Fixed prefix for Zakat transactions
  - `YDSF`: Organization family identifier
  - `ORG`: Branch identifier (MLG for Malang, JTM for Jatim)
  - `YYYY`: 4-digit year
  - `MM`: 2-digit month
  - `COUNTER`: 4-digit sequential counter

### Program ID
- Format: `PROG-{YYYY}-{COUNTER}`
- Example: `PROG-2024-0001`

### Officer ID
- Format: `OFF-{YYYY}-{COUNTER}`
- Example: `OFF-2024-0001`

## Status Workflow

### Payment Processing Workflow (New in v2.0)
The chaincode implements a comprehensive 3-stage status workflow, compared to the simple 2-stage workflow in v1.0:

1. **Pending**: Initial status when donation is submitted via `AddZakat()`
   - Donation recorded but payment not yet validated
   - No updates to program or officer totals
   
2. **Collected**: After admin validates payment via `ValidatePayment()`
   - Payment confirmed and receipt recorded
   - Program `collected` amount automatically updated
   - Officer `totalReferred` amount automatically updated
   - Donation becomes eligible for distribution
   
3. **Distributed**: After funds are distributed via `DistributeZakat()`
   - Distribution details recorded (recipient, amount, distribution ID)
   - Program `distributed` amount automatically updated
   - Complete audit trail maintained

**Note**: v1.0 had only "collected" and "distributed" states with immediate collection upon creation.

## Chaincode Functions

### Initialization
#### `InitLedger()`
- **Description**: Initializes the ledger with sample data if it hasn't been initialized yet. This function is idempotent.
- **Behavior**:
  - Checks for the existence of a sample program (ID: `PROG-2024-0001`).
  - If the sample program exists, `InitLedger` logs a message indicating that initialization is skipped and returns `nil`.
  - If the sample program does not exist, it creates the following:
    - A sample `DonationProgram`:
      - ID: `PROG-2024-0001`
      - Name: "Bantuan Pendidikan Anak Yatim"
      - Description: "Program bantuan pendidikan untuk anak-anak yatim yang membutuhkan."
      - Target: 100,000,000 IDR
      - Status: "active"
      - CreatedBy: "system"
    - A sample `Officer`:
      - ID: `OFF-2024-0001`
      - Name: "Ahmad Petugas"
      - ReferralCode: "REF001"
      - Status: "active"
- **Returns**: `nil` on successful execution (either initialization or skipping). Returns an error if any operation during initialization fails.

### Program Management
#### `CreateProgram(id, name, description, target, startDate, endDate, createdBy)`
- **Description**: Creates a new donation program/campaign
- **Validation**: ID format, dates, target amount
- **Returns**: Error if validation fails

#### `GetProgram(id)`
- **Description**: Retrieves program details by ID
- **Returns**: Program object or error if not found

#### `GetAllPrograms()`
- **Description**: Retrieves all donation programs
- **Returns**: Array of all programs

### Officer Management
#### `RegisterOfficer(id, name, referralCode)`
- **Description**: Registers a new officer with referral tracking
- **Validation**: ID format, unique referral code
- **Returns**: Error if validation fails

#### `GetOfficerByReferral(referralCode)`
- **Description**: Finds officer by their referral code
- **Returns**: Officer object or error if not found

### Zakat Transaction Management
#### `AddZakat(id, programID, muzakki, amount, zakatType, paymentMethod, organization, referralCode)`
- **Description**: Records a new Zakat donation with "pending" status (major change from v1.0 which immediately set status to "collected")
- **Parameters**:
  - `id`: Unique transaction identifier (Format: `ZKT-YDSF-{MLG|JTM}-{YYYYMM}-{COUNTER}`)
  - `programID`: ID of an existing DonationProgram (optional, can be empty string)
  - `muzakki`: Name of the donor (required, cannot be empty)
  - `amount`: Donation amount (must be greater than 0)
  - `zakatType`: Type of Zakat, either "fitrah" or "maal"
  - `paymentMethod`: Payment method - "transfer", "ewallet", "credit_card", "debit_card", "cash"
  - `organization`: Collecting organization - "YDSF Malang" or "YDSF Jatim"
  - `referralCode`: Referral code of an existing Officer (optional, can be empty string)
- **New Validation Features (v2.0)**:
  - Program existence validation if programID provided
  - Officer existence validation if referralCode provided
  - Enhanced payment method validation
  - Strict ID format validation with organization codes
- **Behavior Change**: Creates donation in "pending" status requiring admin validation (vs immediate "collected" in v1.0)
- **Returns**: Error if validation fails or Zakat ID already exists

#### `ValidatePayment(zakatID, receiptNumber, validatedBy)`
- **Description**: Admin function to validate a pending Zakat payment.
- **Parameters**:
  - `zakatID`: The ID of the Zakat transaction to validate.
  - `receiptNumber`: The receipt number for the validated payment.
  - `validatedBy`: Identifier of the admin performing the validation.
- **Behavior**:
  - Retrieves the Zakat transaction by `zakatID`.
  - Checks if the Zakat status is "pending". If not, returns an error.
  - Updates the Zakat status to "collected".
  - Records the `receiptNumber`, `validatedBy`, and current timestamp as `validationDate`.
  - **Program Update**: If the Zakat has a `programID`:
    - Fetches the corresponding `DonationProgram`. If not found, returns an error.
    - Adds the Zakat `amount` to the program's `collected` field.
    - Saves the updated `DonationProgram`.
  - **Officer Update**: If the Zakat has a `referralCode`:
    - Fetches the corresponding `Officer` by `referralCode`. If not found, returns an error.
    - Adds the Zakat `amount` to the officer's `totalReferred` field.
    - Saves the updated `Officer`.
- **Returns**: `nil` on success, or an error if the Zakat is not found, not in "pending" status, or if related program/officer updates fail.

#### `QueryZakat(id)`
- **Description**: Retrieves specific Zakat transaction
- **Returns**: Complete transaction details

#### `GetAllZakat()`
- **Description**: Retrieves all Zakat transactions
- **Returns**: Array of all transactions

#### `GetZakatByStatus(status)`
- **Description**: Filters transactions by status
- **Parameters**: "pending", "collected", or "distributed"
- **Returns**: Filtered transaction array

#### `GetZakatByProgram(programID)`
- **Description**: Retrieves transactions for specific program
- **Returns**: Program-specific transactions

#### `GetZakatByOfficer(referralCode)`
- **Description**: Retrieves transactions referred by officer
- **Returns**: Officer-referred transactions

#### `GetZakatByMuzakki(muzakkiName)`
- **Description**: Retrieves all Zakat records for a given donor's name (`muzakkiName`).
- **Parameters**:
  - `muzakkiName`: The name of the donor to search for.
- **Returns**: An array of `Zakat` objects matching the `muzakkiName`, or an empty array if none are found. Returns an error if the query fails.

#### `DistributeZakat(zakatID, distributionID, recipientName, amount, distributionTimestamp, distributedBy)`
- **Description**: Records the distribution of a collected Zakat (enhanced from v1.0 with additional tracking fields)
- **Parameters**:
  - `zakatID`: ID of the Zakat transaction to distribute
  - `distributionID`: Unique identifier for this distribution event (new in v2.0)
  - `recipientName`: Name of the recipient (mustahik)
  - `amount`: Amount being distributed (must be > 0 and <= Zakat's collected amount)
  - `distributionTimestamp`: Distribution timestamp (ISO 8601 format)
  - `distributedBy`: Admin/Officer performing the distribution (new in v2.0)
- **Enhanced Features (v2.0)**:
  - Automatic program `distributed` amount updates
  - Distribution ID tracking for audit trails
  - Distributor identification and tracking
  - Enhanced validation and error handling
- **Behavior**: Only "collected" Zakat can be distributed, updates program totals automatically
- **Returns**: Error if validation fails, Zakat not found, or not in "collected" status

#### `ZakatExists(id)`
- **Description**: Checks transaction existence
- **Returns**: Boolean and error

### Reporting
#### `GetDailyReport(date)`
- **Description**: Generates a daily report of "collected" Zakat transactions based on their `validationDate`.
- **Parameters**:
  - `date`: The target date for the report, in "YYYY-MM-DD" format.
- **Behavior**:
  - Queries Zakat transactions where `status` is "collected" and `validationDate` falls within the specified `date` (from 00:00:00Z of the target date to 00:00:00Z of the next day, effectively querying for the entire day based on RFC3339 timestamps).
- **Returns**: A map containing:
  - `date`: The report date.
  - `totalAmount`: Total sum of Zakat amounts collected on that day.
  - `transactionCount`: Number of Zakat transactions collected on that day.
  - `byType`: A map of Zakat types (e.g., "maal", "fitrah") to their respective total amounts collected.
  - `byProgram`: A map of `ProgramID`s to their respective total Zakat amounts collected (programID will be an empty string if not associated with a program).
  Returns an error if the date format is invalid or the query fails.

## Validation Rules

### Enhanced Validation (Major Improvements from v1.0)

#### ID Format Validation
- **Zakat ID**: `ZKT-YDSF-{MLG|JTM}-{YYYYMM}-{COUNTER}` (vs simple format in v1.0)
- **Program ID**: `PROG-{YYYY}-{COUNTER}` (new in v2.0)
- **Officer ID**: `OFF-{YYYY}-{COUNTER}` (new in v2.0)

#### Enhanced Field Validation
- **Payment Methods**: 5 supported methods vs basic validation in v1.0
- **Status Transitions**: Enforced 3-stage workflow vs 2-stage in v1.0
- **Organizations**: Strict validation for YDSF branches
- **Timestamps**: ISO 8601 format validation
- **Cross-Entity Validation**: Program and Officer existence checking (new in v2.0)

### Business Rules (New in v2.0)
- **Payment Workflow**: All donations start as "pending" and require admin validation
- **Status Progression**: Enforced sequential status transitions (pending → collected → distributed)
- **Automatic Updates**: Program and officer totals automatically maintained
- **Distribution Controls**: Only "collected" donations can be distributed
- **Amount Validation**: Distribution amounts cannot exceed original donation amounts
- **Audit Trail**: Complete tracking of validation and distribution actions

**Note**: v1.0 had minimal validation with immediate collection upon creation.

## Testing

### Unit Tests
Run comprehensive unit tests with coverage analysis:
```bash
cd chaincode/zakat
go test -v ./...
go test -cover ./...
```

### Test Coverage
**Current Coverage**: 76% (13/17 functions tested) - significantly expanded from basic v1.0 tests

#### ✅ Tested Functions (v2.0 Test Suite)
**Core Functions:**
- `InitLedger()` - Idempotent initialization with sample data
- `AddZakat()` - Enhanced validation including program/officer existence
- `QueryZakat()` - Basic retrieval functionality
- `GetAllZakat()` - Comprehensive result handling
- `ValidatePayment()` - New payment validation workflow
- `GetZakatByMuzakki()` - New donor-based querying

**Program Management (New in v2.0):**
- `GetAllPrograms()` - Program listing functionality
- `RegisterOfficer()` - Officer registration
- `GetOfficerByReferral()` - Officer lookup by referral code

**Advanced Querying (New in v2.0):**
- `GetZakatByStatus()` - Status-based filtering
- `GetZakatByProgram()` - Program-based filtering
- `GetZakatByOfficer()` - Officer-based filtering
- `GetDailyReport()` - Daily reporting with analytics

#### ❌ Functions Needing Test Coverage
- `CreateProgram()` - Program creation logic
- `GetProgram()` - Individual program retrieval
- `DistributeZakat()` - Enhanced distribution workflow
- `ZakatExists()` - Existence checking utility

### Test Data & Scenarios
**Enhanced Mock Data (v2.0)**:
- **Multi-Entity Testing**: Zakat, Programs, and Officers
- **Workflow Testing**: Complete pending → collected → distributed flow
- **Integration Testing**: Cross-entity updates (program totals, officer referrals)
- **Validation Testing**: All new validation rules and business logic
- **Error Scenarios**: Enhanced error handling and edge cases

**Sample Test Scenarios**:
- Donation amounts: 500K-2.5M IDR
- Organizations: YDSF Malang, YDSF Jatim
- Payment methods: transfer, ewallet, cash, credit_card, debit_card
- Complete 3-stage workflow testing
- Officer referral commission calculations
- Program target vs collected tracking

#### Real-World Example Data
Based on successful chaincode testing, typical data flows include:

**Sample Program** (from InitLedger):
```json
{
  "ID": "PROG-2024-0001",
  "name": "Bantuan Pendidikan Anak Yatim",
  "description": "Program bantuan pendidikan untuk anak-anak yatim yang membutuhkan.",
  "target": 100000000,
  "collected": 5000000,
  "distributed": 500000,
  "status": "active"
}
```

**Complete Zakat Workflow Example**:
1. **Initial Submission** (pending status):
   ```json
   {
     "ID": "ZKT-YDSF-MLG-202506-1453",
     "programID": "PROG-2024-0001",
     "muzakki": "Farah Dita Amany",
     "amount": 2500000,
     "type": "maal",
     "paymentMethod": "transfer",
     "status": "pending",
     "organization": "YDSF Malang",
     "referralCode": "REF001"
   }
   ```

2. **After Payment Validation** (collected status):
   ```json
   {
     "status": "collected",
     "receiptNumber": "INV/2024/0609/1453",
     "validatedBy": "AdminOrg1",
     "validationDate": "2025-06-09T23:08:30Z"
   }
   ```

3. **After Distribution** (distributed status):
   ```json
   {
     "status": "distributed",
     "mustahik": "Fakir Miskin Desa Sukamaju",
     "distribution": 500000,
     "distributedAt": "2025-06-09T23:08:45Z",
     "distributionID": "DIST-20250609-7805",
     "distributedBy": "AdminOrg2"
   }
   ```

**Automatic Updates Demonstrated**:
- **Program totals**: `collected` increased from 2.5M to 5M IDR after validation
- **Officer referrals**: `totalReferred` increased from 2.5M to 5M IDR after validation
- **Distribution tracking**: Program `distributed` amount updated to 500K IDR after distribution

**Note**: v1.0 had basic tests for only 5 simple functions vs 17 complex functions in v2.0.

## Security Considerations

### Enhanced Security Features (v2.0)
- **Comprehensive Input Validation**: All parameters validated for format, content, and business rules
- **Strict Status Transition Controls**: Enforced workflow progression prevents status bypassing
- **Cross-Entity Validation**: Program and officer existence verified before associations
- **Admin-Only Functions**: Payment validation and distribution require admin privileges
- **Audit Trail**: Complete transaction history with timestamps and responsible parties
- **ID Format Enforcement**: Strict pattern matching prevents malformed identifiers
- **Amount Validation**: Prevents negative amounts and distribution overruns
- **Organization Authorization**: Only authorized YDSF branches can collect donations

### Business Logic Security
- **Payment Validation Workflow**: Prevents unauthorized collection status changes
- **Distribution Controls**: Only validated payments can be distributed
- **Automatic Calculations**: Program and officer totals maintained automatically to prevent manipulation
- **Receipt Tracking**: All validated payments require receipt documentation
- **Timestamp Integrity**: ISO 8601 format validation ensures proper chronological ordering

**Note**: v1.0 had basic validation with minimal security controls vs comprehensive security framework in v2.0.

## Changelog

### v2.0 - Complete Architecture Overhaul
**Release Date**: Current Version  
**Breaking Changes**: This version represents a complete rewrite and is not backward compatible with v1.0.

#### 🏗️ **Architecture Changes**
- **Multi-Entity System**: Expanded from single `Zakat` entity to three interconnected entities:
  - `Zakat` (enhanced from 9 to 16+ fields)
  - `DonationProgram` (completely new)
  - `Officer` (completely new)
- **Payment Workflow**: Implemented 3-stage workflow (pending → collected → distributed) vs 2-stage in v1.0
- **Business Process**: Added comprehensive donation campaign and referral management

#### 📊 **Data Model Enhancements**
- **Zakat Structure**: Added 8 new fields including `ProgramID`, `PaymentMethod`, `ReferralCode`, `ReceiptNumber`, `ValidatedBy`, `ValidationDate`, `DistributionID`, `DistributedBy`
- **JSON Optimization**: Added `omitempty` tags for optional fields to reduce storage overhead
- **Enhanced Validation**: Expanded from basic validation to comprehensive business rule enforcement

#### 🚀 **New Features**
- **Program Management**: Complete donation campaign lifecycle management
- **Officer Referral System**: Referral tracking with automatic commission calculations
- **Payment Validation Workflow**: Admin-controlled payment approval process
- **Advanced Querying**: 8 query functions vs 2 in v1.0
- **Daily Reporting**: Comprehensive analytics and reporting capabilities
- **Automatic Updates**: Program and officer totals maintained automatically

#### 🔧 **Function Changes**
- **InitLedger()**: Now idempotent, creates sample program and officer data
- **AddZakat()**: Enhanced with program/officer validation, creates "pending" status
- **New: ValidatePayment()**: Admin function to approve pending payments
- **Enhanced: DistributeZakat()**: Added distribution ID and distributor tracking
- **New Query Functions**: GetZakatByStatus, GetZakatByProgram, GetZakatByOfficer, GetZakatByMuzakki
- **New: GetDailyReport()**: Generate daily analytics reports

#### 🧪 **Testing Improvements**
- **Test Coverage**: Expanded from 5 basic functions to 13/17 functions (76% coverage)
- **Mock Data**: Comprehensive test scenarios covering all business workflows
- **Integration Testing**: Cross-entity updates and workflow validation

#### 🔒 **Security Enhancements**
- **Enhanced Validation**: Comprehensive input validation and business rule enforcement
- **Workflow Controls**: Strict status transition enforcement
- **Admin Functions**: Payment validation and distribution require admin privileges
- **Audit Trail**: Complete transaction history with responsible party tracking

### v1.0 - Initial Implementation
**Release Date**: Previous Version (Baseline)
- **Basic Zakat Management**: Simple transaction recording with immediate collection
- **Simple Data Model**: 9-field Zakat structure
- **Limited Functions**: AddZakat, QueryZakat, GetAllZakat, DistributeZakat, ZakatExists, InitLedger
- **Basic Validation**: Simple format and amount validation
- **Two-Stage Workflow**: Direct transition from collected to distributed
- **No Program Management**: No campaign or program tracking capabilities
- **No Officer System**: No referral or commission tracking
- **Limited Testing**: Basic test coverage for core functions
