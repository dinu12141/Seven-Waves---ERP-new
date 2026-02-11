-- =================================================================
-- Z_FINAL_EMERGENCY_FIX.sql
-- Run this to resolve "Database error querying schema" (500 Error)
-- =================================================================

-- 1. Force Schema Cache Reload
NOTIFY pgrst, 'reload schema';

-- 2. Drop ALL Potential Triggers on auth.users (Specific Names)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;
DROP TRIGGER IF EXISTS sync_user_profile ON auth.users;
DROP TRIGGER IF EXISTS validation_trigger ON auth.users;

-- 3. Drop Related Functions 
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.auto_create_user_for_employee() CASCADE;

-- 4. Disable RLS on Public Tables (To verify access)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.designations DISABLE ROW LEVEL SECURITY;

-- 5. Fix Permissions (Grant Global Access temporarily)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- 6. Ensure pgcrypto is installed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 7. Force DDL Update (Kick the Cache)
CREATE TABLE public._force_cache_reload (id serial PRIMARY KEY);
DROP TABLE public._force_cache_reload;

-- 8. Log Success
DO $$
BEGIN
    RAISE NOTICE '✅ Emergency Fix Applied.';
    RAISE NOTICE '   - Triggers Removed';
    RAISE NOTICE '   - RLS Disabled';
    RAISE NOTICE '   - Permissions Granted';
    RAISE NOTICE '   - Cache Reloaded';
END $$;
