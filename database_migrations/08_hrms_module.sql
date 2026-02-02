-- =================================================================
-- SEVEN WAVES ERP - HRM & PAYROLL MODULE
-- SAP Business One HANA Standards Compliant
-- =================================================================

-- =====================================================
-- 1. EMPLOYEE MANAGEMENT
-- =====================================================

-- Departments (Created FIRST to allow employees to reference it)
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    parent_department_id UUID REFERENCES departments(id),
    manager_id UUID, -- Will reference employees via ALTER TABLE later
    cost_center VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Designations / Job Titles
CREATE TABLE IF NOT EXISTS designations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    department_id UUID REFERENCES departments(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Employee Master Data (SAP Standard)
CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_code VARCHAR(20) UNIQUE NOT NULL,
    -- Personal Information
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(200) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    date_of_birth DATE,
    gender VARCHAR(10) CHECK (gender IN ('Male', 'Female', 'Other')),
    marital_status VARCHAR(20) CHECK (marital_status IN ('Single', 'Married', 'Divorced', 'Widowed')),
    nic_number VARCHAR(20) UNIQUE, -- Sri Lanka NIC
    passport_number VARCHAR(20),
    
    -- Contact Information
    personal_email VARCHAR(100),
    company_email VARCHAR(100),
    mobile_phone VARCHAR(20),
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    
    -- Address
    permanent_address TEXT,
    current_address TEXT,
    
    -- Employment Details
    department_id UUID REFERENCES departments(id),
    designation_id UUID REFERENCES designations(id),
    employment_type VARCHAR(20) DEFAULT 'Permanent' CHECK (employment_type IN ('Permanent', 'Contract', 'Probation', 'Intern', 'Part-Time')),
    date_of_joining DATE NOT NULL,
    date_of_confirmation DATE,
    date_of_leaving DATE,
    notice_period_days INTEGER DEFAULT 30,
    
    -- Salary Information (Restricted Access)
    salary_mode VARCHAR(20) DEFAULT 'Bank' CHECK (salary_mode IN ('Bank', 'Cash', 'Cheque')),
    bank_name VARCHAR(100),
    bank_branch VARCHAR(100),
    bank_account_no VARCHAR(50),
    
    -- EPF/ETF (Sri Lanka Compliance)
    epf_number VARCHAR(20),
    etf_number VARCHAR(20),
    
    -- Status
    status VARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Inactive', 'Left', 'Suspended')),
    
    -- Linked User Account
    user_id UUID REFERENCES auth.users(id),
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES profiles(id)
);

-- Add FK manager constraint to departments (Cyclic dependency resolution)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_dept_manager') THEN
        ALTER TABLE departments 
        ADD CONSTRAINT fk_dept_manager 
        FOREIGN KEY (manager_id) REFERENCES employees(id) 
        ON DELETE SET NULL;
    END IF;
END $$;

-- =====================================================
-- 2. SALARY COMPONENTS & STRUCTURES (SAP Payroll)
-- =====================================================

-- Salary Components (Earnings & Deductions)
CREATE TABLE IF NOT EXISTS salary_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    component_type VARCHAR(20) NOT NULL CHECK (component_type IN ('Earning', 'Deduction')),
    description TEXT,
    
    -- Calculation
    amount_based_on VARCHAR(20) DEFAULT 'Formula' CHECK (amount_based_on IN ('Fixed', 'Formula', 'Percentage')),
    formula TEXT, -- e.g., 'base * 0.08' for EPF
    percentage DECIMAL(5,2), -- If percentage based
    
    -- Depends on other component
    depends_on_component_id UUID REFERENCES salary_components(id),
    
    -- Accounting
    expense_account VARCHAR(50), -- GL Account for expense
    payable_account VARCHAR(50), -- GL Account for liability
    
    -- Flags
    is_tax_applicable BOOLEAN DEFAULT false,
    is_flexible_benefit BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    
    -- Sri Lanka Specific
    is_epf_applicable BOOLEAN DEFAULT true,
    is_etf_applicable BOOLEAN DEFAULT true,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Salary Structures (Templates)
CREATE TABLE IF NOT EXISTS salary_structures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Applicability
    employment_type VARCHAR(20), -- 'Permanent', 'Contract', etc.
    department_id UUID REFERENCES departments(id),
    designation_id UUID REFERENCES designations(id),
    
    -- Base Values
    base_amount DECIMAL(15,2) DEFAULT 0, -- Default base salary
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Salary Structure Components (Link table)
CREATE TABLE IF NOT EXISTS salary_structure_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    salary_structure_id UUID REFERENCES salary_structures(id) ON DELETE CASCADE,
    salary_component_id UUID REFERENCES salary_components(id) ON DELETE CASCADE,
    
    -- Override values
    default_amount DECIMAL(15,2),
    formula_override TEXT,
    
    -- Order
    idx INTEGER DEFAULT 0,
    
    UNIQUE(salary_structure_id, salary_component_id)
);

-- Employee Salary Assignment
CREATE TABLE IF NOT EXISTS employee_salary_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    salary_structure_id UUID REFERENCES salary_structures(id),
    
    -- Override base amount per employee
    base_amount DECIMAL(15,2) NOT NULL,
    
    -- Effective dates
    from_date DATE NOT NULL,
    to_date DATE,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(employee_id, from_date)
);

-- =====================================================
-- 3. PAYROLL PROCESSING (SAP Batch Style)
-- =====================================================

-- Payroll Entry (Header) - Batch Processing
CREATE TABLE IF NOT EXISTS payroll_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    
    -- Period
    payroll_month INTEGER NOT NULL CHECK (payroll_month BETWEEN 1 AND 12),
    payroll_year INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- Filters
    department_id UUID REFERENCES departments(id),
    designation_id UUID REFERENCES designations(id),
    
    -- Status
    status VARCHAR(20) DEFAULT 'Draft' CHECK (status IN ('Draft', 'Submitted', 'Approved', 'Cancelled')),
    
    -- Totals
    total_employees INTEGER DEFAULT 0,
    total_gross_pay DECIMAL(15,2) DEFAULT 0,
    total_deductions DECIMAL(15,2) DEFAULT 0,
    total_net_pay DECIMAL(15,2) DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES profiles(id),
    approved_by UUID REFERENCES profiles(id)
);

-- Salary Slips (Generated from Payroll Entry)
CREATE TABLE IF NOT EXISTS salary_slips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    
    payroll_entry_id UUID REFERENCES payroll_entries(id),
    employee_id UUID REFERENCES employees(id),
    
    -- Period
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- Working Details
    total_working_days INTEGER DEFAULT 26,
    payment_days DECIMAL(5,2) DEFAULT 26,
    leave_without_pay_days DECIMAL(5,2) DEFAULT 0,
    absent_days DECIMAL(5,2) DEFAULT 0,
    
    -- Amounts
    gross_pay DECIMAL(15,2) DEFAULT 0,
    total_deduction DECIMAL(15,2) DEFAULT 0,
    net_pay DECIMAL(15,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'Draft' CHECK (status IN ('Draft', 'Submitted', 'Paid', 'Cancelled')),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Salary Slip Details (Line Items)
CREATE TABLE IF NOT EXISTS salary_slip_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    salary_slip_id UUID REFERENCES salary_slips(id) ON DELETE CASCADE,
    salary_component_id UUID REFERENCES salary_components(id),
    
    component_type VARCHAR(20) NOT NULL, -- 'Earning' or 'Deduction'
    amount DECIMAL(15,2) NOT NULL,
    
    idx INTEGER DEFAULT 0
);

-- =====================================================
-- 4. SHIFT MANAGEMENT & ATTENDANCE
-- =====================================================

-- Shift Types
CREATE TABLE IF NOT EXISTS shift_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    
    -- Grace periods (minutes)
    late_entry_grace INTEGER DEFAULT 15,
    early_exit_grace INTEGER DEFAULT 15,
    
    -- Working hours
    working_hours DECIMAL(4,2) DEFAULT 8,
    
    -- Overtime
    enable_auto_ot BOOLEAN DEFAULT false,
    ot_start_after_hours DECIMAL(4,2) DEFAULT 8,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Shift Assignments (Employee --> Shift)
CREATE TABLE IF NOT EXISTS shift_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    shift_type_id UUID REFERENCES shift_types(id),
    
    from_date DATE NOT NULL,
    to_date DATE,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Attendance Records
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    
    -- Check-in/out
    check_in_time TIMESTAMP WITH TIME ZONE,
    check_out_time TIMESTAMP WITH TIME ZONE,
    
    -- Shift
    shift_type_id UUID REFERENCES shift_types(id),
    
    -- Status
    status VARCHAR(20) DEFAULT 'Present' CHECK (status IN ('Present', 'Absent', 'Half Day', 'On Leave', 'Holiday', 'Weekend')),
    
    -- Calculated
    working_hours DECIMAL(5,2),
    overtime_hours DECIMAL(5,2) DEFAULT 0,
    late_entry_minutes INTEGER DEFAULT 0,
    early_exit_minutes INTEGER DEFAULT 0,
    
    -- Source
    attendance_source VARCHAR(20) DEFAULT 'Manual' CHECK (attendance_source IN ('Manual', 'Biometric', 'Mobile', 'Auto')),
    
    remarks TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(employee_id, attendance_date)
);

-- Attendance Requests (Manual Clock-in Workflow)
CREATE TABLE IF NOT EXISTS attendance_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    
    reason TEXT NOT NULL,
    check_in_time TIME,
    check_out_time TIME,
    
    -- Workflow
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    
    approved_by UUID REFERENCES profiles(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 5. LEAVE MANAGEMENT
-- =====================================================

-- Leave Types
CREATE TABLE IF NOT EXISTS leave_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    
    -- Allocation
    max_leaves_allowed INTEGER NOT NULL,
    max_continuous_days INTEGER,
    
    -- Carry Forward
    is_carry_forward BOOLEAN DEFAULT false,
    max_carry_forward_days INTEGER DEFAULT 0,
    
    -- Encashment
    is_encashable BOOLEAN DEFAULT false,
    encashment_threshold INTEGER,
    
    -- Earned Leave (Accrual)
    is_earned_leave BOOLEAN DEFAULT false,
    earned_leave_frequency VARCHAR(20), -- 'Monthly', 'Quarterly'
    
    -- Rules
    is_without_pay BOOLEAN DEFAULT false,
    include_holidays BOOLEAN DEFAULT false,
    is_compensatory BOOLEAN DEFAULT false,
    
    -- Applicable to
    applicable_gender VARCHAR(10), -- NULL = All, 'Male', 'Female'
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Leave Allocations (Per Employee Per Year)
CREATE TABLE IF NOT EXISTS leave_allocations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    leave_type_id UUID REFERENCES leave_types(id),
    
    -- Period
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    
    -- Leaves
    new_leaves_allocated DECIMAL(5,2) NOT NULL,
    carry_forwarded_leaves DECIMAL(5,2) DEFAULT 0,
    total_leaves DECIMAL(5,2) GENERATED ALWAYS AS (new_leaves_allocated + carry_forwarded_leaves) STORED,
    
    leaves_taken DECIMAL(5,2) DEFAULT 0,
    leaves_balance DECIMAL(5,2) GENERATED ALWAYS AS (new_leaves_allocated + carry_forwarded_leaves - leaves_taken) STORED,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(employee_id, leave_type_id, from_date)
);

-- Leave Applications
CREATE TABLE IF NOT EXISTS leave_applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    leave_type_id UUID REFERENCES leave_types(id),
    
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    half_day BOOLEAN DEFAULT false,
    half_day_date DATE,
    
    total_leave_days DECIMAL(5,2) NOT NULL,
    reason TEXT,
    
    -- Workflow (3-tier SAP Standard)
    status VARCHAR(20) DEFAULT 'Draft' CHECK (status IN ('Draft', 'Pending HR Officer', 'Pending HR Manager', 'Approved', 'Rejected', 'Cancelled')),
    
    -- Approvals
    hr_officer_id UUID REFERENCES profiles(id),
    hr_officer_approved_at TIMESTAMP WITH TIME ZONE,
    hr_manager_id UUID REFERENCES profiles(id),
    hr_manager_approved_at TIMESTAMP WITH TIME ZONE,
    
    rejection_reason TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 6. BENEFITS MANAGEMENT
-- =====================================================

-- Benefit Types
CREATE TABLE IF NOT EXISTS benefit_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Amount
    max_benefit_amount DECIMAL(15,2),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Benefit Claims
CREATE TABLE IF NOT EXISTS benefit_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    benefit_type_id UUID REFERENCES benefit_types(id),
    
    claim_date DATE NOT NULL,
    claimed_amount DECIMAL(15,2) NOT NULL,
    approved_amount DECIMAL(15,2),
    
    -- Attachments (store file paths)
    attachments TEXT[],
    
    description TEXT,
    
    -- Workflow
    status VARCHAR(20) DEFAULT 'Draft' CHECK (status IN ('Draft', 'Pending', 'Approved', 'Rejected', 'Paid')),
    
    approved_by UUID REFERENCES profiles(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 7. SEED DATA - SALARY COMPONENTS (Sri Lanka Compliance)
-- =====================================================

INSERT INTO salary_components (code, name, component_type, amount_based_on, formula, is_epf_applicable, is_etf_applicable, expense_account, payable_account) VALUES
('BASIC', 'Basic Salary', 'Earning', 'Fixed', 'base', true, true, '5100-Salaries', '2100-Salary Payable'),
('EPF_EMP', 'EPF Employee (8%)', 'Deduction', 'Formula', 'base * 0.08', false, false, NULL, '2110-EPF Payable'),
('EPF_ER', 'EPF Employer (12%)', 'Earning', 'Formula', 'base * 0.12', false, false, '5110-EPF Expense', '2110-EPF Payable'),
('ETF', 'ETF Employer (3%)', 'Earning', 'Formula', 'base * 0.03', false, false, '5120-ETF Expense', '2120-ETF Payable'),
('OT', 'Overtime', 'Earning', 'Formula', '(base / 26 / 8) * 1.5 * ot_hours', true, true, '5130-OT Expense', '2100-Salary Payable'),
('TRANS', 'Transport Allowance', 'Earning', 'Fixed', NULL, false, false, '5140-Transport Exp', '2100-Salary Payable'),
('MEAL', 'Meal Allowance', 'Earning', 'Fixed', NULL, false, false, '5150-Meal Expense', '2100-Salary Payable'),
('ATT_BONUS', 'Attendance Bonus', 'Earning', 'Fixed', NULL, true, true, '5160-Att Bonus Exp', '2100-Salary Payable')
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- 8. SEED DATA - SHIFT TYPES
-- =====================================================

INSERT INTO shift_types (code, name, start_time, end_time, working_hours, late_entry_grace, early_exit_grace) VALUES
('DAY', 'Day Shift', '08:00:00', '17:00:00', 8, 15, 15),
('NIGHT', 'Night Shift', '20:00:00', '05:00:00', 8, 15, 15),
('MORNING', 'Morning Shift', '06:00:00', '14:00:00', 8, 10, 10),
('EVENING', 'Evening Shift', '14:00:00', '22:00:00', 8, 10, 10)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- 9. SEED DATA - LEAVE TYPES (Sri Lanka Standards)
-- =====================================================

INSERT INTO leave_types (code, name, max_leaves_allowed, is_carry_forward, max_carry_forward_days, is_earned_leave, is_without_pay, applicable_gender) VALUES
('CL', 'Casual Leave', 7, false, 0, false, false, NULL),
('ML', 'Medical Leave', 14, false, 0, false, false, NULL),
('AL', 'Annual Leave', 14, true, 7, true, false, NULL),
('MAT', 'Maternity Leave', 84, false, 0, false, false, 'Female'),
('PAT', 'Paternity Leave', 3, false, 0, false, false, 'Male'),
('LWP', 'Leave Without Pay', 365, false, 0, false, true, NULL)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- 10. SEED DATA - BENEFIT TYPES
-- =====================================================

INSERT INTO benefit_types (code, name, description, max_benefit_amount) VALUES
('MED_INS', 'Medical Insurance', 'Annual medical insurance reimbursement', 50000),
('TRANS_SUB', 'Transport Subsidy', 'Monthly transport allowance claim', 5000),
('MEAL_SUB', 'Meal Subsidy', 'Daily meal allowance claim', 200),
('PHONE', 'Communication Allowance', 'Mobile phone bill reimbursement', 2500)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- 11. INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(status);
CREATE INDEX IF NOT EXISTS idx_attendance_employee_date ON attendance(employee_id, attendance_date);
CREATE INDEX IF NOT EXISTS idx_leave_applications_employee ON leave_applications(employee_id);
CREATE INDEX IF NOT EXISTS idx_leave_applications_status ON leave_applications(status);
CREATE INDEX IF NOT EXISTS idx_salary_slips_employee ON salary_slips(employee_id);
CREATE INDEX IF NOT EXISTS idx_salary_slips_payroll ON salary_slips(payroll_entry_id);

-- =====================================================
-- 12. RLS POLICIES (Role-Based Access)
-- =====================================================

-- Enable RLS
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE salary_slips ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_applications ENABLE ROW LEVEL SECURITY;

-- Employees: HR can see all, employees see only themselves
DROP POLICY IF EXISTS employees_hr_policy ON employees;
CREATE POLICY employees_hr_policy ON employees
    FOR ALL
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'hr_officer'))
        OR user_id = auth.uid()
    );

-- Salary Slips: Only HR Manager and Admin (NOT HR Officer)
DROP POLICY IF EXISTS salary_slips_hr_policy ON salary_slips;
CREATE POLICY salary_slips_hr_policy ON salary_slips
    FOR ALL
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager'))
        OR employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
    );

-- Attendance: HR can see all, employees see only themselves  
DROP POLICY IF EXISTS attendance_policy ON attendance;
CREATE POLICY attendance_policy ON attendance
    FOR ALL
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'hr_officer'))
        OR employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
    );

-- Leave Applications: HR can see all, employees see only themselves
DROP POLICY IF EXISTS leave_applications_policy ON leave_applications;
CREATE POLICY leave_applications_policy ON leave_applications
    FOR ALL
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'hr_officer'))
        OR employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
    );

-- =====================================================
-- 13. GRANT PERMISSIONS
-- =====================================================

GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ HRMS Module installed successfully!';
    RAISE NOTICE '📊 Tables created: employees, departments, designations, salary_components, salary_structures, payroll_entries, salary_slips, shift_types, attendance, leave_types, leave_applications, benefit_types, benefit_claims';
    RAISE NOTICE '🔒 RLS policies configured for role-based access';
END $$;
