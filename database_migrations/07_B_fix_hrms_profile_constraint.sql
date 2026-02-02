-- =================================================================
-- STEP 2: Update Profile Constraints with New Roles
-- Run this AFTER 07_fix_hrms_roles.sql
-- =================================================================

DO $$
BEGIN
    -- Check if profiles table has role column
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'role'
    ) THEN
        -- Drop existing constraint if any
        ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
        
        -- Add new constraint with HRMS roles
        ALTER TABLE profiles ADD CONSTRAINT profiles_role_check 
        CHECK (role IN ('admin', 'manager', 'cashier', 'kitchen', 'waiter', 'director', 'hr_manager', 'hr_officer'));
    
    ELSE
        -- Add role column if it doesn't exist
        ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'waiter';
    END IF;
END $$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Step 2 Complete: Profile constraints updated.';
    RAISE NOTICE '👉 NOW RUN: 08_hrms_module.sql';
END $$;
