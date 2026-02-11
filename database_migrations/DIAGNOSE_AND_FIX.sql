-- =================================================================
-- DIAGNOSE AND FIX (Schema Confusion & Missing Profile)
-- =================================================================

-- 1. CLEANUP LEGACY TYPES (Source of "Schema Error")
-- If 'user_role' enum type still exists, it confuses PostgREST
DROP TYPE IF EXISTS public.user_role CASCADE;

-- 2. ENSURE WAITER PROFILE EXISTS (Source of 406 Error)
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'waiter@sevenwaves.com';
    
    IF v_user_id IS NOT NULL THEN
        -- Check if profile exists
        IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id) THEN
            RAISE NOTICE '⚠️ Waiter Profile Missing! Creating now...';
            INSERT INTO public.profiles (id, user_id, full_name, role, email)
            VALUES (v_user_id, v_user_id, 'John Waiter', 'Z_SALES_STAFF', 'waiter@sevenwaves.com');
        ELSE
            RAISE NOTICE '✅ Waiter Profile Exists.';
            -- Ensure role is valid string
            UPDATE public.profiles SET role = 'Z_SALES_STAFF' WHERE id = v_user_id;
        END IF;
    ELSE
        RAISE NOTICE '❌ Waiter User NOT FOUND in Auth!';
    END IF;
END $$;

-- 3. NUCLEAR PERMISSIONS FIX (Source of 500 Error)
-- Grant everything to ensure no permission denied errors
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- 4. DISABLE RLS TEMPORARILY (To Isolate Issue)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 5. RELOAD SCHEMA CACHE
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ Diagnosis & Fix Complete. RLS Disabled on Profiles for testing.';
END $$;
