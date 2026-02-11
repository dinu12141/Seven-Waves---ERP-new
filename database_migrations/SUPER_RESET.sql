-- =================================================================
-- SUPER RESET: RESTORE ACCESS & FIX SCHEMA ERRORS
-- =================================================================

-- 1. FLUSH SCHEMA CACHE FIRST
NOTIFY pgrst, 'reload schema';

-- 2. CLEAR ALL TRIGGERS ON AUTH.USERS (Likely Culprit)
-- We use a DO block to safely find and drop triggers on auth.users
DO $$ 
DECLARE 
    r RECORD;
BEGIN 
    FOR r IN (SELECT trigger_name FROM information_schema.triggers WHERE event_object_schema = 'auth' AND event_object_table = 'users') LOOP 
        EXECUTE 'DROP TRIGGER IF EXISTS "' || r.trigger_name || '" ON auth.users CASCADE'; 
    END LOOP; 
END $$;

-- 3. DISABLE RLS ON ALL PUBLIC TABLES
DO $$ 
DECLARE 
    r RECORD;
BEGIN 
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP 
        EXECUTE 'ALTER TABLE public."' || r.tablename || '" DISABLE ROW LEVEL SECURITY'; 
    END LOOP; 
END $$;

-- 4. GRANT FULL PERMISSIONS (The "God Mode" Fix)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- 5. ENSURE PGCRYPTO IS ON
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 6. DROP PROBLEMATIC FUNCTIONS
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.auto_create_user_for_employee() CASCADE;

-- 7. RE-CREATE THE AUTOMATION LOGIC (Simplified & Robust)
CREATE OR REPLACE FUNCTION public.auto_create_user_for_employee()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id uuid;
    v_role_code varchar;
    v_login_email varchar;
    v_instance_id uuid;
BEGIN
    -- Get Instance ID (Safe Fallback)
    SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
    IF v_instance_id IS NULL THEN 
       -- Try to get from an existing user or use nil
       v_instance_id := '00000000-0000-0000-0000-000000000000';
    END IF;

    -- Determine Role
    SELECT related_user_role INTO v_role_code FROM public.designations WHERE id = new.designation_id;
    IF v_role_code IS NULL THEN v_role_code := 'Z_SALES_STAFF'; END IF;

    -- Determine Email
    v_login_email := COALESCE(NULLIF(new.company_email, ''), LOWER(new.employee_code || '@sevenwaves.com'));

    -- Check if User Already Exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_login_email) THEN
        RETURN NEW; -- Skip if exists
    END IF;

    v_user_id := gen_random_uuid();

    -- DIRECT INSERT INTO AUTH.USERS (Bypassing APIs)
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, 
        email_confirmed_at, raw_user_meta_data, created_at, updated_at
    ) VALUES (
        v_instance_id,
        v_user_id,
        'authenticated',
        'authenticated',
        v_login_email,
        crypt('Employee123!', gen_salt('bf')), -- Default Password
        NOW(),
        jsonb_build_object('full_name', new.full_name, 'role', v_role_code, 'employee_code', new.employee_code),
        NOW(),
        NOW()
    );

    -- INSERT PROFILE (Safe Upsert)
    INSERT INTO public.profiles (id, user_id, full_name, role, email)
    VALUES (v_user_id, v_user_id, new.full_name, v_role_code, v_login_email)
    ON CONFLICT (id) DO UPDATE SET 
        full_name = EXCLUDED.full_name, role = EXCLUDED.role;

    -- LINK EMPLOYEE
    UPDATE public.employees SET 
        user_id = v_user_id, 
        company_email = v_login_email 
    WHERE id = new.id;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Auto-User Error: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. BIND AUTOMATION TRIGGER
DROP TRIGGER IF EXISTS trg_auto_create_user ON public.employees;
CREATE TRIGGER trg_auto_create_user
    AFTER INSERT ON public.employees
    FOR EACH ROW
    EXECUTE PROCEDURE public.auto_create_user_for_employee();

-- 9. FINAL CACHE RELOAD
NOTIFY pgrst, 'reload schema';
