-- =================================================================
-- MIGRATION 046: PERFORMANCE FIX & RECURSION REMOVAL
-- =================================================================

-- 1. DISABLE RLS ON STATIC CONFIG TABLES
--    These tables are read-heavy and rarely change. RLS overhead is unnecessary here
--    if we control writes via admin-only functions.
ALTER TABLE roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions DISABLE ROW LEVEL SECURITY;

-- Grant read access to everyone authenticated
GRANT SELECT ON roles TO authenticated;
GRANT SELECT ON permissions TO authenticated;
GRANT SELECT ON role_permissions TO authenticated;


-- 2. FIX USER_ROLES RLS (Potential Loop Source)
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "User Roles Access" ON user_roles;

-- Simple policy: Users see their own roles. Admins see all (via JWT check ONLY).
CREATE POLICY "User Roles Access" ON user_roles
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin')
    );


-- 3. OPTIMIZE PROFILES RLS (Strict Non-Recursion)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles Read Access" ON profiles;
DROP POLICY IF EXISTS "Profiles Update Access" ON profiles;
DROP POLICY IF EXISTS "Profiles Insert Access" ON profiles;

-- A. FAST READ: No sub-queries allowed.
CREATE POLICY "Profiles Fast Read" ON profiles
    FOR SELECT TO authenticated
    USING (
        id = auth.uid() 
        OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin', 'hr_manager')
    );

-- B. UPDATE: No sub-queries.
CREATE POLICY "Profiles Fast Update" ON profiles
    FOR UPDATE TO authenticated
    USING ( id = auth.uid() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'admin') )
    WITH CHECK ( id = auth.uid() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'admin') );

-- C. INSERT: No sub-queries.
CREATE POLICY "Profiles Fast Insert" ON profiles
    FOR INSERT TO authenticated
    WITH CHECK ( id = auth.uid() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'admin') );


-- 4. FIX EMPLOYEES RLS (Remove Profile Lookup)
--    The previous policy queried 'profiles' table. We replace it with JWT check.
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Employees Read All Authenticated" ON employees;
-- Allow ALL authenticated users to read employees (needed for dropdowns/selectors)
-- This is low risk for this internal ERP and solves the "User Code" generation block.
CREATE POLICY "Employees Read Global" ON employees
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Employees Insert HR/Admin" ON employees;
CREATE POLICY "Employees Insert HR/Admin" ON employees
    FOR INSERT TO authenticated
    WITH CHECK (
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin', 'hr_manager')
    );

DROP POLICY IF EXISTS "Employees Update HR/Admin" ON employees;
CREATE POLICY "Employees Update HR/Admin" ON employees
    FOR UPDATE TO authenticated
    USING (
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin', 'hr_manager')
    );


-- 5. ENSURE AUTH.USERS IS CLEAN (Again)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_signup ON auth.users;


-- 6. RELOAD SCHEMA
NOTIFY pgrst, 'reload schema';
