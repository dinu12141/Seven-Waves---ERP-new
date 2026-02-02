-- =================================================================
-- SEVEN WAVES ERP - HRMS RPC FUNCTIONS
-- SAP Business One HANA Standards Compliant
-- =================================================================

-- =====================================================
-- 1. GENERATE EMPLOYEE CODE
-- =====================================================
CREATE OR REPLACE FUNCTION generate_employee_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    next_num INTEGER;
    new_code TEXT;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(employee_code FROM 4) AS INTEGER)), 0) + 1
    INTO next_num
    FROM employees
    WHERE employee_code LIKE 'EMP%';
    
    new_code := 'EMP' || LPAD(next_num::TEXT, 4, '0');
    RETURN new_code;
END;
$$;

-- =====================================================
-- 2. PROCESS PAYROLL ENTRY (Batch Processing)
-- =====================================================
CREATE OR REPLACE FUNCTION process_payroll_entry(
    p_payroll_month INTEGER,
    p_payroll_year INTEGER,
    p_department_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_payroll_entry_id UUID;
    v_doc_number TEXT;
    v_start_date DATE;
    v_end_date DATE;
    v_employee RECORD;
    v_salary_assignment RECORD;
    v_component RECORD;
    v_slip_id UUID;
    v_slip_doc_number TEXT;
    v_gross_pay DECIMAL(15,2);
    v_total_deduction DECIMAL(15,2);
    v_base_amount DECIMAL(15,2);
    v_component_amount DECIMAL(15,2);
    v_total_employees INTEGER := 0;
    v_total_gross DECIMAL(15,2) := 0;
    v_total_deductions DECIMAL(15,2) := 0;
    v_total_net DECIMAL(15,2) := 0;
BEGIN
    -- Calculate period dates
    v_start_date := make_date(p_payroll_year, p_payroll_month, 1);
    v_end_date := (v_start_date + INTERVAL '1 month - 1 day')::DATE;
    
    -- Generate doc number
    v_doc_number := 'PAY-' || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(FLOOR(RANDOM()*1000)::TEXT, 3, '0');
    
    -- Create Payroll Entry (Header)
    INSERT INTO payroll_entries (
        doc_number, payroll_month, payroll_year, start_date, end_date,
        department_id, status, created_by
    )
    VALUES (
        v_doc_number, p_payroll_month, p_payroll_year, v_start_date, v_end_date,
        p_department_id, 'Draft', p_user_id
    )
    RETURNING id INTO v_payroll_entry_id;
    
    -- Loop through active employees
    FOR v_employee IN
        SELECT e.* 
        FROM employees e
        WHERE e.status = 'Active'
        AND (p_department_id IS NULL OR e.department_id = p_department_id)
    LOOP
        v_total_employees := v_total_employees + 1;
        v_gross_pay := 0;
        v_total_deduction := 0;
        
        -- Get salary assignment
        SELECT * INTO v_salary_assignment
        FROM employee_salary_assignments
        WHERE employee_id = v_employee.id
        AND is_active = true
        AND from_date <= v_end_date
        AND (to_date IS NULL OR to_date >= v_start_date)
        ORDER BY from_date DESC
        LIMIT 1;
        
        IF v_salary_assignment IS NULL THEN
            CONTINUE; -- Skip employees without salary assignment
        END IF;
        
        v_base_amount := v_salary_assignment.base_amount;
        
        -- Generate Salary Slip doc number
        v_slip_doc_number := 'SLIP-' || TO_CHAR(NOW(), 'YYYYMM') || '-' || v_employee.employee_code;
        
        -- Create Salary Slip
        INSERT INTO salary_slips (
            doc_number, payroll_entry_id, employee_id,
            start_date, end_date, status
        )
        VALUES (
            v_slip_doc_number, v_payroll_entry_id, v_employee.id,
            v_start_date, v_end_date, 'Draft'
        )
        RETURNING id INTO v_slip_id;
        
        -- Process Salary Components
        FOR v_component IN
            SELECT sc.*, ssc.default_amount, ssc.formula_override
            FROM salary_structure_components ssc
            JOIN salary_components sc ON sc.id = ssc.salary_component_id
            WHERE ssc.salary_structure_id = v_salary_assignment.salary_structure_id
            ORDER BY ssc.idx
        LOOP
            -- Calculate component amount
            CASE v_component.amount_based_on
                WHEN 'Fixed' THEN
                    v_component_amount := COALESCE(v_component.default_amount, 0);
                WHEN 'Formula' THEN
                    -- Simple formula evaluation (base * percentage)
                    IF v_component.formula LIKE '%* 0.%' THEN
                        v_component_amount := v_base_amount * 
                            CAST(SUBSTRING(v_component.formula FROM '0\.[0-9]+') AS DECIMAL);
                    ELSE
                        v_component_amount := v_base_amount; -- Default to base
                    END IF;
                WHEN 'Percentage' THEN
                    v_component_amount := v_base_amount * (v_component.percentage / 100);
                ELSE
                    v_component_amount := 0;
            END CASE;
            
            -- Insert detail line
            INSERT INTO salary_slip_details (
                salary_slip_id, salary_component_id,
                component_type, amount, idx
            )
            VALUES (
                v_slip_id, v_component.id,
                v_component.component_type, v_component_amount, v_component.idx
            );
            
            -- Accumulate totals
            IF v_component.component_type = 'Earning' THEN
                v_gross_pay := v_gross_pay + v_component_amount;
            ELSE
                v_total_deduction := v_total_deduction + v_component_amount;
            END IF;
        END LOOP;
        
        -- Update salary slip with totals
        UPDATE salary_slips
        SET gross_pay = v_gross_pay,
            total_deduction = v_total_deduction,
            net_pay = v_gross_pay - v_total_deduction
        WHERE id = v_slip_id;
        
        -- Accumulate payroll totals
        v_total_gross := v_total_gross + v_gross_pay;
        v_total_deductions := v_total_deductions + v_total_deduction;
        v_total_net := v_total_net + (v_gross_pay - v_total_deduction);
    END LOOP;
    
    -- Update payroll entry with totals
    UPDATE payroll_entries
    SET total_employees = v_total_employees,
        total_gross_pay = v_total_gross,
        total_deductions = v_total_deductions,
        total_net_pay = v_total_net
    WHERE id = v_payroll_entry_id;
    
    RETURN json_build_object(
        'success', true,
        'payroll_entry_id', v_payroll_entry_id,
        'doc_number', v_doc_number,
        'total_employees', v_total_employees,
        'total_gross_pay', v_total_gross,
        'total_net_pay', v_total_net
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

-- =====================================================
-- 3. APPLY LEAVE (With Workflow)
-- =====================================================
CREATE OR REPLACE FUNCTION apply_leave(
    p_employee_id UUID,
    p_leave_type_id UUID,
    p_from_date DATE,
    p_to_date DATE,
    p_reason TEXT DEFAULT NULL,
    p_half_day BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_leave_id UUID;
    v_doc_number TEXT;
    v_total_days DECIMAL(5,2);
    v_leave_balance DECIMAL(5,2);
    v_leave_type RECORD;
BEGIN
    -- Get leave type
    SELECT * INTO v_leave_type FROM leave_types WHERE id = p_leave_type_id;
    
    IF v_leave_type IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Leave type not found');
    END IF;
    
    -- Calculate total days
    v_total_days := (p_to_date - p_from_date + 1);
    IF p_half_day THEN
        v_total_days := 0.5;
    END IF;
    
    -- Check leave balance (skip for LWP)
    IF NOT v_leave_type.is_without_pay THEN
        SELECT leaves_balance INTO v_leave_balance
        FROM leave_allocations
        WHERE employee_id = p_employee_id
        AND leave_type_id = p_leave_type_id
        AND from_date <= p_from_date
        AND to_date >= p_to_date;
        
        IF v_leave_balance IS NULL OR v_leave_balance < v_total_days THEN
            RETURN json_build_object(
                'success', false, 
                'error', 'Insufficient leave balance. Available: ' || COALESCE(v_leave_balance, 0)
            );
        END IF;
    END IF;
    
    -- Generate doc number
    v_doc_number := 'LV-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM()*1000)::TEXT, 3, '0');
    
    -- Create leave application
    INSERT INTO leave_applications (
        doc_number, employee_id, leave_type_id,
        from_date, to_date, half_day,
        total_leave_days, reason, status
    )
    VALUES (
        v_doc_number, p_employee_id, p_leave_type_id,
        p_from_date, p_to_date, p_half_day,
        v_total_days, p_reason, 'Pending HR Officer'
    )
    RETURNING id INTO v_leave_id;
    
    RETURN json_build_object(
        'success', true,
        'leave_id', v_leave_id,
        'doc_number', v_doc_number,
        'total_days', v_total_days,
        'status', 'Pending HR Officer'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- =====================================================
-- 4. APPROVE LEAVE (Workflow Step)
-- =====================================================
CREATE OR REPLACE FUNCTION approve_leave(
    p_leave_id UUID,
    p_approver_id UUID,
    p_action VARCHAR(10), -- 'approve' or 'reject'
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_leave RECORD;
    v_approver_role TEXT;
    v_new_status TEXT;
BEGIN
    -- Get leave application
    SELECT * INTO v_leave FROM leave_applications WHERE id = p_leave_id;
    
    IF v_leave IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Leave application not found');
    END IF;
    
    -- Get approver role
    SELECT role INTO v_approver_role FROM profiles WHERE id = p_approver_id;
    
    -- Determine action based on current status and approver role
    IF p_action = 'reject' THEN
        v_new_status := 'Rejected';
        
        UPDATE leave_applications
        SET status = v_new_status,
            rejection_reason = p_rejection_reason
        WHERE id = p_leave_id;
    ELSE
        -- Approve based on role
        IF v_leave.status = 'Pending HR Officer' AND v_approver_role IN ('hr_officer', 'hr_manager', 'admin') THEN
            v_new_status := 'Pending HR Manager';
            
            UPDATE leave_applications
            SET status = v_new_status,
                hr_officer_id = p_approver_id,
                hr_officer_approved_at = NOW()
            WHERE id = p_leave_id;
            
        ELSIF v_leave.status = 'Pending HR Manager' AND v_approver_role IN ('hr_manager', 'admin') THEN
            v_new_status := 'Approved';
            
            UPDATE leave_applications
            SET status = v_new_status,
                hr_manager_id = p_approver_id,
                hr_manager_approved_at = NOW()
            WHERE id = p_leave_id;
            
            -- Deduct from leave balance
            UPDATE leave_allocations
            SET leaves_taken = leaves_taken + v_leave.total_leave_days
            WHERE employee_id = v_leave.employee_id
            AND leave_type_id = v_leave.leave_type_id
            AND from_date <= v_leave.from_date
            AND to_date >= v_leave.to_date;
        ELSE
            RETURN json_build_object(
                'success', false, 
                'error', 'You do not have permission to approve this leave application'
            );
        END IF;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'leave_id', p_leave_id,
        'new_status', v_new_status
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- =====================================================
-- 5. RECORD ATTENDANCE
-- =====================================================
CREATE OR REPLACE FUNCTION record_attendance(
    p_employee_id UUID,
    p_attendance_date DATE,
    p_check_in TIME DEFAULT NULL,
    p_check_out TIME DEFAULT NULL,
    p_source VARCHAR(20) DEFAULT 'Manual'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_attendance_id UUID;
    v_shift RECORD;
    v_working_hours DECIMAL(5,2);
    v_overtime_hours DECIMAL(5,2) := 0;
    v_late_minutes INTEGER := 0;
    v_status TEXT := 'Present';
BEGIN
    -- Get employee's shift
    SELECT st.* INTO v_shift
    FROM shift_assignments sa
    JOIN shift_types st ON st.id = sa.shift_type_id
    WHERE sa.employee_id = p_employee_id
    AND sa.is_active = true
    AND sa.from_date <= p_attendance_date
    AND (sa.to_date IS NULL OR sa.to_date >= p_attendance_date)
    LIMIT 1;
    
    -- Calculate working hours
    IF p_check_in IS NOT NULL AND p_check_out IS NOT NULL THEN
        v_working_hours := EXTRACT(EPOCH FROM (p_check_out - p_check_in)) / 3600;
        
        -- Calculate overtime
        IF v_shift IS NOT NULL AND v_working_hours > v_shift.working_hours THEN
            v_overtime_hours := v_working_hours - v_shift.working_hours;
        END IF;
        
        -- Calculate late entry
        IF v_shift IS NOT NULL AND p_check_in > v_shift.start_time THEN
            v_late_minutes := EXTRACT(EPOCH FROM (p_check_in - v_shift.start_time)) / 60;
            IF v_late_minutes > v_shift.late_entry_grace THEN
                v_status := 'Half Day'; -- Late beyond grace
            END IF;
        END IF;
    ELSIF p_check_in IS NOT NULL THEN
        v_status := 'Present'; -- Checked in but not out
    ELSE
        v_status := 'Absent';
    END IF;
    
    -- Insert or Update attendance
    INSERT INTO attendance (
        employee_id, attendance_date, check_in_time, check_out_time,
        shift_type_id, status, working_hours, overtime_hours,
        late_entry_minutes, attendance_source
    )
    VALUES (
        p_employee_id, p_attendance_date,
        p_attendance_date + p_check_in,
        CASE WHEN p_check_out IS NOT NULL THEN p_attendance_date + p_check_out ELSE NULL END,
        v_shift.id, v_status, v_working_hours, v_overtime_hours,
        v_late_minutes, p_source
    )
    ON CONFLICT (employee_id, attendance_date)
    DO UPDATE SET
        check_in_time = EXCLUDED.check_in_time,
        check_out_time = EXCLUDED.check_out_time,
        working_hours = EXCLUDED.working_hours,
        overtime_hours = EXCLUDED.overtime_hours,
        late_entry_minutes = EXCLUDED.late_entry_minutes,
        attendance_source = EXCLUDED.attendance_source
    RETURNING id INTO v_attendance_id;
    
    RETURN json_build_object(
        'success', true,
        'attendance_id', v_attendance_id,
        'status', v_status,
        'working_hours', v_working_hours,
        'overtime_hours', v_overtime_hours
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- =====================================================
-- 6. GET DASHBOARD STATS (Director View)
-- =====================================================
CREATE OR REPLACE FUNCTION get_hr_dashboard_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_employees INTEGER;
    v_active_employees INTEGER;
    v_pending_leaves INTEGER;
    v_present_today INTEGER;
    v_absent_today INTEGER;
    v_last_payroll_total DECIMAL(15,2);
BEGIN
    -- Employee counts
    SELECT COUNT(*) INTO v_total_employees FROM employees;
    SELECT COUNT(*) INTO v_active_employees FROM employees WHERE status = 'Active';
    
    -- Pending leaves
    SELECT COUNT(*) INTO v_pending_leaves 
    FROM leave_applications 
    WHERE status IN ('Pending HR Officer', 'Pending HR Manager');
    
    -- Today's attendance
    SELECT COUNT(*) INTO v_present_today 
    FROM attendance 
    WHERE attendance_date = CURRENT_DATE AND status = 'Present';
    
    SELECT COUNT(*) INTO v_absent_today
    FROM employees e
    WHERE e.status = 'Active'
    AND NOT EXISTS (
        SELECT 1 FROM attendance a 
        WHERE a.employee_id = e.id 
        AND a.attendance_date = CURRENT_DATE
    );
    
    -- Last payroll total
    SELECT COALESCE(total_net_pay, 0) INTO v_last_payroll_total
    FROM payroll_entries
    WHERE status = 'Approved'
    ORDER BY payroll_year DESC, payroll_month DESC
    LIMIT 1;
    
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
-- GRANT EXECUTE PERMISSIONS
-- =====================================================
GRANT EXECUTE ON FUNCTION generate_employee_code() TO authenticated;
GRANT EXECUTE ON FUNCTION process_payroll_entry(INTEGER, INTEGER, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION apply_leave(UUID, UUID, DATE, DATE, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_leave(UUID, UUID, VARCHAR, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION record_attendance(UUID, DATE, TIME, TIME, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION get_hr_dashboard_stats() TO authenticated;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ HRMS RPC Functions installed successfully!';
    RAISE NOTICE '📦 Functions: generate_employee_code, process_payroll_entry, apply_leave, approve_leave, record_attendance, get_hr_dashboard_stats';
END $$;
