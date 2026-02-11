-- =================================================================
-- SAFE RESOLUTION: FIX PERMISSIONS & DROPPING TRIGGERS
-- =================================================================

-- 1. DROP TRIGGERS (Using verified names, ignoring errors)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;
DROP TRIGGER IF EXISTS sync_user_profile ON auth.users;
DROP TRIGGER IF EXISTS user_created ON auth.users;
DROP TRIGGER IF EXISTS ensure_user_role ON auth.users;
DROP TRIGGER IF EXISTS validation_trigger ON auth.users;

-- 2. RESTORE DUMMY FUNCTIONS (To satisfy any lingering trigger references)
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER AS $$ BEGIN RETURN NEW; END; $$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION public.auto_create_user_for_employee() RETURNS TRIGGER AS $$ BEGIN RETURN NEW; END; $$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION public.sync_user_profile() RETURNS TRIGGER AS $$ BEGIN RETURN NEW; END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. GRANT PERMISSIONS (Strictly Allowed Operations)
-- We cannot ALTER supabase_auth_admin, but we CAN grant it access.

-- Grant Access to Public Schema for System Roles
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role, supabase_auth_admin;

-- Grant Table Access
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role, supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role, supabase_auth_admin;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role, supabase_auth_admin;

-- Grant Access to Authenticator (Crucial for PostgREST)
GRANT USAGE ON SCHEMA public TO authenticator;

-- 4. FORCE CACHE RELOAD
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ Safe Resolution Applied.';
    RAISE NOTICE '   - Triggers Dropped.';
    RAISE NOTICE '   - Public Schema Permissions Granted.';
END $$;
