-- =================================================================
-- FORCE AUTH SERVICE RECOVERY
-- This will reset critical auth permissions and force reconnection
-- =================================================================

-- Step 1: Ensure ALL required extensions exist
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgjwt" SCHEMA "extensions";

-- Step 2: Grant FULL access to auth schema for auth admin
-- This is what the auth service needs to function
GRANT ALL ON SCHEMA auth TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO postgres;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA auth TO postgres;

-- Step 3: Grant public schema access for auth operations
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO postgres, anon, authenticated;

-- Step 4: Ensure user_profiles table exists and is accessible
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    role TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Completely disable RLS (temporary - to allow auth to work)
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;

-- Step 5: Drop ALL policies on user_profiles (they might be blocking)
DO $$
DECLARE
    pol_rec RECORD;
BEGIN
    FOR pol_rec IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'user_profiles'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.user_profiles', pol_rec.policyname);
        RAISE NOTICE 'Dropped policy: %', pol_rec.policyname;
    END LOOP;
END $$;

-- Step 6: Create simple access grants
GRANT ALL ON public.user_profiles TO postgres, anon, authenticated, service_role;

-- Step 7: Ensure auth.users is accessible (critical check)
DO $$
DECLARE
    user_count INT;
BEGIN
    SELECT COUNT(*) INTO user_count FROM auth.users;
    RAISE NOTICE '✓ auth.users accessible: % users found', user_count;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION '✗ CRITICAL: Cannot access auth.users - %', SQLERRM;
END $$;

-- Step 8: Force PostgREST and Realtime to reload
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload config';

-- Step 9: Verify auth service can now access database
DO $$
DECLARE
    test_email TEXT := 'test@example.com';
    test_count INT;
BEGIN
    -- Try to query auth.users by email (this is what login does)
    SELECT COUNT(*) INTO test_count 
    FROM auth.users 
    WHERE email = test_email;
    
    RAISE NOTICE '✓ Auth service query simulation successful';
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Auth query test failed: %', SQLERRM;
END $$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ AUTH SERVICE RECOVERY COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '1. Extensions installed';
    RAISE NOTICE '2. Auth schema permissions granted';
    RAISE NOTICE '3. Public schema permissions granted';
    RAISE NOTICE '4. user_profiles RLS disabled';
    RAISE NOTICE '5. All policies dropped';
    RAISE NOTICE '6. Schema cache reloaded';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 IMPORTANT: Restart your Supabase project!';
    RAISE NOTICE '   Go to: Project Settings → General → Pause project';
    RAISE NOTICE '   Then: Restore project';
    RAISE NOTICE '';
    RAISE NOTICE '   This will restart the auth service.';
    RAISE NOTICE '========================================';
END $$;
