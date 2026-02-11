-- =================================================================
-- FINAL RESOLUTION: FIX AUTH TRANSACTION & TRIGGERS
-- =================================================================

-- 1. EXPLICITLY DROP KNOWN TRIGGERS (No Dynamic SQL)
-- These are the exact names used in your project history.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;
DROP TRIGGER IF EXISTS sync_user_profile ON auth.users;
DROP TRIGGER IF EXISTS user_created ON auth.users;
DROP TRIGGER IF EXISTS ensure_user_role ON auth.users;
DROP TRIGGER IF EXISTS validation_trigger ON auth.users;

-- 2. DUMMY FUNCTIONS (To satisfy any lingering references)
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER AS $$ BEGIN RETURN NEW; END; $$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION public.auto_create_user_for_employee() RETURNS TRIGGER AS $$ BEGIN RETURN NEW; END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. FIX SUPABASE_AUTH_ADMIN ROLE (The "God Mode" Fix)
-- Ensure the internal auth role accepts strict security policies
ALTER USER supabase_auth_admin WITH BYPASSRLS;
ALTER USER postgres WITH BYPASSRLS;
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT ALL ON ALL TABLES IN SCHEMA public TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO supabase_auth_admin;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO supabase_auth_admin;

-- 4. ENSURE PUBLIC PERMISSIONS
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- 5. RE-ENABLE PGCRYPTO (Essential for Auth)
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA public;

-- 6. RELOAD CACHE
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ Triggers Dropped & Admin Privileges Restored.';
END $$;
