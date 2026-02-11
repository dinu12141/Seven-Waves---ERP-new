-- =================================================================
-- MASTER PERMISSIONS FIX
-- Run this to resolve "Database error querying schema" & Permission Issues
-- =================================================================

-- 1. Grant Permissions to System Roles (Crucial for Auth)
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role, supabase_auth_admin;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role, supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role, supabase_auth_admin;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role, supabase_auth_admin;

-- 2. Ensure Supabase Auth Admin can execute functions
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO supabase_auth_admin;

-- 3. REMOVE ALL TRIGGERS ON AUTH.USERS (Dynamic & Aggressive)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name FROM information_schema.triggers WHERE event_object_schema = 'auth' AND event_object_table = 'users') LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS "' || r.trigger_name || '" ON auth.users CASCADE';
        RAISE NOTICE 'Dropped Trigger: %', r.trigger_name;
    END LOOP;
END $$;

-- 4. Restore Dummy Functions (To satisfy any deep dependencies)
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER AS $$ BEGIN RETURN NEW; END; $$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION public.auto_create_user_for_employee() RETURNS TRIGGER AS $$ BEGIN RETURN NEW; END; $$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION public.sync_user_profile() RETURNS TRIGGER AS $$ BEGIN RETURN NEW; END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Force Schema Cache Reload
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ Master Permissions Applied.';
    RAISE NOTICE '✅ All Auth Triggers Dropped.';
END $$;
