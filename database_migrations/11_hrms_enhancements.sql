-- =================================================================
-- SEVEN WAVES ERP - HRMS ENHANCEMENTS (Phase 2)
-- Adds: Sales Hierarchy, Commission Packages, Performance, Training, Resignation
-- =================================================================

-- =====================================================
-- 1. ENHANCE EMPLOYEE MASTER
-- =====================================================

DO $$
BEGIN
    -- Add Personal Details
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'name_with_initials') THEN
        ALTER TABLE employees ADD COLUMN name_with_initials VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'nationality') THEN
        ALTER TABLE employees ADD COLUMN nationality VARCHAR(50);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'civil_status') THEN
        ALTER TABLE employees ADD COLUMN civil_status VARCHAR(20) CHECK (civil_status IN ('Single', 'Married', 'Divorced', 'Widowed'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'driving_license') THEN
        ALTER TABLE employees ADD COLUMN driving_license VARCHAR(50);
    END IF;

    -- JSONB Columns for Flexible Data
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'education_qualifications') THEN
        ALTER TABLE employees ADD COLUMN education_qualifications JSONB DEFAULT '[]'::jsonb;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'kyc_documents') THEN
        ALTER TABLE employees ADD COLUMN kyc_documents JSONB DEFAULT '[]'::jsonb;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'welfare_activation') THEN
        ALTER TABLE employees ADD COLUMN welfare_activation BOOLEAN DEFAULT false;
    END IF;
    
    -- Status Update
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'resignation_status') THEN
        ALTER TABLE employees ADD COLUMN resignation_status VARCHAR(20) CHECK (resignation_status IN ('None', 'Pending', 'Approved', 'Rejected'));
    END IF;
END $$;

-- =====================================================
-- 2. SALES HIERARCHY (Complex Network)
-- =====================================================

CREATE TABLE IF NOT EXISTS sales_hierarchy (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('Zone', 'Region', 'District', 'Branch', 'Team')),
    manager_id UUID REFERENCES employees(id),
    parent_id UUID REFERENCES sales_hierarchy(id),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS employee_sales_hierarchy (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    hierarchy_id UUID REFERENCES sales_hierarchy(id) ON DELETE SET NULL,
    role VARCHAR(20), -- e.g., 'Member', 'Leader'
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(employee_id, hierarchy_id)
);

-- =====================================================
-- 3. SALARY CONFIGURATIONS (Advanced)
-- =====================================================

CREATE TABLE IF NOT EXISTS salary_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Primary Method
    method VARCHAR(20) CHECK (method IN ('Basic', 'Unit', 'Day', 'Commission')),
    
    -- Rates
    basic_salary DECIMAL(15,2) DEFAULT 0,
    unit_rate DECIMAL(15,2) DEFAULT 0,
    daily_rate DECIMAL(15,2) DEFAULT 0,
    
    -- Allowances (JSON to store dynamic rows: [{name: 'Fuel', amount: 5000}])
    allowances JSONB DEFAULT '[]'::jsonb,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(employee_id)
);

-- =====================================================
-- 4. COMMISSION PACKAGES & TIERS
-- =====================================================

CREATE TABLE IF NOT EXISTS commission_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'MPO', 'BSM'
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tiers for Direct, Leader, Upline commissions
CREATE TABLE IF NOT EXISTS commission_tiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    package_id UUID REFERENCES commission_packages(id) ON DELETE CASCADE,
    
    -- Tier Logic
    tier_type VARCHAR(20) CHECK (tier_type IN ('Direct', 'Leader', 'Upline')),
    
    min_units INTEGER DEFAULT 0,
    max_units INTEGER, -- NULL means infinity (e.g., 9 Over)
    
    -- Target Role (for Leader/Upline commissions)
    target_role VARCHAR(50), -- e.g., 'BSM', 'ASM'
    
    -- Payouts
    commission_amount DECIMAL(15,2) DEFAULT 0,
    fuel_allowance DECIMAL(15,2) DEFAULT 0,
    installation_amount DECIMAL(15,2) DEFAULT 0,
    other_incentives DECIMAL(15,2) DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Link Employee to a Package
ALTER TABLE salary_configurations 
ADD COLUMN commission_package_id UUID REFERENCES commission_packages(id);

-- =====================================================
-- 5. PERFORMANCE & TRAINING
-- =====================================================

CREATE TABLE IF NOT EXISTS performance_evaluations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    evaluation_date DATE NOT NULL,
    
    evaluated_by UUID REFERENCES profiles(id),
    
    -- JSON to store criteria and marks: [{criteria: 'Punctuality', mark: 8}, ...]
    criteria_details JSONB DEFAULT '[]'::jsonb,
    total_score DECIMAL(5,2),
    
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    approved_by UUID REFERENCES profiles(id),
    
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS training_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    
    training_topic VARCHAR(200) NOT NULL,
    trainer_name VARCHAR(100),
    training_date DATE,
    duration_hours DECIMAL(4,2),
    
    status VARCHAR(20) DEFAULT 'Completed' CHECK (status IN ('Scheduled', 'Completed', 'Missed')),
    remarks TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 6. SALARY ADJUSTMENTS & AUDIT
-- =====================================================

CREATE TABLE IF NOT EXISTS salary_adjustments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    
    type VARCHAR(20) CHECK (type IN ('Addition', 'Deduction')),
    reason VARCHAR(200) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    
    -- Recurring Logic
    is_recurring BOOLEAN DEFAULT false,
    start_date DATE,
    end_date DATE, -- NULL for indefinite
    
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    approved_by UUID REFERENCES profiles(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audit Table for "Hold/Paid" workflow
CREATE TABLE IF NOT EXISTS salary_audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    salary_slip_id UUID REFERENCES salary_slips(id) ON DELETE CASCADE,
    
    action VARCHAR(20) CHECK (action IN ('Hold', 'Release', 'MarkPaid', 'Edit')),
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    
    reason TEXT,
    performed_by UUID REFERENCES profiles(id),
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 7. RESIGNATION MANAGEMENT
-- =====================================================

CREATE TABLE IF NOT EXISTS employee_resignations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    
    reason TEXT NOT NULL,
    interviewed_by UUID REFERENCES employees(id), -- Exit Interviewer
    
    submission_date DATE DEFAULT CURRENT_DATE,
    expected_leaving_date DATE,
    
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    approval_date DATE,
    approved_by UUID REFERENCES profiles(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 8. PERMISSIONS
-- =====================================================

GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Enable RLS for new tables
ALTER TABLE sales_hierarchy ENABLE ROW LEVEL SECURITY;
ALTER TABLE salary_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_resignations ENABLE ROW LEVEL SECURITY;

-- Simple "View All" policy for HR
CREATE POLICY hrms_enhancement_policy ON sales_hierarchy FOR ALL TO authenticated USING (true);
CREATE POLICY pkg_enhancement_policy ON commission_packages FOR ALL TO authenticated USING (true);
-- (Using broader policies for lookup tables, stricter can be added later)

DO $$
BEGIN
    RAISE NOTICE '✅ HRMS Enhancements (Phase 2) applied successfully!';
END $$;
