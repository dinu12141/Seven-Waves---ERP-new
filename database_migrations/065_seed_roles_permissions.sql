-- =================================================================
-- MIGRATION: SEED SAP ROLES AND PERMISSIONS
-- =================================================================

DO $$
DECLARE
    -- Role IDs
    v_role_sales_staff UUID;
    v_role_stock_mgr UUID;
    v_role_inv_clerk UUID;
    v_role_prod_staff UUID;
    v_role_hr_mgr UUID;
    v_role_hr_officer UUID;
    v_role_finance UUID;
BEGIN
    -- 1. Create Roles if they don't exist
    
    -- Z_SALES_STAFF
    INSERT INTO roles (code, name, description, is_system_role)
    VALUES ('Z_SALES_STAFF', 'Sales Staff', 'Cashiers, Waiters, Sales Reps', true)
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_role_sales_staff;

    -- Z_STOCK_MGR
    INSERT INTO roles (code, name, description, is_system_role)
    VALUES ('Z_STOCK_MGR', 'Stock Manager', 'Inventory Managers', true)
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_role_stock_mgr;

    -- Z_INV_CLERK
    INSERT INTO roles (code, name, description, is_system_role)
    VALUES ('Z_INV_CLERK', 'Inventory Clerk', 'Store Keepers', true)
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_role_inv_clerk;

    -- Z_PROD_STAFF
    INSERT INTO roles (code, name, description, is_system_role)
    VALUES ('Z_PROD_STAFF', 'Production Staff', 'Kitchen Staff, Chefs', true)
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_role_prod_staff;

    -- Z_HR_MANAGER
    INSERT INTO roles (code, name, description, is_system_role)
    VALUES ('Z_HR_MANAGER', 'HR Manager', 'Human Resources Manager', true)
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_role_hr_mgr;

    -- Z_HR_OFFICER
    INSERT INTO roles (code, name, description, is_system_role)
    VALUES ('Z_HR_OFFICER', 'HR Officer', 'HR Assistants', true)
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_role_hr_officer;

    -- Z_FINANCE
    INSERT INTO roles (code, name, description, is_system_role)
    VALUES ('Z_FINANCE', 'Finance', 'Accountants, Finance Officers', true)
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_role_finance;


    -- 2. Ensure Permissions Exist (Based on routes.js meta.permission)
    -- We'll insert these permissions if they are missing.
    
    INSERT INTO permissions (module, action, description) VALUES
    ('dashboard', 'view', 'View Dashboard'),
    ('employees', 'read', 'View Employees'),
    ('employees', 'create', 'Create Employees'),
    ('attendance', 'view', 'View Attendance'),
    ('leaves', 'view', 'View Leaves'),
    ('salary', 'view', 'View Salary'),
    ('items', 'read', 'View Items'),
    ('items', 'update_price', 'Update Item Prices'),
    ('purchase_orders', 'read', 'View Purchase Orders'),
    ('warehouses', 'read', 'View Warehouses'),
    ('grn', 'read', 'View Goods Receipt Notes'),
    ('gin', 'read', 'View Goods Issue Notes'),
    ('stock', 'adjust', 'Adjust Stock Levels'),
    ('stock', 'view', 'View Stock Levels'),
    ('stock', 'transfer', 'Transfer Stock'),
    ('recipes', 'read', 'View Recipes'),
    ('stock_requests', 'read', 'View Stock Requests'),
    ('production_orders', 'read', 'View Production Orders'),
    ('billing', 'process', 'Process Billing'),
    ('tables', 'view', 'View Tables'),
    ('orders', 'read', 'View Orders'),
    ('kitchen', 'view', 'View Kitchen Display'),
    ('accounts', 'view', 'View Accounts'),
    ('transactions', 'view', 'View Transactions'),
    ('daily_cash', 'view', 'View Daily Cash'),
    ('reports', 'sales', 'View Sales Reports'),
    ('reports', 'inventory', 'View Inventory Reports'),
    ('users', 'view', 'View Users'),
    ('settings', 'view', 'View Settings'),
    ('pending_approvals', 'view', 'View Pending Approvals')
    ON CONFLICT (module, action) DO NOTHING;


    -- 3. Map Permissions to Roles
    
    -- Clear existing permissions for cleanup/update
    DELETE FROM role_permissions WHERE role_id IN (
        v_role_sales_staff, v_role_stock_mgr, v_role_inv_clerk, 
        v_role_prod_staff, v_role_hr_mgr, v_role_hr_officer, v_role_finance
    );

    -- Helper query to link permissions
    
    -- Z_SALES_STAFF (Billing, Orders, Tables, Dashboard)
    INSERT INTO role_permissions (role_id, permission_id)
    SELECT v_role_sales_staff, id FROM permissions WHERE 
       (module = 'dashboard' AND action = 'view') OR
       (module = 'billing' AND action = 'process') OR
       (module = 'tables' AND action = 'view') OR
       (module = 'orders' AND action = 'read') OR
       (module = 'reports' AND action = 'sales');

    -- Z_STOCK_MGR (All Stock, Reports, Dashboard, Pending Approvals)
    INSERT INTO role_permissions (role_id, permission_id)
    SELECT v_role_stock_mgr, id FROM permissions WHERE 
       (module = 'dashboard' AND action = 'view') OR
       (module IN ('items', 'warehouses', 'purchase_orders', 'grn', 'gin', 'stock', 'recipes', 'stock_requests', 'production_orders')) OR
       (module = 'reports' AND action IN ('sales', 'inventory')) OR
       (module = 'pending_approvals' AND action = 'view');

    -- Z_INV_CLERK (Stock Read/Write excluding Price/Approval stuff, Dashboard)
    INSERT INTO role_permissions (role_id, permission_id)
    SELECT v_role_inv_clerk, id FROM permissions WHERE 
       (module = 'dashboard' AND action = 'view') OR
       (module = 'items' AND action = 'read') OR
       (module = 'purchase_orders' AND action = 'read') OR
       (module = 'grn' AND action = 'read') OR
       (module = 'gin' AND action = 'read') OR
       (module = 'stock' AND action IN ('view', 'transfer')) OR
       (module = 'stock_requests' AND action = 'read');

    -- Z_PROD_STAFF (Kitchen, Recipes, Production Orders, Dashboard)
    INSERT INTO role_permissions (role_id, permission_id)
    SELECT v_role_prod_staff, id FROM permissions WHERE 
       (module = 'dashboard' AND action = 'view') OR
       (module = 'kitchen' AND action = 'view') OR
       (module = 'recipes' AND action = 'read') OR
       (module = 'production_orders' AND action = 'read');

    -- Z_HR_MANAGER (All HR, Approvals, Dashboard)
    INSERT INTO role_permissions (role_id, permission_id)
    SELECT v_role_hr_mgr, id FROM permissions WHERE 
       (module = 'dashboard' AND action = 'view') OR
       (module IN ('employees', 'attendance', 'leaves', 'salary')) OR
       (module = 'pending_approvals' AND action = 'view');

    -- Z_HR_OFFICER (HR View/Create excluding sensitive salary if needed, but for now assuming broad access)
    INSERT INTO role_permissions (role_id, permission_id)
    SELECT v_role_hr_officer, id FROM permissions WHERE 
       (module = 'dashboard' AND action = 'view') OR
       (module IN ('employees', 'attendance', 'leaves')); 
       -- Excluded Salary for officer for now, based on routes.js meta.roles

    -- Z_FINANCE (Finance Module, Dashboard)
    INSERT INTO role_permissions (role_id, permission_id)
    SELECT v_role_finance, id FROM permissions WHERE 
       (module = 'dashboard' AND action = 'view') OR
       (module IN ('accounts', 'transactions', 'daily_cash'));

END $$;
