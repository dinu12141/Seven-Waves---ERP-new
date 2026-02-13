-- =================================================================
-- SEVEN WAVES ERP - RBAC SYSTEM (SAP HANA Authorization Standard)
-- Migration: 014_rbac_system.sql
-- =================================================================

-- =====================================================
-- 0. SCHEMA FIX: Add missing columns to existing tables
-- =====================================================
-- The permissions table may already exist with 'module' used as
-- the resource identifier. Add the 'resource' column if missing.

DO $$
BEGIN
    -- Add 'resource' column to permissions if it doesn't exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'permissions')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'permissions' AND column_name = 'resource')
    THEN
        ALTER TABLE permissions ADD COLUMN resource VARCHAR(100);
        -- Copy module data into resource for existing rows
        UPDATE permissions SET resource = module WHERE resource IS NULL;
        -- Make resource NOT NULL now that it has data
        ALTER TABLE permissions ALTER COLUMN resource SET NOT NULL;
        -- Drop old unique constraint and add the correct one
        ALTER TABLE permissions DROP CONSTRAINT IF EXISTS permissions_module_action_key;
        ALTER TABLE permissions ADD CONSTRAINT permissions_resource_action_key UNIQUE (resource, action);
        RAISE NOTICE '✅ Added "resource" column to permissions table';
    END IF;

    -- Add 'is_active' column to user_roles if it doesn't exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_roles')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_roles' AND column_name = 'is_active')
    THEN
        ALTER TABLE user_roles ADD COLUMN is_active BOOLEAN DEFAULT true;
        RAISE NOTICE '✅ Added "is_active" column to user_roles table';
    END IF;
END $$;

-- =====================================================
-- 1. ROLES TABLE (SAP Authorization Objects)
-- =====================================================

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. PERMISSIONS TABLE (Granular Feature Permissions)
-- =====================================================

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    description TEXT,
    module VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(resource, action)
);

-- =====================================================
-- 3. ROLE_PERMISSIONS (Junction Table)
-- =====================================================

CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(role_id, permission_id)
);

-- =====================================================
-- 4. USER_ROLES (User-Role Assignment)
-- =====================================================

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES auth.users(id),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, role_id)
);

-- =====================================================
-- 5. USER_WAREHOUSE_ACCESS (Warehouse Isolation)
-- =====================================================

CREATE TABLE IF NOT EXISTS user_warehouse_access (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    access_level VARCHAR(20) DEFAULT 'read' CHECK (access_level IN ('read', 'write', 'full')),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, warehouse_id)
);

-- =====================================================
-- 6. SEED DATA - SAP ROLE CODES
-- =====================================================

INSERT INTO roles (code, name, description, is_system_role) VALUES
('Z_ALL', 'Administrator', 'Full system access - Master Data & Transactions', true),
('Z_STOCK_MGR', 'Store Manager', 'Inventory reports, Warehouse Registration, Good Request Approval', true),
('Z_INV_CLERK', 'Inventory Clerk', 'Item Registration, Good Request Note, GRN', true),
('Z_PROD_STAFF', 'Kitchen/Production', 'Item Menu Registration, Product Finishing updates', true),
('Z_SALES_STAFF', 'Cashier/Waiter', 'Dine-in/Takeaway orders and billing only', true),
('Z_HR_MANAGER', 'HR Manager', 'Full HR access including salary processing', true),
('Z_HR_OFFICER', 'HR Officer', 'Employee management and attendance', true),
('Z_FINANCE', 'Finance User', 'Accounts, transactions, and financial reports', true)
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- 7. SEED DATA - PERMISSIONS
-- =====================================================

-- Dashboard
INSERT INTO permissions (resource, action, description, module) VALUES
('dashboard', 'view', 'View main dashboard', 'core')
ON CONFLICT (resource, action) DO NOTHING;

-- Items/Inventory
INSERT INTO permissions (resource, action, description, module) VALUES
('items', 'create', 'Create new items', 'inventory'),
('items', 'read', 'View items list', 'inventory'),
('items', 'update', 'Modify item details', 'inventory'),
('items', 'delete', 'Remove items', 'inventory'),
('items', 'update_price', 'Modify item prices', 'inventory')
ON CONFLICT (resource, action) DO NOTHING;

-- Warehouses
INSERT INTO permissions (resource, action, description, module) VALUES
('warehouses', 'create', 'Register new warehouses', 'inventory'),
('warehouses', 'read', 'View warehouses', 'inventory'),
('warehouses', 'update', 'Modify warehouse details', 'inventory'),
('warehouses', 'delete', 'Remove warehouses', 'inventory')
ON CONFLICT (resource, action) DO NOTHING;

-- Stock
INSERT INTO permissions (resource, action, description, module) VALUES
('stock', 'view', 'View stock levels', 'inventory'),
('stock', 'transfer', 'Transfer stock between warehouses', 'inventory'),
('stock', 'adjust', 'Make stock adjustments', 'inventory')
ON CONFLICT (resource, action) DO NOTHING;

-- Purchase Orders
INSERT INTO permissions (resource, action, description, module) VALUES
('purchase_orders', 'create', 'Create purchase orders', 'procurement'),
('purchase_orders', 'read', 'View purchase orders', 'procurement'),
('purchase_orders', 'update', 'Modify purchase orders', 'procurement'),
('purchase_orders', 'approve', 'Approve purchase orders', 'procurement'),
('purchase_orders', 'cancel', 'Cancel purchase orders', 'procurement')
ON CONFLICT (resource, action) DO NOTHING;

-- GRN (Goods Receipt Notes)
INSERT INTO permissions (resource, action, description, module) VALUES
('grn', 'create', 'Create goods receipt notes', 'procurement'),
('grn', 'read', 'View goods receipt notes', 'procurement'),
('grn', 'approve', 'Approve goods receipt notes', 'procurement')
ON CONFLICT (resource, action) DO NOTHING;

-- GIN (Goods Issue Notes)
INSERT INTO permissions (resource, action, description, module) VALUES
('gin', 'create', 'Create goods issue notes', 'procurement'),
('gin', 'read', 'View goods issue notes', 'procurement'),
('gin', 'approve', 'Approve goods issue notes', 'procurement')
ON CONFLICT (resource, action) DO NOTHING;

-- Stock Requests
INSERT INTO permissions (resource, action, description, module) VALUES
('stock_requests', 'create', 'Create stock requests', 'inventory'),
('stock_requests', 'read', 'View stock requests', 'inventory'),
('stock_requests', 'approve', 'Approve stock requests', 'inventory')
ON CONFLICT (resource, action) DO NOTHING;

-- Recipes/Menu
INSERT INTO permissions (resource, action, description, module) VALUES
('recipes', 'create', 'Create recipes', 'production'),
('recipes', 'read', 'View recipes', 'production'),
('recipes', 'update', 'Modify recipes', 'production'),
('recipes', 'delete', 'Remove recipes', 'production')
ON CONFLICT (resource, action) DO NOTHING;

-- Production Orders
INSERT INTO permissions (resource, action, description, module) VALUES
('production_orders', 'create', 'Create production orders', 'production'),
('production_orders', 'read', 'View production orders', 'production'),
('production_orders', 'update', 'Update production status', 'production'),
('production_orders', 'complete', 'Mark production as complete', 'production')
ON CONFLICT (resource, action) DO NOTHING;

-- Kitchen Display
INSERT INTO permissions (resource, action, description, module) VALUES
('kitchen', 'view', 'View kitchen display', 'operations'),
('kitchen', 'update_status', 'Update order status in kitchen', 'operations')
ON CONFLICT (resource, action) DO NOTHING;

-- Tables/Reservations
INSERT INTO permissions (resource, action, description, module) VALUES
('tables', 'view', 'View restaurant tables', 'operations'),
('tables', 'manage', 'Manage table assignments', 'operations'),
('reservations', 'create', 'Create reservations', 'operations'),
('reservations', 'read', 'View reservations', 'operations'),
('reservations', 'update', 'Modify reservations', 'operations'),
('reservations', 'cancel', 'Cancel reservations', 'operations')
ON CONFLICT (resource, action) DO NOTHING;

-- Orders/Billing
INSERT INTO permissions (resource, action, description, module) VALUES
('orders', 'create', 'Create orders', 'sales'),
('orders', 'read', 'View orders', 'sales'),
('orders', 'update', 'Modify orders', 'sales'),
('orders', 'cancel', 'Cancel orders', 'sales'),
('billing', 'process', 'Process billing/payments', 'sales'),
('billing', 'refund', 'Process refunds', 'sales')
ON CONFLICT (resource, action) DO NOTHING;

-- Reports
INSERT INTO permissions (resource, action, description, module) VALUES
('reports', 'sales', 'View sales reports', 'reports'),
('reports', 'inventory', 'View inventory reports', 'reports'),
('reports', 'financial', 'View financial reports', 'reports'),
('reports', 'hr', 'View HR reports', 'reports')
ON CONFLICT (resource, action) DO NOTHING;

-- HR Module
INSERT INTO permissions (resource, action, description, module) VALUES
('employees', 'create', 'Register new employees', 'hr'),
('employees', 'read', 'View employee list', 'hr'),
('employees', 'update', 'Modify employee details', 'hr'),
('employees', 'delete', 'Remove employees', 'hr'),
('attendance', 'view', 'View attendance records', 'hr'),
('attendance', 'manage', 'Manage attendance', 'hr'),
('leaves', 'view', 'View leave applications', 'hr'),
('leaves', 'approve', 'Approve leave applications', 'hr'),
('salary', 'view', 'View salary information', 'hr'),
('salary', 'process', 'Process payroll', 'hr')
ON CONFLICT (resource, action) DO NOTHING;

-- Finance
INSERT INTO permissions (resource, action, description, module) VALUES
('accounts', 'view', 'View chart of accounts', 'finance'),
('accounts', 'manage', 'Manage accounts', 'finance'),
('transactions', 'view', 'View transactions', 'finance'),
('transactions', 'create', 'Create transactions', 'finance'),
('daily_cash', 'view', 'View daily cash', 'finance'),
('daily_cash', 'manage', 'Manage daily cash', 'finance')
ON CONFLICT (resource, action) DO NOTHING;

-- Admin
INSERT INTO permissions (resource, action, description, module) VALUES
('users', 'view', 'View user list', 'admin'),
('users', 'manage', 'Manage users', 'admin'),
('roles', 'view', 'View roles', 'admin'),
('roles', 'manage', 'Manage roles and permissions', 'admin'),
('settings', 'view', 'View system settings', 'admin'),
('settings', 'manage', 'Manage system settings', 'admin')
ON CONFLICT (resource, action) DO NOTHING;

-- Pending Approvals
INSERT INTO permissions (resource, action, description, module) VALUES
('pending_approvals', 'view', 'View pending approval list', 'workflow'),
('pending_approvals', 'process', 'Process pending approvals', 'workflow')
ON CONFLICT (resource, action) DO NOTHING;

-- =====================================================
-- 8. ASSIGN PERMISSIONS TO ROLES
-- =====================================================

-- Z_ALL (Admin) - Full access
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.code = 'Z_ALL'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_STOCK_MGR (Store Manager)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.code = 'Z_STOCK_MGR'
AND (
    p.module IN ('inventory', 'procurement', 'reports', 'workflow')
    OR (p.resource = 'dashboard' AND p.action = 'view')
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_INV_CLERK (Inventory Clerk)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.code = 'Z_INV_CLERK'
AND (
    (p.resource IN ('items', 'stock', 'grn', 'stock_requests') AND p.action IN ('create', 'read', 'update'))
    OR (p.resource = 'purchase_orders' AND p.action IN ('create', 'read'))
    OR (p.resource = 'warehouses' AND p.action = 'read')
    OR (p.resource = 'dashboard' AND p.action = 'view')
    OR (p.resource = 'reports' AND p.action = 'inventory')
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_PROD_STAFF (Kitchen/Production)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.code = 'Z_PROD_STAFF'
AND (
    p.module = 'production'
    OR (p.resource = 'kitchen' AND p.action IN ('view', 'update_status'))
    OR (p.resource = 'recipes' AND p.action IN ('read', 'update'))
    OR (p.resource = 'dashboard' AND p.action = 'view')
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_SALES_STAFF (Cashier/Waiter)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.code = 'Z_SALES_STAFF'
AND (
    (p.resource IN ('orders', 'billing') AND p.action IN ('create', 'read', 'update', 'process'))
    OR (p.resource = 'tables' AND p.action IN ('view', 'manage'))
    OR (p.resource = 'reservations' AND p.action IN ('read', 'update'))
    OR (p.resource = 'dashboard' AND p.action = 'view')
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_HR_MANAGER (HR Manager)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.code = 'Z_HR_MANAGER'
AND (
    p.module = 'hr'
    OR (p.resource = 'dashboard' AND p.action = 'view')
    OR (p.resource = 'reports' AND p.action = 'hr')
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_HR_OFFICER (HR Officer)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.code = 'Z_HR_OFFICER'
AND (
    (p.resource IN ('employees', 'attendance') AND p.action IN ('create', 'read', 'update', 'view', 'manage'))
    OR (p.resource = 'leaves' AND p.action = 'view')
    OR (p.resource = 'dashboard' AND p.action = 'view')
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_FINANCE (Finance User)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.code = 'Z_FINANCE'
AND (
    p.module = 'finance'
    OR (p.resource = 'dashboard' AND p.action = 'view')
    OR (p.resource = 'reports' AND p.action = 'financial')
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- =====================================================
-- 9. UPDATE PROFILES TABLE (Add role reference)
-- =====================================================

-- Add role column if not exists (for backward compatibility)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'role') THEN
        ALTER TABLE profiles ADD COLUMN role VARCHAR(50) DEFAULT 'Z_SALES_STAFF';
    END IF;
END $$;

-- =====================================================
-- 10. RPC FUNCTIONS
-- =====================================================

-- Drop functions first to avoid return type conflicts
DROP FUNCTION IF EXISTS get_user_permissions(uuid);
DROP FUNCTION IF EXISTS get_user_warehouses(uuid);
DROP FUNCTION IF EXISTS get_user_role(uuid);

-- Get user permissions
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id UUID)
RETURNS TABLE (
    resource VARCHAR,
    action VARCHAR,
    module VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT p.resource, p.action, p.module
    FROM permissions p
    INNER JOIN role_permissions rp ON rp.permission_id = p.id
    INNER JOIN user_roles ur ON ur.role_id = rp.role_id
    WHERE ur.user_id = p_user_id AND ur.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user has permission
CREATE OR REPLACE FUNCTION has_permission(p_user_id UUID, p_module VARCHAR, p_action VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    has_perm BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM permissions p
        INNER JOIN role_permissions rp ON rp.permission_id = p.id
        INNER JOIN user_roles ur ON ur.role_id = rp.role_id
        WHERE ur.user_id = p_user_id 
        AND ur.is_active = true
        AND (p.resource = p_module OR p.module = p_module)
        AND p.action = p_action
    ) INTO has_perm;
    
    RETURN has_perm;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user's accessible warehouses
CREATE OR REPLACE FUNCTION get_user_warehouses(p_user_id UUID)
RETURNS TABLE (
    warehouse_id UUID,
    warehouse_code VARCHAR,
    warehouse_name VARCHAR,
    access_level VARCHAR
) AS $$
BEGIN
    -- Check if user is admin (has full access)
    IF EXISTS (
        SELECT 1 FROM user_roles ur
        INNER JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = p_user_id AND r.code = 'Z_ALL' AND ur.is_active = true
    ) THEN
        -- Return all warehouses for admin
        RETURN QUERY
        SELECT w.id, w.code, w.name, 'full'::VARCHAR
        FROM warehouses w
        WHERE w.is_active = true;
    ELSE
        -- Return only assigned warehouses
        RETURN QUERY
        SELECT w.id, w.code, w.name, uwa.access_level
        FROM user_warehouse_access uwa
        INNER JOIN warehouses w ON w.id = uwa.warehouse_id
        WHERE uwa.user_id = p_user_id AND w.is_active = true;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user's primary role
CREATE OR REPLACE FUNCTION get_user_role(p_user_id UUID)
RETURNS TABLE (
    role_code VARCHAR,
    role_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.code, r.name
    FROM roles r
    INNER JOIN user_roles ur ON ur.role_id = r.id
    WHERE ur.user_id = p_user_id AND ur.is_active = true
    ORDER BY 
        CASE r.code 
            WHEN 'Z_ALL' THEN 1
            WHEN 'Z_STOCK_MGR' THEN 2
            WHEN 'Z_HR_MANAGER' THEN 3
            WHEN 'Z_FINANCE' THEN 4
            ELSE 5
        END
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Validate issued person for GIN
CREATE OR REPLACE FUNCTION validate_issued_person(p_person_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles WHERE id = p_person_id
    ) OR EXISTS (
        SELECT 1 FROM employees WHERE user_id = p_person_id AND status = 'Active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 11. INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission ON role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_user_warehouse_access_user ON user_warehouse_access(user_id);
CREATE INDEX IF NOT EXISTS idx_permissions_resource_action ON permissions(resource, action);

-- =====================================================
-- 12. RLS POLICIES FOR RBAC TABLES
-- =====================================================

ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_warehouse_access ENABLE ROW LEVEL SECURITY;

-- Roles: Everyone can read, only admins can modify
DROP POLICY IF EXISTS roles_read_policy ON roles;
CREATE POLICY roles_read_policy ON roles
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS roles_write_policy ON roles;
CREATE POLICY roles_write_policy ON roles
    FOR ALL TO authenticated
    USING (has_permission(auth.uid(), 'roles', 'manage'));

-- Permissions: Everyone can read
DROP POLICY IF EXISTS permissions_read_policy ON permissions;
CREATE POLICY permissions_read_policy ON permissions
    FOR SELECT TO authenticated
    USING (true);

-- Role Permissions: Everyone can read, only admins can modify
DROP POLICY IF EXISTS role_permissions_read_policy ON role_permissions;
CREATE POLICY role_permissions_read_policy ON role_permissions
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS role_permissions_write_policy ON role_permissions;
CREATE POLICY role_permissions_write_policy ON role_permissions
    FOR ALL TO authenticated
    USING (has_permission(auth.uid(), 'roles', 'manage'));

-- User Roles: Admins can manage, users can see their own
DROP POLICY IF EXISTS user_roles_policy ON user_roles;
CREATE POLICY user_roles_policy ON user_roles
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() 
        OR has_permission(auth.uid(), 'users', 'manage')
    );

-- User Warehouse Access: Admins can manage, users can see their own
DROP POLICY IF EXISTS user_warehouse_access_policy ON user_warehouse_access;
CREATE POLICY user_warehouse_access_policy ON user_warehouse_access
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid() 
        OR has_permission(auth.uid(), 'users', 'manage')
    );

-- =====================================================
-- 13. GRANT PERMISSIONS
-- =====================================================

GRANT ALL ON roles TO authenticated;
GRANT ALL ON permissions TO authenticated;
GRANT ALL ON role_permissions TO authenticated;
GRANT ALL ON user_roles TO authenticated;
GRANT ALL ON user_warehouse_access TO authenticated;

GRANT EXECUTE ON FUNCTION get_user_permissions TO authenticated;
GRANT EXECUTE ON FUNCTION has_permission TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_warehouses TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION validate_issued_person TO authenticated;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ RBAC System installed successfully!';
    RAISE NOTICE '📊 Tables created: roles, permissions, role_permissions, user_roles, user_warehouse_access';
    RAISE NOTICE '🔑 Roles seeded: Z_ALL, Z_STOCK_MGR, Z_INV_CLERK, Z_PROD_STAFF, Z_SALES_STAFF, Z_HR_MANAGER, Z_HR_OFFICER, Z_FINANCE';
    RAISE NOTICE '🔒 RLS policies configured for role-based access';
END $$;
