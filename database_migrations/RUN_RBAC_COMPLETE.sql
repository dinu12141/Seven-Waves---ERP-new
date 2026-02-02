-- =================================================================
-- SEVEN WAVES ERP - COMPLETE RBAC SYSTEM MIGRATION
-- Combined file for easy execution in Supabase SQL Editor
-- =================================================================
-- 
-- HOW TO USE:
-- 1. Open Supabase Dashboard -> SQL Editor
-- 2. Copy and paste this entire file
-- 3. Click "Run" to execute all migrations
-- 4. Check the output for success messages
--
-- This file combines:
-- - 014_rbac_system.sql (Roles, Permissions, User Roles)
-- - 015_audit_logging.sql (Change Log with triggers)
-- - 016_restaurant_tables.sql (Tables & Reservations)
-- - 017_rls_policies.sql (Row Level Security)
-- - 018_migrate_existing_users.sql (User migration)
-- =================================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =================================================================
-- PART 1: RBAC SYSTEM (014_rbac_system.sql)
-- =================================================================

-- 1. ROLES TABLE
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

-- 2. PERMISSIONS TABLE
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    description TEXT,
    module VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(resource, action)
);

-- 3. ROLE_PERMISSIONS
CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(role_id, permission_id)
);

-- 4. USER_ROLES
CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES auth.users(id),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, role_id)
);

-- 5. USER_WAREHOUSE_ACCESS
CREATE TABLE IF NOT EXISTS user_warehouse_access (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    access_level VARCHAR(20) DEFAULT 'read' CHECK (access_level IN ('read', 'write', 'full')),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, warehouse_id)
);

-- 6. SEED ROLES
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

-- 7. SEED PERMISSIONS
INSERT INTO permissions (resource, action, description, module) VALUES
('dashboard', 'view', 'View main dashboard', 'core'),
('items', 'create', 'Create new items', 'inventory'),
('items', 'read', 'View items list', 'inventory'),
('items', 'update', 'Modify item details', 'inventory'),
('items', 'delete', 'Remove items', 'inventory'),
('items', 'update_price', 'Modify item prices', 'inventory'),
('warehouses', 'create', 'Register new warehouses', 'inventory'),
('warehouses', 'read', 'View warehouses', 'inventory'),
('warehouses', 'update', 'Modify warehouse details', 'inventory'),
('warehouses', 'delete', 'Remove warehouses', 'inventory'),
('stock', 'view', 'View stock levels', 'inventory'),
('stock', 'transfer', 'Transfer stock between warehouses', 'inventory'),
('stock', 'adjust', 'Make stock adjustments', 'inventory'),
('purchase_orders', 'create', 'Create purchase orders', 'procurement'),
('purchase_orders', 'read', 'View purchase orders', 'procurement'),
('purchase_orders', 'update', 'Modify purchase orders', 'procurement'),
('purchase_orders', 'approve', 'Approve purchase orders', 'procurement'),
('purchase_orders', 'cancel', 'Cancel purchase orders', 'procurement'),
('grn', 'create', 'Create goods receipt notes', 'procurement'),
('grn', 'read', 'View goods receipt notes', 'procurement'),
('grn', 'approve', 'Approve goods receipt notes', 'procurement'),
('gin', 'create', 'Create goods issue notes', 'procurement'),
('gin', 'read', 'View goods issue notes', 'procurement'),
('gin', 'approve', 'Approve goods issue notes', 'procurement'),
('stock_requests', 'create', 'Create stock requests', 'inventory'),
('stock_requests', 'read', 'View stock requests', 'inventory'),
('stock_requests', 'approve', 'Approve stock requests', 'inventory'),
('recipes', 'create', 'Create recipes', 'production'),
('recipes', 'read', 'View recipes', 'production'),
('recipes', 'update', 'Modify recipes', 'production'),
('recipes', 'delete', 'Remove recipes', 'production'),
('production_orders', 'create', 'Create production orders', 'production'),
('production_orders', 'read', 'View production orders', 'production'),
('production_orders', 'update', 'Update production status', 'production'),
('production_orders', 'complete', 'Mark production as complete', 'production'),
('kitchen', 'view', 'View kitchen display', 'operations'),
('kitchen', 'update_status', 'Update order status in kitchen', 'operations'),
('tables', 'view', 'View restaurant tables', 'operations'),
('tables', 'manage', 'Manage table assignments', 'operations'),
('reservations', 'create', 'Create reservations', 'operations'),
('reservations', 'read', 'View reservations', 'operations'),
('reservations', 'update', 'Modify reservations', 'operations'),
('reservations', 'cancel', 'Cancel reservations', 'operations'),
('orders', 'create', 'Create orders', 'sales'),
('orders', 'read', 'View orders', 'sales'),
('orders', 'update', 'Modify orders', 'sales'),
('orders', 'cancel', 'Cancel orders', 'sales'),
('billing', 'process', 'Process billing/payments', 'sales'),
('billing', 'refund', 'Process refunds', 'sales'),
('reports', 'sales', 'View sales reports', 'reports'),
('reports', 'inventory', 'View inventory reports', 'reports'),
('reports', 'financial', 'View financial reports', 'reports'),
('reports', 'hr', 'View HR reports', 'reports'),
('employees', 'create', 'Register new employees', 'hr'),
('employees', 'read', 'View employee list', 'hr'),
('employees', 'update', 'Modify employee details', 'hr'),
('employees', 'delete', 'Remove employees', 'hr'),
('attendance', 'view', 'View attendance records', 'hr'),
('attendance', 'manage', 'Manage attendance', 'hr'),
('leaves', 'view', 'View leave applications', 'hr'),
('leaves', 'approve', 'Approve leave applications', 'hr'),
('salary', 'view', 'View salary information', 'hr'),
('salary', 'process', 'Process payroll', 'hr'),
('accounts', 'view', 'View chart of accounts', 'finance'),
('accounts', 'manage', 'Manage accounts', 'finance'),
('transactions', 'view', 'View transactions', 'finance'),
('transactions', 'create', 'Create transactions', 'finance'),
('daily_cash', 'view', 'View daily cash', 'finance'),
('daily_cash', 'manage', 'Manage daily cash', 'finance'),
('users', 'view', 'View user list', 'admin'),
('users', 'manage', 'Manage users', 'admin'),
('roles', 'view', 'View roles', 'admin'),
('roles', 'manage', 'Manage roles and permissions', 'admin'),
('settings', 'view', 'View system settings', 'admin'),
('settings', 'manage', 'Manage system settings', 'admin'),
('pending_approvals', 'view', 'View pending approval list', 'workflow'),
('pending_approvals', 'process', 'Process pending approvals', 'workflow')
ON CONFLICT (resource, action) DO NOTHING;

-- 8. ASSIGN PERMISSIONS TO ROLES
-- Z_ALL (Admin) - Full access
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.code = 'Z_ALL'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_STOCK_MGR
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_STOCK_MGR'
AND (p.module IN ('inventory', 'procurement', 'reports', 'workflow') OR (p.resource = 'dashboard' AND p.action = 'view'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_INV_CLERK
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_INV_CLERK'
AND ((p.resource IN ('items', 'stock', 'grn', 'stock_requests') AND p.action IN ('create', 'read', 'update'))
    OR (p.resource = 'purchase_orders' AND p.action IN ('create', 'read'))
    OR (p.resource = 'warehouses' AND p.action = 'read')
    OR (p.resource = 'dashboard' AND p.action = 'view')
    OR (p.resource = 'reports' AND p.action = 'inventory'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_PROD_STAFF
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_PROD_STAFF'
AND (p.module = 'production' OR (p.resource = 'kitchen') OR (p.resource = 'recipes' AND p.action IN ('read', 'update')) OR (p.resource = 'dashboard' AND p.action = 'view'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_SALES_STAFF
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_SALES_STAFF'
AND ((p.resource IN ('orders', 'billing') AND p.action IN ('create', 'read', 'update', 'process'))
    OR (p.resource = 'tables' AND p.action IN ('view', 'manage'))
    OR (p.resource = 'reservations' AND p.action IN ('read', 'update'))
    OR (p.resource = 'dashboard' AND p.action = 'view'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_HR_MANAGER
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_HR_MANAGER'
AND (p.module = 'hr' OR (p.resource = 'dashboard' AND p.action = 'view') OR (p.resource = 'reports' AND p.action = 'hr'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_HR_OFFICER
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_HR_OFFICER'
AND ((p.resource IN ('employees', 'attendance') AND p.action IN ('create', 'read', 'update', 'view', 'manage'))
    OR (p.resource = 'leaves' AND p.action = 'view')
    OR (p.resource = 'dashboard' AND p.action = 'view'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Z_FINANCE
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'Z_FINANCE'
AND (p.module = 'finance' OR (p.resource = 'dashboard' AND p.action = 'view') OR (p.resource = 'reports' AND p.action = 'financial'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 9. RPC FUNCTIONS
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

CREATE OR REPLACE FUNCTION get_user_warehouses(p_user_id UUID)
RETURNS TABLE (warehouse_id UUID, warehouse_code VARCHAR, warehouse_name VARCHAR, access_level VARCHAR) AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM user_roles ur INNER JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = p_user_id AND r.code = 'Z_ALL' AND ur.is_active = true) THEN
        RETURN QUERY SELECT w.id, w.code, w.name, 'full'::VARCHAR FROM warehouses w WHERE w.is_active = true;
    ELSE
        RETURN QUERY SELECT w.id, w.code, w.name, uwa.access_level FROM user_warehouse_access uwa INNER JOIN warehouses w ON w.id = uwa.warehouse_id WHERE uwa.user_id = p_user_id AND w.is_active = true;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_role(p_user_id UUID)
RETURNS TABLE (role_code VARCHAR, role_name VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT r.code, r.name FROM roles r INNER JOIN user_roles ur ON ur.role_id = r.id
    WHERE ur.user_id = p_user_id AND ur.is_active = true
    ORDER BY CASE r.code WHEN 'Z_ALL' THEN 1 WHEN 'Z_STOCK_MGR' THEN 2 WHEN 'Z_HR_MANAGER' THEN 3 ELSE 5 END
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION validate_issued_person(p_person_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM profiles WHERE id = p_person_id) OR EXISTS (SELECT 1 FROM employees WHERE user_id = p_person_id AND status = 'Active');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- PART 2: AUDIT LOGGING (015_audit_logging.sql)
-- =================================================================

CREATE TABLE IF NOT EXISTS change_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    doc_number VARCHAR(100),
    change_type VARCHAR(20) NOT NULL CHECK (change_type IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    changed_by UUID REFERENCES auth.users(id),
    changed_by_name TEXT,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    transaction_id TEXT,
    client_ip INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_change_log_table ON change_log(table_name);
CREATE INDEX IF NOT EXISTS idx_change_log_record ON change_log(record_id);
CREATE INDEX IF NOT EXISTS idx_change_log_changed_at ON change_log(changed_at);

CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    changed_fields_arr TEXT[];
    old_json JSONB;
    new_json JSONB;
    user_name TEXT;
    doc_num TEXT;
    key_field TEXT;
BEGIN
    SELECT COALESCE(full_name, email) INTO user_name FROM profiles p LEFT JOIN auth.users u ON u.id = p.id WHERE p.id = auth.uid();
    IF user_name IS NULL THEN user_name := 'System'; END IF;
    
    CASE TG_TABLE_NAME
        WHEN 'items' THEN key_field := 'item_code';
        WHEN 'purchase_orders' THEN key_field := 'doc_number';
        WHEN 'goods_receipt_notes' THEN key_field := 'doc_number';
        WHEN 'employees' THEN key_field := 'employee_code';
        ELSE key_field := NULL;
    END CASE;
    
    IF TG_OP = 'INSERT' THEN
        new_json := to_jsonb(NEW);
        IF key_field IS NOT NULL THEN doc_num := new_json->>key_field; END IF;
        INSERT INTO change_log (table_name, record_id, doc_number, change_type, old_values, new_values, changed_by, changed_by_name)
        VALUES (TG_TABLE_NAME, NEW.id, doc_num, 'INSERT', NULL, new_json, auth.uid(), user_name);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        old_json := to_jsonb(OLD); new_json := to_jsonb(NEW);
        IF key_field IS NOT NULL THEN doc_num := new_json->>key_field; END IF;
        SELECT array_agg(key) INTO changed_fields_arr FROM (SELECT key FROM jsonb_each(old_json) old_kv FULL OUTER JOIN jsonb_each(new_json) new_kv USING (key) WHERE old_kv.value IS DISTINCT FROM new_kv.value AND key NOT IN ('updated_at', 'created_at')) changes;
        IF changed_fields_arr IS NOT NULL AND array_length(changed_fields_arr, 1) > 0 THEN
            INSERT INTO change_log (table_name, record_id, doc_number, change_type, old_values, new_values, changed_fields, changed_by, changed_by_name)
            VALUES (TG_TABLE_NAME, NEW.id, doc_num, 'UPDATE', old_json, new_json, changed_fields_arr, auth.uid(), user_name);
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        old_json := to_jsonb(OLD);
        IF key_field IS NOT NULL THEN doc_num := old_json->>key_field; END IF;
        INSERT INTO change_log (table_name, record_id, doc_number, change_type, old_values, new_values, changed_by, changed_by_name)
        VALUES (TG_TABLE_NAME, OLD.id, doc_num, 'DELETE', old_json, NULL, auth.uid(), user_name);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS audit_items ON items;
CREATE TRIGGER audit_items AFTER INSERT OR UPDATE OR DELETE ON items FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

DROP TRIGGER IF EXISTS audit_purchase_orders ON purchase_orders;
CREATE TRIGGER audit_purchase_orders AFTER INSERT OR UPDATE OR DELETE ON purchase_orders FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

DROP TRIGGER IF EXISTS audit_goods_receipt_notes ON goods_receipt_notes;
CREATE TRIGGER audit_goods_receipt_notes AFTER INSERT OR UPDATE OR DELETE ON goods_receipt_notes FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

DROP TRIGGER IF EXISTS audit_employees ON employees;
CREATE TRIGGER audit_employees AFTER INSERT OR UPDATE OR DELETE ON employees FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE OR REPLACE FUNCTION get_change_history(p_table_name VARCHAR DEFAULT NULL, p_record_id UUID DEFAULT NULL, p_limit INTEGER DEFAULT 100)
RETURNS TABLE (id UUID, table_name VARCHAR, record_id UUID, doc_number VARCHAR, change_type VARCHAR, old_values JSONB, new_values JSONB, changed_fields TEXT[], changed_by_name TEXT, changed_at TIMESTAMP WITH TIME ZONE) AS $$
BEGIN
    RETURN QUERY SELECT cl.id, cl.table_name, cl.record_id, cl.doc_number, cl.change_type, cl.old_values, cl.new_values, cl.changed_fields, cl.changed_by_name, cl.changed_at FROM change_log cl
    WHERE (p_table_name IS NULL OR cl.table_name = p_table_name) AND (p_record_id IS NULL OR cl.record_id = p_record_id) ORDER BY cl.changed_at DESC LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- PART 3: RESTAURANT TABLES (016_restaurant_tables.sql)
-- =================================================================

CREATE TABLE IF NOT EXISTS restaurant_tables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_number VARCHAR(20) UNIQUE NOT NULL,
    capacity INTEGER NOT NULL DEFAULT 4,
    location VARCHAR(50),
    floor_number INTEGER DEFAULT 1,
    section VARCHAR(50),
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'reserved', 'cleaning', 'out_of_service')),
    current_order_id UUID,
    current_waiter_id UUID REFERENCES auth.users(id),
    position_x INTEGER,
    position_y INTEGER,
    shape VARCHAR(20) DEFAULT 'square' CHECK (shape IN ('square', 'round', 'rectangle')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reservations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reservation_number VARCHAR(50) UNIQUE NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20),
    customer_email VARCHAR(100),
    party_size INTEGER NOT NULL DEFAULT 2,
    table_id UUID REFERENCES restaurant_tables(id),
    reservation_date DATE NOT NULL,
    reservation_time TIME NOT NULL,
    duration_minutes INTEGER DEFAULT 90,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'seated', 'completed', 'no_show', 'cancelled')),
    special_requests TEXT,
    occasion VARCHAR(50),
    reminder_sent BOOLEAN DEFAULT false,
    confirmation_sent BOOLEAN DEFAULT false,
    created_by UUID REFERENCES auth.users(id),
    confirmed_by UUID REFERENCES auth.users(id),
    confirmed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION generate_reservation_number() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.reservation_number IS NULL THEN
        NEW.reservation_number := 'RES-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_reservation_number ON reservations;
CREATE TRIGGER set_reservation_number BEFORE INSERT ON reservations FOR EACH ROW EXECUTE FUNCTION generate_reservation_number();

INSERT INTO restaurant_tables (table_number, capacity, location, section, shape) VALUES
('T01', 2, 'Indoor', 'Main Hall', 'square'),
('T02', 2, 'Indoor', 'Main Hall', 'square'),
('T03', 4, 'Indoor', 'Main Hall', 'square'),
('T04', 4, 'Indoor', 'Main Hall', 'square'),
('T05', 6, 'Indoor', 'Main Hall', 'rectangle'),
('T06', 6, 'Indoor', 'Main Hall', 'rectangle'),
('T07', 8, 'Indoor', 'Private', 'rectangle'),
('T08', 4, 'Outdoor', 'Terrace', 'round'),
('T09', 4, 'Outdoor', 'Terrace', 'round'),
('T10', 10, 'Indoor', 'VIP Room', 'rectangle'),
('TK01', 0, 'Counter', 'Takeaway', 'square')
ON CONFLICT (table_number) DO NOTHING;

-- =================================================================
-- PART 4: PENDING APPROVALS VIEW
-- =================================================================

CREATE OR REPLACE VIEW pending_approvals AS
SELECT 'purchase_order' AS doc_type, po.id, po.doc_number, 'Purchase Order' AS description, po.total_amount AS amount, p.full_name AS requested_by, po.created_at AS requested_at, po.status
FROM purchase_orders po LEFT JOIN profiles p ON p.id = po.created_by WHERE po.status = 'pending'
UNION ALL
SELECT 'grn' AS doc_type, grn.id, grn.doc_number, 'Goods Receipt Note' AS description, grn.total_amount AS amount, p.full_name AS requested_by, grn.created_at AS requested_at, grn.status
FROM goods_receipt_notes grn LEFT JOIN profiles p ON p.id = grn.created_by WHERE grn.status = 'draft'
ORDER BY requested_at DESC;

CREATE OR REPLACE FUNCTION approve_document(p_doc_type VARCHAR, p_doc_id UUID, p_action VARCHAR DEFAULT 'approve')
RETURNS JSONB AS $$
BEGIN
    IF p_doc_type = 'purchase_order' THEN
        IF NOT has_permission(auth.uid(), 'purchase_orders', 'approve') THEN RETURN jsonb_build_object('success', false, 'error', 'No approval permission'); END IF;
        IF p_action = 'approve' THEN UPDATE purchase_orders SET status = 'approved', approved_by = auth.uid(), approved_at = NOW() WHERE id = p_doc_id AND status = 'pending';
        ELSE UPDATE purchase_orders SET status = 'cancelled' WHERE id = p_doc_id AND status = 'pending'; END IF;
    ELSIF p_doc_type = 'grn' THEN
        IF NOT has_permission(auth.uid(), 'grn', 'approve') THEN RETURN jsonb_build_object('success', false, 'error', 'No approval permission'); END IF;
        IF p_action = 'approve' THEN UPDATE goods_receipt_notes SET status = 'approved', approved_by = auth.uid(), approved_at = NOW() WHERE id = p_doc_id AND status = 'draft';
        ELSE UPDATE goods_receipt_notes SET status = 'cancelled' WHERE id = p_doc_id AND status = 'draft'; END IF;
    END IF;
    RETURN jsonb_build_object('success', true, 'doc_type', p_doc_type, 'doc_id', p_doc_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- PART 5: RLS POLICIES
-- =================================================================

ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_warehouse_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE change_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;

-- Allow read access
DROP POLICY IF EXISTS roles_read ON roles; CREATE POLICY roles_read ON roles FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS permissions_read ON permissions; CREATE POLICY permissions_read ON permissions FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS role_permissions_read ON role_permissions; CREATE POLICY role_permissions_read ON role_permissions FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS user_roles_read ON user_roles; CREATE POLICY user_roles_read ON user_roles FOR SELECT TO authenticated USING (user_id = auth.uid() OR has_permission(auth.uid(), 'users', 'manage'));
DROP POLICY IF EXISTS tables_read ON restaurant_tables; CREATE POLICY tables_read ON restaurant_tables FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS reservations_read ON reservations; CREATE POLICY reservations_read ON reservations FOR SELECT TO authenticated USING (true);

-- =================================================================
-- PART 6: MIGRATE EXISTING USERS
-- =================================================================

DO $$
DECLARE admin_role_id UUID; manager_role_id UUID; sales_role_id UUID; kitchen_role_id UUID;
BEGIN
    SELECT id INTO admin_role_id FROM roles WHERE code = 'Z_ALL';
    SELECT id INTO manager_role_id FROM roles WHERE code = 'Z_STOCK_MGR';
    SELECT id INTO sales_role_id FROM roles WHERE code = 'Z_SALES_STAFF';
    SELECT id INTO kitchen_role_id FROM roles WHERE code = 'Z_PROD_STAFF';
    
    INSERT INTO user_roles (user_id, role_id, is_active) SELECT p.id, admin_role_id, true FROM profiles p WHERE p.role = 'admin' ON CONFLICT DO NOTHING;
    INSERT INTO user_roles (user_id, role_id, is_active) SELECT p.id, manager_role_id, true FROM profiles p WHERE p.role = 'manager' ON CONFLICT DO NOTHING;
    INSERT INTO user_roles (user_id, role_id, is_active) SELECT p.id, sales_role_id, true FROM profiles p WHERE p.role IN ('cashier', 'waiter') ON CONFLICT DO NOTHING;
    INSERT INTO user_roles (user_id, role_id, is_active) SELECT p.id, kitchen_role_id, true FROM profiles p WHERE p.role = 'kitchen' ON CONFLICT DO NOTHING;
    
    UPDATE profiles SET role = 'Z_ALL' WHERE role = 'admin';
    UPDATE profiles SET role = 'Z_STOCK_MGR' WHERE role = 'manager';
    UPDATE profiles SET role = 'Z_SALES_STAFF' WHERE role IN ('cashier', 'waiter');
    UPDATE profiles SET role = 'Z_PROD_STAFF' WHERE role = 'kitchen';
END $$;

-- =================================================================
-- GRANT PERMISSIONS
-- =================================================================

GRANT ALL ON roles TO authenticated;
GRANT ALL ON permissions TO authenticated;
GRANT ALL ON role_permissions TO authenticated;
GRANT ALL ON user_roles TO authenticated;
GRANT ALL ON user_warehouse_access TO authenticated;
GRANT ALL ON change_log TO authenticated;
GRANT ALL ON restaurant_tables TO authenticated;
GRANT ALL ON reservations TO authenticated;
GRANT SELECT ON pending_approvals TO authenticated;

GRANT EXECUTE ON FUNCTION get_user_permissions TO authenticated;
GRANT EXECUTE ON FUNCTION has_permission TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_warehouses TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION validate_issued_person TO authenticated;
GRANT EXECUTE ON FUNCTION get_change_history TO authenticated;
GRANT EXECUTE ON FUNCTION approve_document TO authenticated;

-- =================================================================
-- SUCCESS MESSAGE
-- =================================================================

DO $$ BEGIN
    RAISE NOTICE '✅ RBAC SYSTEM INSTALLATION COMPLETE!';
    RAISE NOTICE '📊 Tables: roles, permissions, role_permissions, user_roles, user_warehouse_access, change_log, restaurant_tables, reservations';
    RAISE NOTICE '🔑 Roles: Z_ALL, Z_STOCK_MGR, Z_INV_CLERK, Z_PROD_STAFF, Z_SALES_STAFF, Z_HR_MANAGER, Z_HR_OFFICER, Z_FINANCE';
    RAISE NOTICE '🔒 RLS policies configured';
    RAISE NOTICE '📝 Audit logging enabled on: items, purchase_orders, goods_receipt_notes, employees';
END $$;
