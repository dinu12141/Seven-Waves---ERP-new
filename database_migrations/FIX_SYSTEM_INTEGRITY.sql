-- =================================================================
-- FIX SYSTEM INTEGRITY (RBAC, Profiles, Functions)
-- Run this to fix 404 and 400 errors
-- =================================================================

-- 1. Ensure PROFILES has ROLE column
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'role') THEN
        ALTER TABLE profiles ADD COLUMN role VARCHAR(50) DEFAULT 'Z_SALES_STAFF';
    END IF;
END $$;

-- 2. Create RBAC Tables if missing
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    description TEXT,
    module VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(resource, action)
);

CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES auth.users(id),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, role_id)
);

CREATE TABLE IF NOT EXISTS user_warehouse_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    access_level VARCHAR(20) DEFAULT 'read',
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, warehouse_id)
);

-- 3. Seed Roles
INSERT INTO roles (code, name, description, is_system_role) VALUES
('Z_ALL', 'Administrator', 'Full system access', true),
('Z_STOCK_MGR', 'Store Manager', 'Inventory management', true),
('Z_SALES_STAFF', 'Cashier/Waiter', 'Sales access', true)
ON CONFLICT (code) DO NOTHING;

-- 4. Re-create RPC Functions (Fixes 404s)

-- get_user_permissions
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id UUID)
RETURNS TABLE (resource VARCHAR, action VARCHAR, module VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT p.resource, p.action, p.module
    FROM permissions p
    INNER JOIN role_permissions rp ON rp.permission_id = p.id
    INNER JOIN user_roles ur ON ur.role_id = rp.role_id
    WHERE ur.user_id = p_user_id AND ur.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- has_permission
CREATE OR REPLACE FUNCTION has_permission(p_user_id UUID, p_resource VARCHAR, p_action VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE has_perm BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM permissions p
        INNER JOIN role_permissions rp ON rp.permission_id = p.id
        INNER JOIN user_roles ur ON ur.role_id = rp.role_id
        WHERE ur.user_id = p_user_id AND ur.is_active = true AND p.resource = p_resource AND p.action = p_action
    ) INTO has_perm;
    RETURN has_perm;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_user_warehouses
CREATE OR REPLACE FUNCTION get_user_warehouses(p_user_id UUID)
RETURNS TABLE (warehouse_id UUID, warehouse_code VARCHAR, warehouse_name VARCHAR, access_level VARCHAR) AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = p_user_id AND r.code = 'Z_ALL') THEN
        RETURN QUERY SELECT w.id, w.code, w.name, 'full'::VARCHAR FROM warehouses w WHERE w.is_active = true;
    ELSE
        RETURN QUERY SELECT w.id, w.code, w.name, uwa.access_level FROM user_warehouse_access uwa JOIN warehouses w ON w.id = uwa.warehouse_id WHERE uwa.user_id = p_user_id AND w.is_active = true;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Open Permissions for Profiles (Fixes 400/406)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
CREATE POLICY "Profiles are viewable by everyone" ON profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
CREATE POLICY "Users can insert their own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- 6. Grant Permissions
GRANT EXECUTE ON FUNCTION get_user_permissions TO authenticated;
GRANT EXECUTE ON FUNCTION has_permission TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_warehouses TO authenticated;
GRANT ALL ON profiles TO authenticated;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ System Integrity Fixed! RBAC functions and Profile permissions restored.';
END $$;
