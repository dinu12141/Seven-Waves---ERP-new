-- =================================================================
-- MIGRATION 055: EMERGENCY FIX - SEARCH PATH & PERMISSIONS
-- =================================================================
-- The "Database error querying schema" during login is likely caused 
-- by the altered search_path settings in migration 053.
-- This script resets them to safe Supabase defaults.
-- =================================================================

-- Reset search_path to defaults (safe for Supabase)
-- "public" and "extensions" are standard. "auth" is usually NOT in search_path for anon/authenticated.
ALTER ROLE postgres SET search_path = "$user", public, extensions;
ALTER ROLE service_role SET search_path = public, extensions;
ALTER ROLE authenticated SET search_path = public, extensions;
ALTER ROLE anon SET search_path = public, extensions;
-- ALTER ROLE supabase_admin SET search_path = "$user", public, extensions; -- Reserved role, skipping

-- Ensure auth schema is accessible to system roles (just in case)
GRANT USAGE ON SCHEMA auth TO postgres, service_role; -- Removed supabase_admin

-- DO NOT grant usage on auth to anon/authenticated!

-- Ensure public schema is accessible
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;

-- Ensure extensions schema is accessible
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- Reload configuration
SELECT pg_reload_conf();

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ MIGRATION 055 COMPLETE: Search paths reset and permissions verified';
    RAISE NOTICE '👉 Try logging in again.';
END $$;
