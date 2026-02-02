-- =================================================================
-- SEVEN WAVES ERP - MIGRATE EXISTING USERS TO NEW RBAC
-- Migration: 018_migrate_existing_users.sql
-- Run this AFTER 014_rbac_system.sql
-- =================================================================

-- =====================================================
-- MAP OLD ROLES TO NEW SAP ROLE CODES
-- =====================================================

DO $$
DECLARE
    admin_role_id UUID;
    manager_role_id UUID;
    cashier_role_id UUID;
    kitchen_role_id UUID;
    waiter_role_id UUID;
    hr_manager_role_id UUID;
    hr_officer_role_id UUID;
BEGIN
    -- Get role IDs
    SELECT id INTO admin_role_id FROM roles WHERE code = 'Z_ALL';
    SELECT id INTO manager_role_id FROM roles WHERE code = 'Z_STOCK_MGR';
    SELECT id INTO cashier_role_id FROM roles WHERE code = 'Z_SALES_STAFF';
    SELECT id INTO kitchen_role_id FROM roles WHERE code = 'Z_PROD_STAFF';
    SELECT id INTO waiter_role_id FROM roles WHERE code = 'Z_SALES_STAFF';
    SELECT id INTO hr_manager_role_id FROM roles WHERE code = 'Z_HR_MANAGER';
    SELECT id INTO hr_officer_role_id FROM roles WHERE code = 'Z_HR_OFFICER';
    
    -- Migrate users based on their current profile.role
    
    -- Admin users -> Z_ALL
    INSERT INTO user_roles (user_id, role_id, is_active)
    SELECT p.id, admin_role_id, true
    FROM profiles p
    WHERE p.role = 'admin'
    ON CONFLICT (user_id, role_id) DO NOTHING;
    
    -- Manager users -> Z_STOCK_MGR
    INSERT INTO user_roles (user_id, role_id, is_active)
    SELECT p.id, manager_role_id, true
    FROM profiles p
    WHERE p.role = 'manager'
    ON CONFLICT (user_id, role_id) DO NOTHING;
    
    -- Cashier users -> Z_SALES_STAFF
    INSERT INTO user_roles (user_id, role_id, is_active)
    SELECT p.id, cashier_role_id, true
    FROM profiles p
    WHERE p.role = 'cashier'
    ON CONFLICT (user_id, role_id) DO NOTHING;
    
    -- Kitchen users -> Z_PROD_STAFF
    INSERT INTO user_roles (user_id, role_id, is_active)
    SELECT p.id, kitchen_role_id, true
    FROM profiles p
    WHERE p.role = 'kitchen'
    ON CONFLICT (user_id, role_id) DO NOTHING;
    
    -- Waiter users -> Z_SALES_STAFF
    INSERT INTO user_roles (user_id, role_id, is_active)
    SELECT p.id, waiter_role_id, true
    FROM profiles p
    WHERE p.role = 'waiter'
    ON CONFLICT (user_id, role_id) DO NOTHING;
    
    -- HR Manager users -> Z_HR_MANAGER
    INSERT INTO user_roles (user_id, role_id, is_active)
    SELECT p.id, hr_manager_role_id, true
    FROM profiles p
    WHERE p.role = 'hr_manager'
    ON CONFLICT (user_id, role_id) DO NOTHING;
    
    -- HR Officer users -> Z_HR_OFFICER
    INSERT INTO user_roles (user_id, role_id, is_active)
    SELECT p.id, hr_officer_role_id, true
    FROM profiles p
    WHERE p.role = 'hr_officer'
    ON CONFLICT (user_id, role_id) DO NOTHING;
    
    -- Update profile.role to new SAP codes
    UPDATE profiles SET role = 'Z_ALL' WHERE role = 'admin';
    UPDATE profiles SET role = 'Z_STOCK_MGR' WHERE role = 'manager';
    UPDATE profiles SET role = 'Z_SALES_STAFF' WHERE role IN ('cashier', 'waiter');
    UPDATE profiles SET role = 'Z_PROD_STAFF' WHERE role = 'kitchen';
    UPDATE profiles SET role = 'Z_HR_MANAGER' WHERE role = 'hr_manager';
    UPDATE profiles SET role = 'Z_HR_OFFICER' WHERE role = 'hr_officer';
    
    RAISE NOTICE '✅ User migration complete!';
END $$;

-- =====================================================
-- ASSIGN ALL USERS TO DEFAULT WAREHOUSE (if exists)
-- =====================================================

INSERT INTO user_warehouse_access (user_id, warehouse_id, access_level)
SELECT ur.user_id, w.id, 'full'
FROM user_roles ur
CROSS JOIN warehouses w
WHERE w.is_default = true
ON CONFLICT (user_id, warehouse_id) DO NOTHING;

-- For admins, assign all warehouses
INSERT INTO user_warehouse_access (user_id, warehouse_id, access_level)
SELECT ur.user_id, w.id, 'full'
FROM user_roles ur
INNER JOIN roles r ON r.id = ur.role_id
CROSS JOIN warehouses w
WHERE r.code = 'Z_ALL'
ON CONFLICT (user_id, warehouse_id) DO NOTHING;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ Existing users migrated to new RBAC system!';
    RAISE NOTICE '🔄 Role mappings: admin->Z_ALL, manager->Z_STOCK_MGR, cashier/waiter->Z_SALES_STAFF, kitchen->Z_PROD_STAFF';
    RAISE NOTICE '🏭 Default warehouse access assigned to all users';
END $$;
