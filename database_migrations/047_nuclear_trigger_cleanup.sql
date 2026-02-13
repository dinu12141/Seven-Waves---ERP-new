-- =================================================================
-- MIGRATION 047: NUCLEAR TRIGGER CLEANUP & SEARCH PATH RESET
-- =================================================================

-- 1. DYNAMICALLY DROP ALL TRIGGERS ON auth.users
--    This iterates through the system catalog and drops everything attached to auth.users.
--    This is necessary because some triggers might have auto-generated names or names we missed.
DO $$
DECLARE
    trig_record RECORD;
BEGIN
    FOR trig_record IN 
        SELECT trigger_name 
        FROM information_schema.triggers 
        WHERE event_object_schema = 'auth' 
        AND event_object_table = 'users'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users;', trig_record.trigger_name);
        RAISE NOTICE 'Dropped trigger: % on auth.users', trig_record.trigger_name;
    END LOOP;
END $$;


-- 2. DYNAMICALLY DROP ALL TRIGGERS ON profiles
DO $$
DECLARE
    trig_record RECORD;
BEGIN
    FOR trig_record IN 
        SELECT trigger_name 
        FROM information_schema.triggers 
        WHERE event_object_schema = 'public' 
        AND event_object_table = 'profiles'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON profiles;', trig_record.trigger_name);
        RAISE NOTICE 'Dropped trigger: % on profiles', trig_record.trigger_name;
    END LOOP;
END $$;


-- 3. RESET ROLE SEARCH PATHS TO SAFE DEFAULTS
--    In case previous migration messed up extensions visibility for superusers.
ALTER ROLE postgres SET search_path = public, extensions, auth;
ALTER ROLE service_role SET search_path = public, extensions, auth;
ALTER ROLE authenticated SET search_path = public, extensions, auth;
ALTER ROLE anon SET search_path = public, extensions, auth;


-- 4. EMERGENCY PERMISSIONS GRANT
--    Ensure extensions (pgcrypto) are absolutely accessible.
GRANT USAGE ON SCHEMA extensions TO public;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO public;


-- 5. RELOAD SCHEMA
NOTIFY pgrst, 'reload schema';
