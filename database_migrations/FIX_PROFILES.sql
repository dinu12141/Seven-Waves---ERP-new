-- =================================================================
-- SIMPLIFIED FIX: Just Grant Permissions on HRMS Tables
-- Run this in Supabase SQL Editor
-- =================================================================

-- 1. Add role column to profiles if it doesn't exist (safe)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'role'
    ) THEN
        ALTER TABLE profiles ADD COLUMN role VARCHAR(20) DEFAULT 'admin';
    END IF;
END $$;

-- 2. Grant all permissions on HRMS tables to authenticated users
GRANT ALL ON employees TO authenticated;
GRANT ALL ON departments TO authenticated;
GRANT ALL ON designations TO authenticated;
GRANT ALL ON salary_components TO authenticated;
GRANT ALL ON salary_structures TO authenticated;
GRANT ALL ON salary_structure_components TO authenticated;
GRANT ALL ON employee_salary_assignments TO authenticated;
GRANT ALL ON payroll_entries TO authenticated;
GRANT ALL ON salary_slips TO authenticated;
GRANT ALL ON salary_slip_details TO authenticated;
GRANT ALL ON shift_types TO authenticated;
GRANT ALL ON shift_assignments TO authenticated;
GRANT ALL ON attendance TO authenticated;
GRANT ALL ON attendance_requests TO authenticated;
GRANT ALL ON leave_types TO authenticated;
GRANT ALL ON leave_allocations TO authenticated;
GRANT ALL ON leave_applications TO authenticated;
GRANT ALL ON benefit_types TO authenticated;
GRANT ALL ON benefit_claims TO authenticated;

-- 3. Also grant on sequences (for auto-increment)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Permissions granted on all HRMS tables!';
    RAISE NOTICE 'You can now access employees, attendance, leave, and payroll data.';
END $$;
