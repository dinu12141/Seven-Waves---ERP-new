-- =================================================================
-- DEEP AUTH SCHEMA INVESTIGATION
-- Since triggers are clean (0 found), check deeper issues
-- =================================================================

-- Test 1: Can auth service access its own tables?
DO $$
DECLARE
    table_count INT;
    error_msg TEXT;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 1: Auth Schema Table Access';
    RAISE NOTICE '========================================';
    
    -- Try to count auth.users
    BEGIN
        SELECT COUNT(*) INTO table_count FROM auth.users;
        RAISE NOTICE '✓ auth.users accessible: % rows', table_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✗ Cannot access auth.users: %', SQLERRM;
    END;
    
    -- Try to count auth.identities
    BEGIN
        SELECT COUNT(*) INTO table_count FROM auth.identities;
        RAISE NOTICE '✓ auth.identities accessible: % rows', table_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✗ Cannot access auth.identities: %', SQLERRM;
    END;
    
    -- Try to count auth.sessions
    BEGIN
        SELECT COUNT(*) INTO table_count FROM auth.sessions;
        RAISE NOTICE '✓ auth.sessions accessible: % rows', table_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✗ Cannot access auth.sessions: %', SQLERRM;
    END;
END $$;

-- Test 2: Check if pgcrypto extension exists (CRITICAL for auth)
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 2: Required Extensions';
    RAISE NOTICE '========================================';
    
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
        RAISE NOTICE '✓ pgcrypto installed';
    ELSE
        RAISE NOTICE '✗ pgcrypto MISSING (CRITICAL!)';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp') THEN
        RAISE NOTICE '✓ uuid-ossp installed';
    ELSE
        RAISE NOTICE '⚠ uuid-ossp missing';
    END IF;
END $$;

-- Test 3: Check auth schema permissions in detail
DO $$
DECLARE
    perm_rec RECORD;
    has_perms BOOLEAN := false;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 3: Auth Schema Permissions';
    RAISE NOTICE '========================================';
    
    FOR perm_rec IN 
        SELECT 
            grantee,
            string_agg(privilege_type, ', ') as privileges
        FROM information_schema.schema_privileges
        WHERE schema_name = 'auth'
        GROUP BY grantee
        ORDER BY grantee
    LOOP
        has_perms := true;
        RAISE NOTICE '% -> %', perm_rec.grantee, perm_rec.privileges;
    END LOOP;
    
    IF NOT has_perms THEN
        RAISE NOTICE '✗ NO permissions found on auth schema!';
    END IF;
END $$;

-- Test 4: Check if there are any existing users
DO $$
DECLARE
    user_rec RECORD;
    user_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 4: Existing Users in auth.users';
    RAISE NOTICE '========================================';
    
    BEGIN
        FOR user_rec IN 
            SELECT id, email, created_at 
            FROM auth.users 
            ORDER BY created_at DESC 
            LIMIT 5
        LOOP
            user_count := user_count + 1;
            RAISE NOTICE 'User %: % (created: %)', user_count, user_rec.email, user_rec.created_at;
        END LOOP;
        
        IF user_count = 0 THEN
            RAISE NOTICE '⚠ No users found in auth.users';
        ELSE
            SELECT COUNT(*) INTO user_count FROM auth.users;
            RAISE NOTICE 'Total users: %', user_count;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✗ Error querying users: %', SQLERRM;
    END;
END $$;

-- Test 5: Check auth.users table structure
DO $$
DECLARE
    col_rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 5: auth.users Table Structure';
    RAISE NOTICE '========================================';
    
    BEGIN
        FOR col_rec IN 
            SELECT 
                column_name,
                data_type,
                is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'auth'
            AND table_name = 'users'
            ORDER BY ordinal_position
        LOOP
            RAISE NOTICE '  % (%) NULL:%', col_rec.column_name, col_rec.data_type, col_rec.is_nullable;
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✗ Cannot read auth.users structure: %', SQLERRM;
    END;
END $$;

-- Test 6: Check for auth helper functions
DO $$
DECLARE
    func_rec RECORD;
    func_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST 6: Auth Schema Functions';
    RAISE NOTICE '========================================';
    
    FOR func_rec IN 
        SELECT 
            routine_name
        FROM information_schema.routines
        WHERE routine_schema = 'auth'
        ORDER BY routine_name
        LIMIT 10
    LOOP
        func_count := func_count + 1;
        RAISE NOTICE 'auth.%', func_rec.routine_name;
    END LOOP;
    
    IF func_count = 0 THEN
        RAISE NOTICE '✗ No functions found in auth schema!';
    ELSE
        RAISE NOTICE 'Found % auth functions', func_count;
    END IF;
END $$;

-- Final Report
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 DEEP DIAGNOSIS COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CRITICAL CHECKS:';
    RAISE NOTICE '1. Can query auth.users?';
    RAISE NOTICE '2. pgcrypto extension installed?';
    RAISE NOTICE '3. Auth schema has permissions?';
    RAISE NOTICE '4. Users exist in database?';
    RAISE NOTICE '5. auth.users structure intact?';
    RAISE NOTICE '6. Auth functions exist?';
    RAISE NOTICE '';
    RAISE NOTICE 'Look for ✗ marks above for issues!';
END $$;
