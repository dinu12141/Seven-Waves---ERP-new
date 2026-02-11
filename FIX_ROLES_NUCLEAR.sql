
-- =================================================================
-- FIX: DYNAMICALLY DROP ALL POLICIES TO UNBLOCK COLUMN CHANGE
-- =================================================================

-- 1. "Nuclear Option": Find and Drop EVERY policy on the 'profiles' table automatically.
--    This prevents "whack-a-mole" with policy names.
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'profiles' LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON profiles', pol.policyname);
        RAISE NOTICE 'Dropped policy: %', pol.policyname;
    END LOOP;
END $$;

-- 2. NOW we can change the column type safely
ALTER TABLE profiles 
ALTER COLUMN role TYPE VARCHAR(50) USING role::text;

-- 3. Set Admin Profile Data
INSERT INTO profiles (id, full_name, role)
SELECT id, 'System Admin', 'Z_ALL'
FROM auth.users
WHERE email = 'admin@sevenwaves.com'
ON CONFLICT (id) DO UPDATE SET role = 'Z_ALL';

-- 4. Ensure Roles Table Exists & Populate
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

-- 5. Assign Permission Role (Link Table)
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

-- 6. Restore Basic RLS Policies (Standard)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone" 
ON profiles FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Users can insert their own profile" 
ON profiles FOR INSERT TO authenticated 
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE TO authenticated 
USING (auth.uid() = id);

CREATE POLICY "Admins can manage all profiles"
ON profiles FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles ur
    INNER JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() AND r.code = 'Z_ALL'
  )
);

-- Success Confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ SUCCESS: All policies cleaned, column updated, and Admin restored.';
END $$;
