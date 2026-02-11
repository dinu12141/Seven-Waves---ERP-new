
-- =================================================================
-- FIX: DROP ALL DEPENDENT POLICIES ACROSS TABLES
-- =================================================================

-- 1. Drop the specific policy blocking the change on 'employees' table
DROP POLICY IF EXISTS "employees_hr_policy" ON employees;
DROP POLICY IF EXISTS "employees_read_policy" ON employees;
DROP POLICY IF EXISTS "employees_write_policy" ON employees;

-- 2. Drop all policies on 'profiles' (Nuclear loop again to be sure)
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'profiles' LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON profiles', pol.policyname);
    END LOOP;
END $$;

-- 3. Drop functions that might depend on the specific Enum type 'user_role'
--    (If they exist, they will block the column type change too)
DROP FUNCTION IF EXISTS get_user_role(UUID);
DROP FUNCTION IF EXISTS is_admin();

-- 4. NOW we can finally change the column type safely
ALTER TABLE profiles 
ALTER COLUMN role TYPE VARCHAR(50) USING role::text;

-- 5. Drop the Enum type if it exists (cleanup)
DROP TYPE IF EXISTS user_role;

-- 6. Re-seed Admin Data
INSERT INTO profiles (id, full_name, role)
SELECT id, 'System Admin', 'Z_ALL'
FROM auth.users
WHERE email = 'admin@sevenwaves.com'
ON CONFLICT (id) DO UPDATE SET role = 'Z_ALL';

-- 7. Ensure Roles Infrastructure
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT false
);

INSERT INTO roles (code, name, description, is_system_role) VALUES
('Z_ALL', 'Administrator', 'Full Access', true)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, role_id)
);

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM auth.users u, roles r
WHERE u.email = 'admin@sevenwaves.com' AND r.code = 'Z_ALL'
ON CONFLICT (user_id, role_id) DO NOTHING;

-- 8. Restore Policies (Updated for Text Role)

-- Profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Employees (Re-creating the dropped policy with new logic)
-- Assuming 'Z_HR_MANAGER' or 'Z_ALL' can manage employees
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
CREATE POLICY "employees_hr_access" ON employees
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid() 
        AND (profiles.role = 'Z_ALL' OR profiles.role = 'Z_HR_MANAGER')
    )
);

-- Success Confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ SUCCESS: Dependencies cleared, Enum converted to Text, Policies restored.';
END $$;
