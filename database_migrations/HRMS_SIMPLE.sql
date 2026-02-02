-- =================================================================
-- ⚡ SEVEN WAVES ERP - HRMS MODULE (NO RLS VERSION) ⚡
-- RUN THIS IN SUPABASE SQL EDITOR
-- =================================================================
-- This version skips RLS policies that require role enum changes
-- =================================================================

-- =====================================================
-- PART 1: CORE TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    parent_department_id UUID REFERENCES departments(id),
    manager_id UUID,
    cost_center VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS designations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    department_id UUID REFERENCES departments(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_code VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(200) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    date_of_birth DATE,
    gender VARCHAR(10) CHECK (gender IN ('Male', 'Female', 'Other')),
    marital_status VARCHAR(20) CHECK (marital_status IN ('Single', 'Married', 'Divorced', 'Widowed')),
    nic_number VARCHAR(20) UNIQUE,
    passport_number VARCHAR(20),
    personal_email VARCHAR(100),
    company_email VARCHAR(100),
    mobile_phone VARCHAR(20),
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    permanent_address TEXT,
    current_address TEXT,
    department_id UUID REFERENCES departments(id),
    designation_id UUID REFERENCES designations(id),
    employment_type VARCHAR(20) DEFAULT 'Permanent' CHECK (employment_type IN ('Permanent', 'Contract', 'Probation', 'Intern', 'Part-Time')),
    date_of_joining DATE NOT NULL,
    date_of_confirmation DATE,
    date_of_leaving DATE,
    notice_period_days INTEGER DEFAULT 30,
    salary_mode VARCHAR(20) DEFAULT 'Bank' CHECK (salary_mode IN ('Bank', 'Cash', 'Cheque')),
    bank_name VARCHAR(100),
    bank_branch VARCHAR(100),
    bank_account_no VARCHAR(50),
    epf_number VARCHAR(20),
    etf_number VARCHAR(20),
    status VARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Inactive', 'Left', 'Suspended')),
    user_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES profiles(id)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_dept_manager'
    ) THEN
        ALTER TABLE departments 
        ADD CONSTRAINT fk_dept_manager 
        FOREIGN KEY (manager_id) REFERENCES employees(id) 
        ON DELETE SET NULL;
    END IF;
END $$;

-- =====================================================
-- PART 2: SALARY COMPONENTS & STRUCTURES
-- =====================================================

CREATE TABLE IF NOT EXISTS salary_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    component_type VARCHAR(20) NOT NULL CHECK (component_type IN ('Earning', 'Deduction')),
    description TEXT,
    amount_based_on VARCHAR(20) DEFAULT 'Formula' CHECK (amount_based_on IN ('Fixed', 'Formula', 'Percentage')),
    formula TEXT,
    percentage DECIMAL(5,2),
    depends_on_component_id UUID REFERENCES salary_components(id),
    expense_account VARCHAR(50),
    payable_account VARCHAR(50),
    is_tax_applicable BOOLEAN DEFAULT false,
    is_flexible_benefit BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    is_epf_applicable BOOLEAN DEFAULT true,
    is_etf_applicable BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS salary_structures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    employment_type VARCHAR(20),
    department_id UUID REFERENCES departments(id),
    designation_id UUID REFERENCES designations(id),
    base_amount DECIMAL(15,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS salary_structure_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    salary_structure_id UUID REFERENCES salary_structures(id) ON DELETE CASCADE,
    salary_component_id UUID REFERENCES salary_components(id) ON DELETE CASCADE,
    default_amount DECIMAL(15,2),
    formula_override TEXT,
    idx INTEGER DEFAULT 0,
    UNIQUE(salary_structure_id, salary_component_id)
);

CREATE TABLE IF NOT EXISTS employee_salary_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    salary_structure_id UUID REFERENCES salary_structures(id),
    base_amount DECIMAL(15,2) NOT NULL,
    from_date DATE NOT NULL,
    to_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, from_date)
);

-- =====================================================
-- PART 3: PAYROLL PROCESSING
-- =====================================================

CREATE TABLE IF NOT EXISTS payroll_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    payroll_month INTEGER NOT NULL CHECK (payroll_month BETWEEN 1 AND 12),
    payroll_year INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    department_id UUID REFERENCES departments(id),
    designation_id UUID REFERENCES designations(id),
    status VARCHAR(20) DEFAULT 'Draft' CHECK (status IN ('Draft', 'Submitted', 'Approved', 'Cancelled')),
    total_employees INTEGER DEFAULT 0,
    total_gross_pay DECIMAL(15,2) DEFAULT 0,
    total_deductions DECIMAL(15,2) DEFAULT 0,
    total_net_pay DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES profiles(id),
    approved_by UUID REFERENCES profiles(id)
);

CREATE TABLE IF NOT EXISTS salary_slips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    payroll_entry_id UUID REFERENCES payroll_entries(id),
    employee_id UUID REFERENCES employees(id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_working_days INTEGER DEFAULT 26,
    payment_days DECIMAL(5,2) DEFAULT 26,
    leave_without_pay_days DECIMAL(5,2) DEFAULT 0,
    absent_days DECIMAL(5,2) DEFAULT 0,
    gross_pay DECIMAL(15,2) DEFAULT 0,
    total_deduction DECIMAL(15,2) DEFAULT 0,
    net_pay DECIMAL(15,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'Draft' CHECK (status IN ('Draft', 'Submitted', 'Paid', 'Cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS salary_slip_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    salary_slip_id UUID REFERENCES salary_slips(id) ON DELETE CASCADE,
    salary_component_id UUID REFERENCES salary_components(id),
    component_type VARCHAR(20) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    idx INTEGER DEFAULT 0
);

-- =====================================================
-- PART 4: SHIFT MANAGEMENT & ATTENDANCE
-- =====================================================

CREATE TABLE IF NOT EXISTS shift_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    late_entry_grace INTEGER DEFAULT 15,
    early_exit_grace INTEGER DEFAULT 15,
    working_hours DECIMAL(4,2) DEFAULT 8,
    enable_auto_ot BOOLEAN DEFAULT false,
    ot_start_after_hours DECIMAL(4,2) DEFAULT 8,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shift_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    shift_type_id UUID REFERENCES shift_types(id),
    from_date DATE NOT NULL,
    to_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    check_in_time TIMESTAMP WITH TIME ZONE,
    check_out_time TIMESTAMP WITH TIME ZONE,
    shift_type_id UUID REFERENCES shift_types(id),
    status VARCHAR(20) DEFAULT 'Present' CHECK (status IN ('Present', 'Absent', 'Half Day', 'On Leave', 'Holiday', 'Weekend')),
    working_hours DECIMAL(5,2),
    overtime_hours DECIMAL(5,2) DEFAULT 0,
    late_entry_minutes INTEGER DEFAULT 0,
    early_exit_minutes INTEGER DEFAULT 0,
    attendance_source VARCHAR(20) DEFAULT 'Manual' CHECK (attendance_source IN ('Manual', 'Biometric', 'Mobile', 'Auto')),
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, attendance_date)
);

CREATE TABLE IF NOT EXISTS attendance_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    reason TEXT NOT NULL,
    check_in_time TIME,
    check_out_time TIME,
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    approved_by UUID REFERENCES profiles(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- PART 5: LEAVE MANAGEMENT
-- =====================================================

CREATE TABLE IF NOT EXISTS leave_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    max_leaves_allowed INTEGER NOT NULL,
    max_continuous_days INTEGER,
    is_carry_forward BOOLEAN DEFAULT false,
    max_carry_forward_days INTEGER DEFAULT 0,
    is_encashable BOOLEAN DEFAULT false,
    encashment_threshold INTEGER,
    is_earned_leave BOOLEAN DEFAULT false,
    earned_leave_frequency VARCHAR(20),
    is_without_pay BOOLEAN DEFAULT false,
    include_holidays BOOLEAN DEFAULT false,
    is_compensatory BOOLEAN DEFAULT false,
    applicable_gender VARCHAR(10),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS leave_allocations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    leave_type_id UUID REFERENCES leave_types(id),
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    new_leaves_allocated DECIMAL(5,2) NOT NULL,
    carry_forwarded_leaves DECIMAL(5,2) DEFAULT 0,
    leaves_taken DECIMAL(5,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, leave_type_id, from_date)
);

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
    status VARCHAR(20) DEFAULT 'Draft' CHECK (status IN ('Draft', 'Pending HR Officer', 'Pending HR Manager', 'Approved', 'Rejected', 'Cancelled')),
    hr_officer_id UUID REFERENCES profiles(id),
    hr_officer_approved_at TIMESTAMP WITH TIME ZONE,
    hr_manager_id UUID REFERENCES profiles(id),
    hr_manager_approved_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- PART 6: BENEFITS MANAGEMENT
-- =====================================================

CREATE TABLE IF NOT EXISTS benefit_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    max_benefit_amount DECIMAL(15,2),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS benefit_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    benefit_type_id UUID REFERENCES benefit_types(id),
    claim_date DATE NOT NULL,
    claimed_amount DECIMAL(15,2) NOT NULL,
    approved_amount DECIMAL(15,2),
    attachments TEXT[],
    description TEXT,
    status VARCHAR(20) DEFAULT 'Draft' CHECK (status IN ('Draft', 'Pending', 'Approved', 'Rejected', 'Paid')),
    approved_by UUID REFERENCES profiles(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- PART 7: SEED DATA
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

INSERT INTO shift_types (code, name, start_time, end_time, working_hours, late_entry_grace, early_exit_grace) VALUES
('DAY', 'Day Shift', '08:00:00', '17:00:00', 8, 15, 15),
('NIGHT', 'Night Shift', '20:00:00', '05:00:00', 8, 15, 15),
('MORNING', 'Morning Shift', '06:00:00', '14:00:00', 8, 10, 10),
('EVENING', 'Evening Shift', '14:00:00', '22:00:00', 8, 10, 10)
ON CONFLICT (code) DO NOTHING;

INSERT INTO leave_types (code, name, max_leaves_allowed, is_carry_forward, max_carry_forward_days, is_earned_leave, is_without_pay, applicable_gender) VALUES
('CL', 'Casual Leave', 7, false, 0, false, false, NULL),
('ML', 'Medical Leave', 14, false, 0, false, false, NULL),
('AL', 'Annual Leave', 14, true, 7, true, false, NULL),
('MAT', 'Maternity Leave', 84, false, 0, false, false, 'Female'),
('PAT', 'Paternity Leave', 3, false, 0, false, false, 'Male'),
('LWP', 'Leave Without Pay', 365, false, 0, false, true, NULL)
ON CONFLICT (code) DO NOTHING;

INSERT INTO benefit_types (code, name, description, max_benefit_amount) VALUES
('MED_INS', 'Medical Insurance', 'Annual medical insurance reimbursement', 50000),
('TRANS_SUB', 'Transport Subsidy', 'Monthly transport allowance claim', 5000),
('MEAL_SUB', 'Meal Subsidy', 'Daily meal allowance claim', 200),
('PHONE', 'Communication Allowance', 'Mobile phone bill reimbursement', 2500)
ON CONFLICT (code) DO NOTHING;

INSERT INTO departments (code, name, cost_center) VALUES
('PROD', 'Production', 'CC-PROD'),
('HR', 'Human Resources', 'CC-HR'),
('FIN', 'Finance', 'CC-FIN'),
('ADMIN', 'Administration', 'CC-ADMIN'),
('IT', 'Information Technology', 'CC-IT')
ON CONFLICT (code) DO NOTHING;

INSERT INTO designations (code, name) VALUES
('DIR', 'Director'),
('MGR', 'Manager'),
('SUPV', 'Supervisor'),
('OFF', 'Officer'),
('OPER', 'Operator'),
('HELPER', 'Helper')
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- PART 8: INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(status);
CREATE INDEX IF NOT EXISTS idx_attendance_employee_date ON attendance(employee_id, attendance_date);
CREATE INDEX IF NOT EXISTS idx_leave_applications_employee ON leave_applications(employee_id);
CREATE INDEX IF NOT EXISTS idx_leave_applications_status ON leave_applications(status);
CREATE INDEX IF NOT EXISTS idx_salary_slips_employee ON salary_slips(employee_id);
CREATE INDEX IF NOT EXISTS idx_salary_slips_payroll ON salary_slips(payroll_entry_id);

-- =====================================================
-- PART 9: RPC FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION generate_employee_code()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    next_num INTEGER;
    new_code TEXT;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(employee_code FROM 4) AS INTEGER)), 0) + 1
    INTO next_num FROM employees WHERE employee_code LIKE 'EMP%';
    new_code := 'EMP' || LPAD(next_num::TEXT, 4, '0');
    RETURN new_code;
END;
$$;

CREATE OR REPLACE FUNCTION get_hr_dashboard_stats()
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_total_employees INTEGER;
    v_active_employees INTEGER;
    v_pending_leaves INTEGER;
    v_present_today INTEGER;
    v_absent_today INTEGER;
    v_last_payroll_total DECIMAL(15,2);
BEGIN
    SELECT COUNT(*) INTO v_total_employees FROM employees;
    SELECT COUNT(*) INTO v_active_employees FROM employees WHERE status = 'Active';
    SELECT COUNT(*) INTO v_pending_leaves FROM leave_applications WHERE status IN ('Pending HR Officer', 'Pending HR Manager');
    SELECT COUNT(*) INTO v_present_today FROM attendance WHERE attendance_date = CURRENT_DATE AND status = 'Present';
    SELECT COUNT(*) INTO v_absent_today FROM employees e WHERE e.status = 'Active'
        AND NOT EXISTS (SELECT 1 FROM attendance a WHERE a.employee_id = e.id AND a.attendance_date = CURRENT_DATE);
    SELECT COALESCE(total_net_pay, 0) INTO v_last_payroll_total FROM payroll_entries
        WHERE status = 'Approved' ORDER BY payroll_year DESC, payroll_month DESC LIMIT 1;
    
    RETURN json_build_object(
        'total_employees', v_total_employees,
        'active_employees', v_active_employees,
        'pending_leaves', v_pending_leaves,
        'present_today', v_present_today,
        'absent_today', v_absent_today,
        'last_payroll_total', v_last_payroll_total
    );
END;
$$;

-- =====================================================
-- PART 10: PERMISSIONS (Simple - No RLS)
-- =====================================================

GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION generate_employee_code() TO authenticated;
GRANT EXECUTE ON FUNCTION get_hr_dashboard_stats() TO authenticated;

-- =====================================================
-- ✅ SUCCESS MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  ✅ SEVEN WAVES HRMS MODULE INSTALLED SUCCESSFULLY!       ║';
    RAISE NOTICE '╠═══════════════════════════════════════════════════════════╣';
    RAISE NOTICE '║  📊 Tables: employees, departments, designations          ║';
    RAISE NOTICE '║  💰 Payroll: salary_components, salary_slips, payroll     ║';
    RAISE NOTICE '║  ⏰ Attendance: shift_types, attendance                    ║';
    RAISE NOTICE '║  🏖️ Leave: leave_types, leave_applications                ║';
    RAISE NOTICE '║  🎁 Benefits: benefit_types, benefit_claims               ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
END $$;
