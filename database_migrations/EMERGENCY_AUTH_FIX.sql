-- =================================================================
-- EMERGENCY FIX: AUTH SCHEMA DATABASE ERROR
-- Run this in Supabase SQL Editor immediately
-- =================================================================

-- Step 1: Remove ALL triggers on auth.users that might be causing issues
DO $$
DECLARE
    trigger_rec RECORD;
BEGIN
    -- Drop all custom triggers on auth.users
    FOR trigger_rec IN 
        SELECT tgname 
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'auth' 
        AND c.relname = 'users'
        AND NOT tgisinternal
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users CASCADE', trigger_rec.tgname);
        RAISE NOTICE 'Dropped trigger: %', trigger_rec.tgname;
    END LOOP;
END $$;

-- Step 2: Restore critical auth permissions
GRANT USAGE ON SCHEMA auth TO supabase_auth_admin, postgres;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin, postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin, postgres;

-- Fix public schema access for auth operations
GRANT USAGE ON SCHEMA public TO supabase_auth_admin, postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO supabase_auth_admin, postgres;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO supabase_auth_admin, postgres, anon, authenticated;

-- Step 3: Ensure bypass RLS for system roles
ALTER USER supabase_auth_admin WITH BYPASSRLS;
ALTER USER postgres WITH BYPASSRLS;

-- Step 4: Verify critical extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;

-- Step 5: Check if user_profiles table exists and has proper structure
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_profiles') THEN
        CREATE TABLE public.user_profiles (
            id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
            email TEXT,
            full_name TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );
        
        -- Disable RLS temporarily to allow auth operations
        ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;
        
        RAISE NOTICE 'Created user_profiles table';
    END IF;
END $$;

-- Step 6: Disable RLS on critical tables to allow auth operations
DO $$
DECLARE
    table_rec RECORD;
BEGIN
    FOR table_rec IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
        AND tablename IN ('user_profiles', 'user_roles', 'roles', 'permissions')
    LOOP
        EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', table_rec.tablename);
        RAISE NOTICE 'Disabled RLS on: %', table_rec.tablename;
    END LOOP;
END $$;

-- Step 7: Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ EMERGENCY AUTH FIX COMPLETED';
    RAISE NOTICE '========================================';
    RAISE NOTICE '1. All problematic triggers removed';
    RAISE NOTICE '2. Auth schema permissions restored';
    RAISE NOTICE '3. RLS disabled on auth-related tables';
    RAISE NOTICE '4. Schema cache reloaded';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 Try logging in again now';
    RAISE NOTICE '========================================';
END $$;
