-- =================================================================
-- MIGRATION 051: FIX API GATEWAY & AUTHENTICATOR SEARCH PATH
-- =================================================================

-- 1. INSURE EXTENSIONS SCHEMA EXISTS & IS PUBLIC
--    This is critical for Supabase Auth to verify passwords.
CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role, dashboard_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO postgres, anon, authenticated, service_role, dashboard_user;

-- 2. MOVE PGCRYPTO TO EXTENSIONS (Best Practice)
--    If it's in public, we leave it alone, but ensure extensions has it too if needed.
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;


-- 3. FIX THE "AUTHENTICATOR" ROLE (The Hidden Culprit)
--    This role handles the API requests. If its search_path is broken,
--    it cannot find the auth schema or cryptographic functions during login.
DO $$
BEGIN
    -- Try to set search_path for authenticator if the role exists
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
        ALTER ROLE authenticator SET search_path = public, extensions, auth;
    END IF;
    
    -- (Removed attempt to alter supabase_admin as it is a reserved superuser role)
END $$;


-- 4. GRANT AUTH SCHEMA USAGE TO AUTHENTICATOR
--    The authenticator needs to switch to other roles, but it might need
--    basic visibility to the auth schema itself during handshake.
GRANT USAGE ON SCHEMA auth TO postgres, anon, authenticated, service_role;


-- 5. RELOAD CONFIGURATION
--    Force the database to reload its config to pick up role changes immediately.
SELECT pg_reload_conf();
NOTIFY pgrst, 'reload schema';
