// Type definitions for the Zakat Platform

export interface User {
  id: string
  phone: string
  email?: string
  name: string
  role: 'donor' | 'officer' | 'org_admin' | 'super_admin'
  referral_code?: string
  organization?: string
  created_at: string
  updated_at: string
}

export interface Donation {
  id: string
  donor_id?: string
  donor_name: string
  donor_phone: string
  donor_email?: string
  amount: number
  type: 'fitrah' | 'maal'
  program_id?: string
  referral_code?: string
  blockchain_status: 'pending' | 'collected' | 'distributed'
  sync_status: 'synced' | 'pending_sync' | 'error'
  payment_reference?: string
  validated_at?: string
  validated_by?: string
  distributed_at?: string
  distributed_by?: string
  blockchain_tx_id?: string
  created_at: string
  updated_at: string
}

export interface Program {
  id: string
  name: string
  description?: string
  organization: string
  target_amount?: number
  collected_amount: number
  is_active: boolean
  created_at: string
}

export interface Distribution {
  id: string
  donation_id: string
  recipient_name: string
  recipient_details?: any
  amount: number
  distribution_date?: string
  distributed_by?: string
  blockchain_tx_id?: string
  created_at: string
}

export interface AuditLog {
  id: string
  entity_type: string
  entity_id: string
  action: string
  performed_by: string
  details: any
  created_at: string
}

// API Request/Response Types
export interface CreateDonationRequest {
  name: string
  phone: string
  email?: string
  amount: number
  type: 'fitrah' | 'maal'
  program_id?: string
  referral_code?: string
}

export interface AdminLoginRequest {
  phone: string
  password: string
}

export interface AdminLoginResponse {
  token: string
  user: User
}

export interface DashboardMetrics {
  pending_donations: number
  todays_collection: number
  total_collected: number
  total_distributed: number
  network_health: 'healthy' | 'warning' | 'error'
  blockchain_height: number
  chaincode_instantiated: boolean
}

export interface RecentActivity {
  type: 'donation' | 'validation' | 'distribution' | 'system'
  message: string
  timestamp: string
}

export interface DashboardResponse {
  metrics: DashboardMetrics
  recent_activity: RecentActivity[]
}

// Form Types
export interface DonationFormData {
  name: string
  phone: string
  email: string
  amount: number
  type: 'fitrah' | 'maal'
  program_id: string
  referral_code?: string
}

export interface TrackingFormData {
  donationId: string
}

export interface LoginFormData {
  phone: string
  password: string
}

// API Error Type
export interface ApiError {
  message: string
  error?: string
  details?: any
}

// Pagination
export interface PaginationParams {
  limit?: number
  offset?: number
}

export interface PaginatedResponse<T> {
  data: T[]
  pagination: {
    limit: number
    offset: number
    total?: number
  }
}

// Component Props Types
export interface LayoutProps {
  children: React.ReactNode
}

export interface CardProps {
  children: React.ReactNode
  className?: string
}

export interface ButtonProps {
  children: React.ReactNode
  variant?: 'primary' | 'secondary' | 'outline' | 'danger'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  loading?: boolean
  onClick?: () => void
  type?: 'button' | 'submit' | 'reset'
  className?: string
}

export interface InputProps {
  label?: string
  error?: string
  required?: boolean
  className?: string
  [key: string]: any
}

// Status Types
export type BlockchainStatus = 'pending' | 'collected' | 'distributed'
export type SyncStatus = 'synced' | 'pending_sync' | 'error'
export type ZakatType = 'fitrah' | 'maal'
export type UserRole = 'donor' | 'officer' | 'org_admin' | 'super_admin'
export type NetworkHealth = 'healthy' | 'warning' | 'error'
