-- =================================================================
-- MIGRATION 042: FIX RLS FOR EMPLOYEES & CONFIG TABLES
-- =================================================================

-- 1. EMPLOYEES: Enable RLS and Allow Read
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Employees Read All Authenticated" ON employees;
CREATE POLICY "Employees Read All Authenticated" ON employees
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Employees Insert HR/Admin" ON employees;
CREATE POLICY "Employees Insert HR/Admin" ON employees
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'Z_HR_MANAGER', 'Z_ALL') OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'director'))
    );

DROP POLICY IF EXISTS "Employees Update HR/Admin" ON employees;
CREATE POLICY "Employees Update HR/Admin" ON employees
    FOR UPDATE TO authenticated
    USING (
        auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'Z_HR_MANAGER', 'Z_ALL') OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'director'))
    )
    WITH CHECK (
        auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'Z_HR_MANAGER', 'Z_ALL') OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'director'))
    );

DROP POLICY IF EXISTS "Employees Delete HR/Admin" ON employees;
CREATE POLICY "Employees Delete HR/Admin" ON employees
    FOR DELETE TO authenticated
    USING (
        auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'Z_HR_MANAGER', 'Z_ALL') OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'director'))
    );

-- 2. DEPARTMENTS & DESIGNATIONS: Allow Read All
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE designations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Departments Read All" ON departments;
CREATE POLICY "Departments Read All" ON departments FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Designations Read All" ON designations;
CREATE POLICY "Designations Read All" ON designations FOR SELECT TO authenticated USING (true);


-- 3. SALARY STRUCTURES: Read HR/Admin only
ALTER TABLE salary_structures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Salary Struct Read HR/Admin" ON salary_structures;
CREATE POLICY "Salary Struct Read HR/Admin" ON salary_structures
    FOR SELECT TO authenticated
    USING (
        auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'Z_HR_MANAGER', 'Z_ALL', 'director', 'finance_manager') OR
         EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'director', 'finance_manager'))
    );

-- Reload schema
NOTIFY pgrst, 'reload schema';
