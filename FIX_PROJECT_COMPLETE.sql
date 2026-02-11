
-- =================================================================
-- RUN THIS IN SUPABASE SQL EDITOR TO FIX EVERYTHING
-- =================================================================

-- 1. Ensure Roles Exist
INSERT INTO roles (code, name, description, is_system_role) VALUES
('Z_ALL', 'Administrator', 'Full system access', true),
('Z_STOCK_MGR', 'Store Manager', 'Store Manager', true),
('Z_INV_CLERK', 'Inventory Clerk', 'Inventory Clerk', true),
('Z_PROD_STAFF', 'Kitchen/Production', 'Kitchen', true),
('Z_SALES_STAFF', 'Cashier/Waiter', 'POS', true),
('Z_HR_MANAGER', 'HR Manager', 'HR', true),
('Z_FINANCE', 'Finance User', 'Finance', true)
ON CONFLICT (code) DO NOTHING;

-- 2. Ensure Permissions Exist (Sample)
INSERT INTO permissions (resource, action, module) VALUES
('dashboard', 'view', 'core'),
('items', 'create', 'inventory'),
('items', 'read', 'inventory'),
('items', 'update', 'inventory'),
('orders', 'create', 'sales'),
('orders', 'read', 'sales')
ON CONFLICT (resource, action) DO NOTHING;

-- 3. Link Admin User to Role
DO $$
DECLARE
    v_user_id UUID;
    v_role_id UUID;
BEGIN
    -- Get Admin User ID (admin@sevenwaves.com)
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'admin@sevenwaves.com';
    
    -- Get Admin Role ID
    SELECT id INTO v_role_id FROM roles WHERE code = 'Z_ALL';

    IF v_user_id IS NOT NULL AND v_role_id IS NOT NULL THEN
        -- Assign Role
        INSERT INTO user_roles (user_id, role_id) VALUES (v_user_id, v_role_id)
        ON CONFLICT (user_id, role_id) DO NOTHING;
        
        -- Update Profile
        INSERT INTO profiles (id, full_name, role) VALUES (v_user_id, 'System Admin', 'Z_ALL')
        ON CONFLICT (id) DO UPDATE SET role = 'Z_ALL';
        
        RAISE NOTICE '✅ Successfully assigned Admin role to %', v_user_id;
    ELSE
        RAISE WARNING '⚠️ Could not find user or role. UserID: %, RoleID: %', v_user_id, v_role_id;
    END IF;
END $$;
