-- =================================================================
-- COMPREHENSIVE AUTH SCHEMA DIAGNOSIS
-- Run this to see what's actually broken
-- =================================================================

-- Check 1: List ALL triggers on auth.users (including system ones)
DO $$
DECLARE
    trigger_rec RECORD;
    trigger_count INT := 0;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 1: Triggers on auth.users';
    RAISE NOTICE '========================================';
    
    FOR trigger_rec IN 
        SELECT 
            tgname,
            tgisinternal,
            pg_get_triggerdef(t.oid) as trigger_def
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'auth' 
        AND c.relname = 'users'
        ORDER BY tgisinternal, tgname
    LOOP
        trigger_count := trigger_count + 1;
        RAISE NOTICE 'Trigger %: % (Internal: %)', trigger_count, trigger_rec.tgname, trigger_rec.tgisinternal;
        RAISE NOTICE '  Definition: %', trigger_rec.trigger_def;
    END LOOP;
    
    IF trigger_count = 0 THEN
        RAISE NOTICE '✓ No triggers found';
    ELSE
        RAISE NOTICE 'Total triggers: %', trigger_count;
    END IF;
END $$;

-- Check 2: Verify auth schema tables exist
DO $$
DECLARE
    table_rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 2: Auth Schema Tables';
    RAISE NOTICE '========================================';
    
    FOR table_rec IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'auth'
        ORDER BY tablename
    LOOP
        RAISE NOTICE '✓ auth.%', table_rec.tablename;
    END LOOP;
END $$;

-- Check 3: Check for broken functions referenced by triggers
DO $$
DECLARE
    func_rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 3: Public Schema Trigger Functions';
    RAISE NOTICE '========================================';
    
    FOR func_rec IN 
        SELECT 
            routine_name,
            routine_type
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name LIKE '%user%'
        OR routine_name LIKE '%auth%'
        OR routine_name LIKE '%employee%'
        ORDER BY routine_name
    LOOP
        RAISE NOTICE '✓ %.% (%)', func_rec.routine_schema, func_rec.routine_name, func_rec.routine_type;
    END LOOP;
END $$;

-- Check 4: Verify user_profiles table structure
DO $$
DECLARE
    col_rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 4: user_profiles Table';
    RAISE NOTICE '========================================';
    
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_profiles') THEN
        RAISE NOTICE '✓ Table exists';
        
        FOR col_rec IN 
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'user_profiles'
            ORDER BY ordinal_position
        LOOP
            RAISE NOTICE '  - % (%) NULL:%', col_rec.column_name, col_rec.data_type, col_rec.is_nullable;
        END LOOP;
        
        -- Check RLS status
        IF EXISTS (
            SELECT FROM pg_tables 
            WHERE schemaname = 'public' 
            AND tablename = 'user_profiles' 
            AND rowsecurity = true
        ) THEN
            RAISE NOTICE '⚠ RLS is ENABLED';
        ELSE
            RAISE NOTICE '✓ RLS is DISABLED';
        END IF;
    ELSE
        RAISE NOTICE '✗ Table does NOT exist';
    END IF;
END $$;

-- Check 5: Test if we can query auth.users
DO $$
DECLARE
    user_count INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 5: Auth Users Query Test';
    RAISE NOTICE '========================================';
    
    BEGIN
        SELECT COUNT(*) INTO user_count FROM auth.users;
        RAISE NOTICE '✓ Can query auth.users: % users found', user_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✗ Cannot query auth.users: %', SQLERRM;
    END;
END $$;

-- Check 6: Check auth schema permissions
DO $$
DECLARE
    perm_rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 6: Auth Schema Permissions';
    RAISE NOTICE '========================================';
    
    FOR perm_rec IN 
        SELECT 
            grantee,
            privilege_type
        FROM information_schema.schema_privileges
        WHERE schema_name = 'auth'
        ORDER BY grantee, privilege_type
    LOOP
        RAISE NOTICE '✓ %: %', perm_rec.grantee, perm_rec.privilege_type;
    END LOOP;
END $$;

-- Check 7: Look for any auth-related extensions
DO $$
DECLARE
    ext_rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CHECK 7: Installed Extensions';
    RAISE NOTICE '========================================';
    
    FOR ext_rec IN 
        SELECT 
            extname,
            extversion,
            nspname as schema
        FROM pg_extension e
        JOIN pg_namespace n ON e.extnamespace = n.oid
        ORDER BY extname
    LOOP
        RAISE NOTICE '✓ %.% (v%)', ext_rec.schema, ext_rec.extname, ext_rec.extversion;
    END LOOP;
END $$;

-- Final Summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 DIAGNOSIS COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Review the output above to identify issues.';
    RAISE NOTICE 'Look for:';
    RAISE NOTICE '  - Custom triggers on auth.users';
    RAISE NOTICE '  - Missing auth tables';
    RAISE NOTICE '  - Broken function references';
    RAISE NOTICE '  - RLS enabled on user_profiles';
    RAISE NOTICE '  - Permission issues on auth schema';
END $$;
