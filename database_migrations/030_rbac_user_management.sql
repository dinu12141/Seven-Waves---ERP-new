-- =================================================================
-- SEVEN WAVES ERP - RBAC USER MANAGEMENT MIGRATION
-- Migration 030: Granular per-user permissions & admin user creation
-- =================================================================

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 2. USER_PERMISSIONS TABLE (Per-user overrides)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    grant_type VARCHAR(10) NOT NULL DEFAULT 'allow' CHECK (grant_type IN ('allow', 'deny')),
    granted_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, permission_id)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_permissions_user_id ON user_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_permissions_permission_id ON user_permissions(permission_id);

-- RLS for user_permissions
ALTER TABLE user_permissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_permissions_admin_policy" ON user_permissions;
CREATE POLICY "user_permissions_admin_policy" ON user_permissions
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- 3. COMPREHENSIVE PERMISSION SEEDING
-- ============================================================

-- Dashboard
INSERT INTO permissions (resource, action, description, module) VALUES
('dashboard', 'view', 'View main dashboard', 'dashboard')
ON CONFLICT (resource, action) DO NOTHING;

-- HRM Module
INSERT INTO permissions (resource, action, description, module) VALUES
('employees', 'read', 'View employee list', 'hr'),
('employees', 'create', 'Create new employees', 'hr'),
('employees', 'update', 'Update employee records', 'hr'),
('employees', 'delete', 'Delete employees', 'hr'),
('attendance', 'view', 'View attendance records', 'hr'),
('attendance', 'create', 'Mark attendance', 'hr'),
('attendance', 'update', 'Edit attendance records', 'hr'),
('leaves', 'view', 'View leave requests', 'hr'),
('leaves', 'create', 'Apply for leave', 'hr'),
('leaves', 'approve', 'Approve leave requests', 'hr'),
('salary', 'view', 'View salary information', 'hr'),
('salary', 'create', 'Process salary', 'hr'),
('salary', 'update', 'Edit salary records', 'hr')
ON CONFLICT (resource, action) DO NOTHING;

-- Inventory Module
INSERT INTO permissions (resource, action, description, module) VALUES
('items', 'read', 'View item master list', 'inventory'),
('items', 'create', 'Create new items', 'inventory'),
('items', 'update', 'Update item details', 'inventory'),
('items', 'delete', 'Delete items', 'inventory'),
('items', 'update_price', 'Update item prices', 'inventory'),
('warehouses', 'read', 'View warehouses', 'inventory'),
('warehouses', 'create', 'Create warehouses', 'inventory'),
('warehouses', 'update', 'Update warehouses', 'inventory'),
('stock', 'view', 'View stock levels', 'inventory'),
('stock', 'adjust', 'Adjust stock (cycle count)', 'inventory'),
('stock', 'transfer', 'Transfer stock between warehouses', 'inventory'),
('stock_requests', 'read', 'View stock requests', 'inventory'),
('stock_requests', 'create', 'Create stock requests', 'inventory'),
('stock_requests', 'approve', 'Approve stock requests', 'inventory')
ON CONFLICT (resource, action) DO NOTHING;

-- Procurement Module
INSERT INTO permissions (resource, action, description, module) VALUES
('purchase_orders', 'read', 'View purchase orders', 'procurement'),
('purchase_orders', 'create', 'Create purchase orders', 'procurement'),
('purchase_orders', 'update', 'Update purchase orders', 'procurement'),
('purchase_orders', 'approve', 'Approve purchase orders', 'procurement'),
('grn', 'read', 'View goods receipt notes', 'procurement'),
('grn', 'create', 'Create GRN', 'procurement'),
('gin', 'read', 'View goods issue notes', 'procurement'),
('gin', 'create', 'Create GIN', 'procurement')
ON CONFLICT (resource, action) DO NOTHING;

-- Production Module
INSERT INTO permissions (resource, action, description, module) VALUES
('recipes', 'read', 'View recipes / BOM', 'production'),
('recipes', 'create', 'Create recipes', 'production'),
('recipes', 'update', 'Update recipes', 'production'),
('production_orders', 'read', 'View production orders', 'production'),
('production_orders', 'create', 'Create production orders', 'production'),
('production_orders', 'update', 'Update production orders', 'production')
ON CONFLICT (resource, action) DO NOTHING;

-- Sales & Billing Module
INSERT INTO permissions (resource, action, description, module) VALUES
('billing', 'process', 'Process bills', 'sales'),
('billing', 'void', 'Void bills', 'sales')
ON CONFLICT (resource, action) DO NOTHING;

-- Operations Module (KOT, Tables, Kitchen already seeded in 020)
INSERT INTO permissions (resource, action, description, module) VALUES
('tables', 'view', 'View tables', 'operations'),
('tables', 'manage', 'Manage tables', 'operations'),
('orders', 'read', 'View orders', 'sales'),
('orders', 'create', 'Create orders', 'sales'),
('orders', 'update', 'Update orders', 'sales'),
('orders', 'cancel', 'Cancel orders', 'sales'),
('kitchen', 'view', 'View kitchen display', 'operations'),
('kitchen', 'manage', 'Manage kitchen', 'operations')
ON CONFLICT (resource, action) DO NOTHING;

-- Finance Module
INSERT INTO permissions (resource, action, description, module) VALUES
('accounts', 'view', 'View chart of accounts', 'finance'),
('accounts', 'create', 'Create accounts', 'finance'),
('accounts', 'update', 'Update accounts', 'finance'),
('transactions', 'view', 'View transactions', 'finance'),
('transactions', 'create', 'Create transactions', 'finance'),
('daily_cash', 'view', 'View daily cash report', 'finance'),
('daily_cash', 'create', 'Create daily cash entries', 'finance')
ON CONFLICT (resource, action) DO NOTHING;

-- Reports Module
INSERT INTO permissions (resource, action, description, module) VALUES
('reports', 'sales', 'View sales reports', 'reports'),
('reports', 'inventory', 'View inventory reports', 'reports'),
('reports', 'finance', 'View finance reports', 'reports'),
('reports', 'hr', 'View HR reports', 'reports')
ON CONFLICT (resource, action) DO NOTHING;

-- Admin Module
INSERT INTO permissions (resource, action, description, module) VALUES
('users', 'view', 'View user list', 'admin'),
('users', 'create', 'Create users', 'admin'),
('users', 'update', 'Update user roles/permissions', 'admin'),
('users', 'delete', 'Delete users', 'admin'),
('settings', 'view', 'View system settings', 'admin'),
('settings', 'update', 'Update system settings', 'admin'),
('pending_approvals', 'view', 'View pending approvals', 'workflow'),
('pending_approvals', 'approve', 'Approve/reject requests', 'workflow')
ON CONFLICT (resource, action) DO NOTHING;

-- ============================================================
-- 4. ASSIGN ALL PERMISSIONS TO Z_ALL (Admin)
-- ============================================================
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_ALL'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign HR permissions to Z_HR_MANAGER
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_HR_MANAGER' AND p.module IN ('hr', 'dashboard')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign HR read permissions to Z_HR_OFFICER
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_HR_OFFICER' AND p.module IN ('hr', 'dashboard') AND p.action IN ('read', 'view', 'create')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign inventory/procurement permissions to Z_STOCK_MGR
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_STOCK_MGR' AND p.module IN ('inventory', 'procurement', 'production', 'reports', 'dashboard')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign inventory read permissions to Z_INV_CLERK
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_INV_CLERK' AND p.module IN ('inventory', 'procurement', 'dashboard') AND p.action IN ('read', 'view', 'create')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign production permissions to Z_PROD_STAFF
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_PROD_STAFF' AND (p.module IN ('production', 'dashboard') OR (p.resource = 'kitchen'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign sales permissions to Z_SALES_STAFF
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_SALES_STAFF' AND (p.module IN ('sales', 'operations', 'dashboard'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign finance permissions to Z_FINANCE
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_FINANCE' AND p.module IN ('finance', 'reports', 'dashboard')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- ============================================================
-- 5. GET_USER_PERMISSIONS_V2 FUNCTION
-- Returns merged permissions: role-based + user overrides
-- ============================================================
CREATE OR REPLACE FUNCTION get_user_permissions_v2(p_user_id UUID)
RETURNS TABLE(
    permission_id UUID,
    resource VARCHAR,
    action VARCHAR,
    description TEXT,
    module VARCHAR,
    source VARCHAR  -- 'role' or 'user_override'
) AS $$
BEGIN
    RETURN QUERY
    WITH role_perms AS (
        -- Get all permissions from user's role(s)
        SELECT DISTINCT
            p.id AS perm_id,
            p.resource,
            p.action,
            p.description,
            p.module,
            'role'::VARCHAR AS source
        FROM permissions p
        JOIN role_permissions rp ON rp.permission_id = p.id
        JOIN user_roles ur ON ur.role_id = rp.role_id
        WHERE ur.user_id = p_user_id
    ),
    user_allows AS (
        -- Get user-specific ALLOW overrides
        SELECT DISTINCT
            p.id AS perm_id,
            p.resource,
            p.action,
            p.description,
            p.module,
            'user_override'::VARCHAR AS source
        FROM permissions p
        JOIN user_permissions up ON up.permission_id = p.id
        WHERE up.user_id = p_user_id AND up.grant_type = 'allow'
    ),
    user_denies AS (
        -- Get user-specific DENY overrides
        SELECT up.permission_id AS perm_id
        FROM user_permissions up
        WHERE up.user_id = p_user_id AND up.grant_type = 'deny'
    ),
    merged AS (
        -- Combine role permissions + user allows
        SELECT * FROM role_perms
        UNION
        SELECT * FROM user_allows
    )
    -- Return all merged permissions MINUS denied ones
    SELECT m.perm_id, m.resource, m.action, m.description, m.module, m.source
    FROM merged m
    WHERE m.perm_id NOT IN (SELECT d.perm_id FROM user_denies d);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 6. GET_USER_PERMISSIONS (backward compat wrapper)
-- ============================================================
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id UUID)
RETURNS TABLE(
    resource VARCHAR,
    action VARCHAR,
    module VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT v.resource, v.action, v.module
    FROM get_user_permissions_v2(p_user_id) v;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 7. ADMIN_CREATE_USER FUNCTION
-- Restricted to Z_ALL and Z_HR_MANAGER roles
-- ============================================================
CREATE OR REPLACE FUNCTION admin_create_user(
    p_email VARCHAR,
    p_password VARCHAR,
    p_full_name VARCHAR,
    p_role_code VARCHAR DEFAULT 'Z_SALES_STAFF',
    p_permissions JSONB DEFAULT '[]'::JSONB,
    p_employee_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_user_id UUID;
    v_instance_id UUID;
    v_encrypted_pw VARCHAR;
    v_role_id UUID;
    v_perm JSONB;
    v_perm_id UUID;
    v_clean_email VARCHAR;
BEGIN
    -- Clean inputs
    v_clean_email := LOWER(TRIM(p_email));

    -- A. Authorization Check: Only admin/HR manager can create users
    SELECT p.role INTO v_caller_role
    FROM profiles p
    WHERE p.id = auth.uid();

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators and HR managers can create users';
    END IF;

    -- B. Check if email already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RAISE EXCEPTION 'A user with email % already exists', v_clean_email;
    END IF;

    -- C. Get instance ID from existing users or default to nil
    SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
    IF v_instance_id IS NULL THEN
        v_instance_id := '00000000-0000-0000-0000-000000000000';
    END IF;

    -- D. Create auth.users record
    v_user_id := gen_random_uuid();
    v_encrypted_pw := crypt(p_password, gen_salt('bf', 10)); -- Force cost 10 for Supabase compatibility

    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, is_super_admin
    ) VALUES (
        v_instance_id,
        v_user_id,
        'authenticated',
        'authenticated',
        v_clean_email,
        v_encrypted_pw,
        NOW(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        jsonb_build_object(
            'full_name', p_full_name,
            'role', p_role_code
        ),
        NOW(),
        NOW(),
        '',
        FALSE
    );

    -- E. Create profile record
    INSERT INTO profiles (id, user_id, full_name, role, email)
    VALUES (v_user_id, v_user_id, p_full_name, p_role_code, v_clean_email)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        email = EXCLUDED.email;

    -- F. Assign role
    SELECT id INTO v_role_id FROM roles WHERE code = p_role_code;
    IF v_role_id IS NOT NULL THEN
        INSERT INTO user_roles (user_id, role_id)
        VALUES (v_user_id, v_role_id)
        ON CONFLICT DO NOTHING;
    END IF;

    -- G. Link to employee if provided
    IF p_employee_id IS NOT NULL THEN
        UPDATE employees SET
            user_id = v_user_id,
            company_email = v_clean_email
        WHERE id = p_employee_id;
    END IF;

    -- H. Apply user-level permission overrides
    IF p_permissions IS NOT NULL AND jsonb_array_length(p_permissions) > 0 THEN
        FOR v_perm IN SELECT * FROM jsonb_array_elements(p_permissions)
        LOOP
            -- Each element: {"permission_id": "uuid", "grant_type": "allow"/"deny"}
            v_perm_id := (v_perm->>'permission_id')::UUID;
            INSERT INTO user_permissions (user_id, permission_id, grant_type, granted_by)
            VALUES (
                v_user_id,
                v_perm_id,
                COALESCE(v_perm->>'grant_type', 'allow'),
                auth.uid()
            )
            ON CONFLICT (user_id, permission_id) DO UPDATE SET
                grant_type = EXCLUDED.grant_type,
                granted_by = EXCLUDED.granted_by,
                updated_at = NOW();
        END LOOP;
    END IF;

    -- I. Return result
    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'email', v_clean_email,
        'role', p_role_code,
        'message', 'User created successfully'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 8. UPDATE_USER_PERMISSIONS FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION update_user_permissions(
    p_target_user_id UUID,
    p_permissions JSONB  -- [{"permission_id": "uuid", "grant_type": "allow"/"deny"}, ...]
)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_perm JSONB;
    v_perm_id UUID;
BEGIN
    -- Authorization Check
    SELECT p.role INTO v_caller_role
    FROM profiles p
    WHERE p.id = auth.uid();

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators and HR managers can modify permissions';
    END IF;

    -- Clear existing user-level overrides
    DELETE FROM user_permissions WHERE user_id = p_target_user_id;

    -- Insert new overrides
    IF p_permissions IS NOT NULL AND jsonb_array_length(p_permissions) > 0 THEN
        FOR v_perm IN SELECT * FROM jsonb_array_elements(p_permissions)
        LOOP
            v_perm_id := (v_perm->>'permission_id')::UUID;
            INSERT INTO user_permissions (user_id, permission_id, grant_type, granted_by)
            VALUES (
                p_target_user_id,
                v_perm_id,
                COALESCE(v_perm->>'grant_type', 'allow'),
                auth.uid()
            )
            ON CONFLICT (user_id, permission_id) DO UPDATE SET
                grant_type = EXCLUDED.grant_type,
                granted_by = EXCLUDED.granted_by,
                updated_at = NOW();
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Permissions updated successfully'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 9. GRANT EXECUTION PERMISSIONS
-- ============================================================
GRANT EXECUTE ON FUNCTION get_user_permissions_v2(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_permissions(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, JSONB, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_permissions(UUID, JSONB) TO authenticated;

-- ============================================================
-- 10. FORCE SCHEMA CACHE RELOAD
-- ============================================================
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 030 Complete:';
    RAISE NOTICE '  - user_permissions table created';
    RAISE NOTICE '  - All system permissions seeded';
    RAISE NOTICE '  - get_user_permissions_v2 function created';
    RAISE NOTICE '  - admin_create_user function created';
    RAISE NOTICE '  - update_user_permissions function created';
    RAISE NOTICE '  - Role permission assignments updated';
END $$;
