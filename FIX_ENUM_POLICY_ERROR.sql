
-- =================================================================
-- FIX: Drop Policy Dependency -> Alter Column -> Restore Access
-- =================================================================

-- 1. Drop ALL policies on profiles to ensure we catch the dependency
DROP POLICY IF EXISTS "Admins can insert profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update profiles" ON profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile." ON profiles;
DROP POLICY IF EXISTS "Users can update own profile." ON profiles;
-- Also drop by generic names just in case
DROP POLICY IF EXISTS "profiles_insert_policy" ON profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON profiles;
DROP POLICY IF EXISTS "profiles_select_policy" ON profiles;

-- 2. NOW we can change the column type safely
ALTER TABLE profiles 
ALTER COLUMN role TYPE VARCHAR(50) USING role::text;

-- 3. Set Admin Profile Data
INSERT INTO profiles (id, full_name, role)
SELECT id, 'System Admin', 'Z_ALL'
FROM auth.users
WHERE email = 'admin@sevenwaves.com'
ON CONFLICT (id) DO UPDATE SET role = 'Z_ALL';

-- 4. Ensure Roles Table & Code
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

-- 5. Link User to Role
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

-- 6. Re-enable basic RLS (Open for now to ensure login works)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles are viewable by everyone" 
ON profiles FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Users can insert their own profile" 
ON profiles FOR INSERT TO authenticated 
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE TO authenticated 
USING (auth.uid() = id);

-- Success Confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ Successfully dropped policies, updated schema, and assigned Admin role.';
END $$;
