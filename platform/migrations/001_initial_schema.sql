-- Initial schema for Zakat Platform
-- PostgreSQL database schema

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255),
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('donor', 'officer', 'org_admin', 'super_admin')),
    referral_code VARCHAR(50),
    organization VARCHAR(255),
    hashed_password VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Programs table
CREATE TABLE programs (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    organization VARCHAR(255) NOT NULL,
    target_amount DECIMAL(15,2),
    collected_amount DECIMAL(15,2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Donations table
CREATE TABLE donations (
    id VARCHAR(100) PRIMARY KEY, -- ZKT-YDSF-MLG-202406-0001
    donor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    donor_name VARCHAR(255) NOT NULL,
    donor_phone VARCHAR(20) NOT NULL,
    donor_email VARCHAR(255),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    type VARCHAR(20) NOT NULL CHECK (type IN ('fitrah', 'maal')),
    program_id VARCHAR(100) REFERENCES programs(id) ON DELETE SET NULL,
    referral_code VARCHAR(50),
    blockchain_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (blockchain_status IN ('pending', 'collected', 'distributed')),
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending_sync' CHECK (sync_status IN ('synced', 'pending_sync', 'error')),
    payment_reference VARCHAR(255),
    validated_at TIMESTAMP WITH TIME ZONE,
    validated_by VARCHAR(255),
    distributed_at TIMESTAMP WITH TIME ZONE,
    distributed_by VARCHAR(255),
    blockchain_tx_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Distributions table
CREATE TABLE distributions (
    id VARCHAR(100) PRIMARY KEY,
    donation_id VARCHAR(100) NOT NULL REFERENCES donations(id) ON DELETE CASCADE,
    recipient_name VARCHAR(255) NOT NULL,
    recipient_details JSONB,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    distribution_date TIMESTAMP WITH TIME ZONE,
    distributed_by VARCHAR(255),
    blockchain_tx_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Audit logs table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    performed_by VARCHAR(255) NOT NULL,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for better performance
CREATE INDEX idx_donations_donor_id ON donations(donor_id);
CREATE INDEX idx_donations_blockchain_status ON donations(blockchain_status);
CREATE INDEX idx_donations_sync_status ON donations(sync_status);
CREATE INDEX idx_donations_created_at ON donations(created_at);
CREATE INDEX idx_donations_type ON donations(type);
CREATE INDEX idx_donations_program_id ON donations(program_id);

CREATE INDEX idx_distributions_donation_id ON distributions(donation_id);
CREATE INDEX idx_distributions_distribution_date ON distributions(distribution_date);

CREATE INDEX idx_audit_logs_entity_type ON audit_logs(entity_type);
CREATE INDEX idx_audit_logs_entity_id ON audit_logs(entity_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);

-- Insert sample data

-- Insert default admin user (password: admin123)
INSERT INTO users (id, phone, email, name, role, organization, hashed_password, created_at, updated_at)
VALUES (
    uuid_generate_v4(),
    '+6281234567890',
    'admin@ydsfmalang.org',
    'Admin YDSF Malang',
    'org_admin',
    'YDSF Malang',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewYr9Cz7k8cHiJSG', -- bcrypt hash of 'admin123'
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- Insert sample programs
INSERT INTO programs (id, name, description, organization, target_amount, collected_amount, is_active, created_at)
VALUES 
    ('PROG-FITRAH-2024', 'Zakat Fitrah 2024', 'Program pengumpulan zakat fitrah untuk tahun 2024', 'YDSF Malang', 100000000.00, 0.00, true, CURRENT_TIMESTAMP),
    ('PROG-MAAL-2024', 'Zakat Maal 2024', 'Program pengumpulan zakat maal untuk tahun 2024', 'YDSF Malang', 500000000.00, 0.00, true, CURRENT_TIMESTAMP),
    ('PROG-PENDIDIKAN-2024', 'Bantuan Pendidikan 2024', 'Program bantuan pendidikan untuk anak yatim dan dhuafa', 'YDSF Malang', 200000000.00, 0.00, true, CURRENT_TIMESTAMP);

-- Update trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add update triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_donations_updated_at BEFORE UPDATE ON donations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to generate donation ID
CREATE OR REPLACE FUNCTION generate_donation_id(org_code VARCHAR DEFAULT 'YDSF-MLG')
RETURNS VARCHAR AS $$
DECLARE
    current_year INTEGER;
    current_month INTEGER;
    sequence_num INTEGER;
    donation_id VARCHAR;
BEGIN
    current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    current_month := EXTRACT(MONTH FROM CURRENT_DATE);
    
    -- Get next sequence number for this month
    SELECT COALESCE(MAX(CAST(SUBSTRING(id FROM LENGTH(id)-3) AS INTEGER)), 0) + 1
    INTO sequence_num
    FROM donations
    WHERE id LIKE 'ZKT-' || org_code || '-' || current_year || LPAD(current_month::TEXT, 2, '0') || '-%';
    
    donation_id := 'ZKT-' || org_code || '-' || current_year || LPAD(current_month::TEXT, 2, '0') || '-' || LPAD(sequence_num::TEXT, 4, '0');
    
    RETURN donation_id;
END;
$$ LANGUAGE plpgsql;
