-- =================================================================
-- STEP 1: Add HRMS Roles to user_role ENUM
-- Run this file FIRST correctly committed.
-- =================================================================

DO $$
BEGIN
    -- Check if user_role enum exists and add new values
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        -- Add director if not exists
        BEGIN
            ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'director';
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
        
        -- Add hr_manager if not exists
        BEGIN
            ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'hr_manager';
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
        
        -- Add hr_officer if not exists
        BEGIN
            ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'hr_officer';
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
END $$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Step 1 Complete: Roles added to Enum.';
    RAISE NOTICE '👉 NOW RUN: 07_B_fix_hrms_profile_constraint.sql';
END $$;
