-- =================================================================
-- SEVEN WAVES ERP - KOT MODULE RBAC PERMISSIONS
-- =================================================================

-- Create permissions table if not exists
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    description TEXT,
    module VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(resource, action)
);

-- Create role_permissions table if not exists
CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(role_id, permission_id)
);

-- Insert KOT Module Permissions
INSERT INTO permissions (resource, action, description, module) VALUES
-- Kitchen Orders
('kot', 'view', 'View kitchen order tickets', 'operations'),
('kot', 'update', 'Update KOT status', 'operations'),
('kot', 'cancel', 'Cancel KOT items', 'operations'),
-- Customer Menu
('customer_menu', 'view', 'View customer menu', 'operations'),
-- Tables Management
('tables', 'view', 'View restaurant tables', 'operations'),
('tables', 'manage', 'Manage tables and sessions', 'operations'),
('tables', 'assign_waiter', 'Assign waiters to tables', 'operations'),
-- Orders
('orders', 'create', 'Create new orders', 'sales'),
('orders', 'read', 'View orders', 'sales'),
('orders', 'update', 'Update orders', 'sales'),
('orders', 'cancel', 'Cancel orders', 'sales'),
-- Kitchen Display
('kitchen', 'view', 'View kitchen display', 'operations'),
('kitchen', 'manage', 'Manage kitchen operations', 'operations'),
-- Billing
('billing', 'process', 'Process bills', 'sales'),
('billing', 'void', 'Void bills', 'sales')
ON CONFLICT (resource, action) DO NOTHING;

-- Create roles table if not exists
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert roles if not exist
INSERT INTO roles (code, name, description) VALUES
('Z_KITCHEN', 'Kitchen Staff', 'Kitchen staff with KOT access'),
('Z_WAITER', 'Waiter', 'Waiters with order and table access'),
('Z_CASHIER', 'Cashier', 'Cashiers with billing access')
ON CONFLICT (code) DO NOTHING;

-- Assign permissions to roles
-- Kitchen Staff: kot.view, kot.update, kitchen.view
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_KITCHEN' AND p.resource = 'kot' AND p.action IN ('view', 'update')
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_KITCHEN' AND p.resource = 'kitchen' AND p.action = 'view'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Waiter: orders.*, tables.view, tables.assign_waiter, billing.process
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_WAITER' AND p.resource = 'orders'
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_WAITER' AND p.resource = 'tables' AND p.action IN ('view', 'assign_waiter')
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_WAITER' AND p.resource = 'billing' AND p.action = 'process'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Cashier: billing.*, orders.read, tables.view
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_CASHIER' AND p.resource = 'billing'
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_CASHIER' AND p.resource = 'orders' AND p.action = 'read'
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_CASHIER' AND p.resource = 'tables' AND p.action = 'view'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_ALL (Admin) gets all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_ALL'
ON CONFLICT (role_id, permission_id) DO NOTHING;
