
-- =================================================================
-- FIX: Allow New Role Codes (Removing Enum Restriction)
-- =================================================================

-- 1. Convert the 'role' column from ENUM to TEXT
-- This fixes the "invalid input value" error by allowing any string like 'Z_ALL'
ALTER TABLE profiles 
ALTER COLUMN role TYPE VARCHAR(50) USING role::text;

-- 2. Create the Admin Profile again
INSERT INTO profiles (id, full_name, role)
SELECT id, 'System Admin', 'Z_ALL'
FROM auth.users
WHERE email = 'admin@sevenwaves.com'
ON CONFLICT (id) DO UPDATE SET role = 'Z_ALL';

-- 3. Ensure Roles Table Exists & Populate
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

-- 4. Assign Permission Role (Link Table)
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

-- Success Confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ Database schema updated to accept Z_ALL roles.';
END $$;
