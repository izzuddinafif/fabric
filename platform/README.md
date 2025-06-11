# Zakat Platform - MVP Phase 1

## Overview
Blockchain-based zakat donation management platform built on Hyperledger Fabric with streamlined auto-validation system.

## Architecture
- **Backend**: Go + Gin framework with Hyperledger Fabric SDK
- **Frontend**: Next.js with Tailwind CSS (Islamic green/gold theme)
- **Database**: PostgreSQL + Redis
- **Blockchain**: Existing Hyperledger Fabric network (2 orgs: YDSF Malang, YDSF Jatim)

## MVP Phase 1 Features
- ✅ Guest donation form (no registration required)
- ✅ Auto-validation system with **mock payment verification**
- ✅ Admin authentication & basic dashboard
- ✅ Email notifications
- ✅ Docker Compose deployment

## Mock Payment System (MVP)
For MVP Phase 1, we use **mock payment verification** to streamline development:

- **Auto-approval**: Donations are automatically validated after 30 seconds
- **Mock reference**: Payment references use format `MOCK-PAYMENT-REF-{timestamp}`
- **Testing**: Allows focus on blockchain integration and core functionality
- **Future**: Phase 3 will integrate real Indonesian payment gateways (Midtrans, Xendit, DOKU)

### Mock Payment Flow:
```
Donor Submits → AddZakat() (pending) → Wait 30s → Auto-Validate → ValidatePayment() (collected) → Email Confirmation
```

## Project Structure
```
platform/
├── backend/                 # Go API server
│   ├── cmd/server/         # Application entry point
│   ├── internal/           # Private application code
│   │   ├── config/        # Configuration management
│   │   ├── handlers/      # HTTP handlers
│   │   ├── services/      # Business logic
│   │   ├── models/        # Data models
│   │   └── middleware/    # HTTP middleware
│   ├── pkg/               # Public packages
│   │   ├── fabric/        # Fabric SDK client
│   │   └── database/      # Database connections
│   ├── migrations/        # Database migrations
│   └── Dockerfile
├── frontend/              # Next.js application
│   ├── components/        # React components
│   ├── pages/            # Next.js pages
│   ├── hooks/            # Custom React hooks
│   ├── styles/           # Tailwind CSS
│   └── Dockerfile
├── migrations/           # PostgreSQL migrations
├── docker-compose.platform.yml
└── README.md
```

## Quick Start

### Prerequisites
- Docker and Docker Compose (Docker 28.1.1+)
- Running Hyperledger Fabric network (see main project)
- Go 1.23+ (for development)
- Node.js 24+ (for development)

### Development Setup
1. **Start the platform services:**
   ```bash
   cd platform
   docker-compose -f docker-compose.platform.yml up -d
   ```

2. **Access the services:**
   - Frontend: http://localhost:3001
   - Backend API: http://localhost:3002
   - PostgreSQL: localhost:5432
   - Redis: localhost:6379

### Environment Variables
Create `.env` file in platform directory:
```env
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=zakatplatform
DB_USER=zakat
DB_PASSWORD=secure_password

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Fabric
FABRIC_CONFIG_PATH=../config
FABRIC_WALLET_PATH=./wallet
FABRIC_CHANNEL=zakatchannel
FABRIC_CHAINCODE=zakat

# Email (SMTP)
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=your_email@gmail.com
EMAIL_PASSWORD=your_app_password

# JWT
JWT_SECRET=your_jwt_secret_key_here
JWT_EXPIRY=720h # 30 days

# Mock Payment
MOCK_PAYMENT_DELAY=30s
```

## API Endpoints

### Donations
- `POST /api/donations` - Submit new donation (guest)
- `GET /api/donations/{id}` - Get donation details
- `GET /api/admin/donations` - List donations (admin only)

### Authentication
- `POST /api/auth/admin/login` - Admin login
- `POST /api/auth/logout` - Logout

### Dashboard
- `GET /api/admin/dashboard` - Dashboard metrics

## Database Schema
See `migrations/001_initial_schema.sql` for complete PostgreSQL schema including:
- `users` - User accounts and roles
- `donations` - Donation records with blockchain sync status
- `programs` - Zakat programs
- `distributions` - Distribution tracking
- `audit_logs` - System audit trail

## Development Workflow

### Backend Development
```bash
cd platform/backend
go mod tidy
go run cmd/server/main.go
```

### Frontend Development
```bash
cd platform/frontend
npm install
npm run dev
```

### Database Migrations
```bash
# Run migrations
psql -h localhost -U zakat -d zakatplatform -f migrations/001_initial_schema.sql
```

## Testing
- Mock payments automatically validate after 30 seconds
- Use admin credentials from environment
- Test donation flow: Submit → Wait 30s → Check validation status

## Monitoring Integration
- Platform integrates with existing Grafana dashboard (ID 10892)
- Business metrics tracked alongside blockchain performance
- Real-time updates via WebSocket (Phase 2)

## Next Phases
- **Phase 2**: User management, WebSocket real-time updates, Grafana integration
- **Phase 3**: Real payment gateways, Kubernetes deployment, advanced reporting

## Contributing
1. Follow Go and React best practices
2. Test with mock payment system
3. Ensure Islamic design principles (green/gold theme)
4. Document any new environment variables

---

**Current Phase**: MVP Phase 1 - Core Donation Flow  
**Mock Payment**: Active (30-second auto-validation)  
**Next**: Real payment gateway integration in Phase 3
