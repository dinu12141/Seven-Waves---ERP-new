-- =================================================================
-- CHECK AUTH HEALTH
-- Run this and see if it returns data or an error.
-- =================================================================

DO $$
DECLARE
    v_count integer;
    r RECORD;
BEGIN
    -- 1. Try to read auth.users (Direct DB Access)
    SELECT count(*) INTO v_count FROM auth.users;
    RAISE NOTICE '✅ READ SUCCESS: auth.users contains % rows.', v_count;

    -- 2. Check for Triggers on auth.users
    RAISE NOTICE '--- Checking Triggers on auth.users ---';
    FOR r IN (SELECT trigger_name FROM information_schema.triggers WHERE event_object_schema = 'auth' AND event_object_table = 'users') LOOP 
        RAISE NOTICE '⚠️ WARNING: Found Trigger [%]', r.trigger_name;
    END LOOP;

    -- 3. Check for specific user
    PERFORM id FROM auth.users WHERE email = 'emp-2026-0005@sevenwaves.com';
    IF FOUND THEN
        RAISE NOTICE '✅ User emp-2026-0005 exists.';
    ELSE
        RAISE NOTICE '❌ User emp-2026-0005 NOT found.';
    END IF;

    -- 4. Check Public Permissions
    RAISE NOTICE '--- Checking Permissions ---';
    IF has_table_privilege('anon', 'public.employees', 'SELECT') THEN
        RAISE NOTICE '✅ Anon has SELECT on employees.';
    ELSE
        RAISE NOTICE '❌ Anon MISSING SELECT on employees.';
    END IF;

END $$;
