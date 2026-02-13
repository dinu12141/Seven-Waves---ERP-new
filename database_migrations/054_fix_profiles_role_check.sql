-- =================================================================
-- MIGRATION 054: Fix profiles_role_check constraint
-- =================================================================
-- The old constraint only allows legacy role names (admin, manager, etc.)
-- but the new RBAC system uses Z_ prefixed codes (Z_ALL, Z_SALES_STAFF, etc.)
-- This drops the old constraint and adds one that allows ALL role codes.
-- =================================================================

-- Drop the old restrictive constraint
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Add new constraint that allows both legacy and new Z_ role codes
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
CHECK (role IN (
    -- New RBAC roles
    'Z_ALL',
    'Z_STOCK_MGR',
    'Z_INV_CLERK',
    'Z_PROD_STAFF',
    'Z_SALES_STAFF',
    'Z_SALES_MGR',
    'Z_HR_MANAGER',
    'Z_HR_OFFICER',
    'Z_WAITER',
    'Z_CASHIER',
    -- Legacy roles (for backward compatibility)
    'admin',
    'manager',
    'cashier',
    'kitchen',
    'waiter',
    'director',
    'hr_manager',
    'hr_officer'
));

-- Reload schema
SELECT pg_reload_conf();
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ MIGRATION 054 COMPLETE: profiles_role_check updated with Z_ role codes';
END $$;
