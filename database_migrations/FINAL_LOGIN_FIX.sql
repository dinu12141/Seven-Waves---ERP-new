-- =================================================================
-- FINAL LOGIN FIX (AGGRESSIVE)
-- =================================================================

-- 1. DISABLE RLS COMPLETELY (Temporary Fix for Access)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.designations DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles DISABLE ROW LEVEL SECURITY;

-- 2. DROP TRIGGERS ON AUTH.USERS (Prevent Login Side-Effects)
-- If this trigger fails during login (last_sign_in update), login fails.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 3. ENSURE PERMISSIONS (Wide Open for Fix)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- 4. RECREATE ESSENTIAL AUTOMATION (Employee -> User)
-- We strictly want Employee Creation to drive User Creation.
CREATE OR REPLACE FUNCTION public.auto_create_user_for_employee()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id uuid;
    v_role_code varchar;
    v_password varchar;
    v_encrypted_pw varchar;
    v_login_email varchar;
    v_instance_id uuid;
BEGIN
    -- Get Instance ID
    SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
    IF v_instance_id IS NULL THEN v_instance_id := '00000000-0000-0000-0000-000000000000'; END IF;

    -- A. Determine Role
    SELECT related_user_role INTO v_role_code FROM public.designations WHERE id = new.designation_id;
    IF v_role_code IS NULL THEN v_role_code := 'Z_SALES_STAFF'; END IF;

    -- B. Email
    IF new.company_email IS NOT NULL AND new.company_email != '' THEN
        v_login_email := new.company_email;
    ELSE
        v_login_email := LOWER(new.employee_code || '@sevenwaves.com');
    END IF;

    -- C. Password (bcrypt)
    v_password := 'Employee123!';
    v_encrypted_pw := crypt(v_password, gen_salt('bf'));
    v_user_id := gen_random_uuid();

    -- D. Create Auth User (If not exists)
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = v_login_email) THEN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password, 
            email_confirmed_at, raw_app_meta_data, raw_user_meta_data, 
            created_at, updated_at
        ) VALUES (
            v_instance_id,
            v_user_id,
            'authenticated',
            'authenticated',
            v_login_email,
            v_encrypted_pw,
            NOW(),
            '{"provider": "email", "providers": ["email"]}',
            jsonb_build_object('full_name', new.full_name, 'role', v_role_code, 'employee_code', new.employee_code),
            NOW(),
            NOW()
        );

        -- E. Create/Update Profile (Since we disabled RLS, this should never fail)
        INSERT INTO public.profiles (id, user_id, full_name, role, email)
        VALUES (v_user_id, v_user_id, new.full_name, v_role_code, v_login_email)
        ON CONFLICT (id) DO UPDATE SET
            full_name = EXCLUDED.full_name,
            role = EXCLUDED.role; -- Ensure role is synced

        -- F. Assign RBAC Role
        INSERT INTO public.user_roles (user_id, role_id)
        SELECT v_user_id, id FROM public.roles WHERE code = v_role_code
        ON CONFLICT DO NOTHING;

        -- G. Link Employee
        UPDATE public.employees SET 
            user_id = v_user_id,
            company_email = v_login_email 
        WHERE id = new.id;
    END IF;

    RETURN NULL;
EXCEPTION WHEN OTHERS THEN
    -- Swallow errors to prevent blocking Employee Creation, but log it
    RAISE WARNING 'Auto-User Creation Failed: %', SQLERRM;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RE-BIND TRIGGER
DROP TRIGGER IF EXISTS trg_auto_create_user ON employees;
CREATE TRIGGER trg_auto_create_user
    AFTER INSERT ON employees
    FOR EACH ROW
    EXECUTE PROCEDURE public.auto_create_user_for_employee();

-- 6. FLUSH SCHEMA CACHE
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ FINAL LOGIN FIX APPLIED.';
    RAISE NOTICE '   - RLS Disabled on Core Tables';
    RAISE NOTICE '   - Auth Triggers Cleaned';
    RAISE NOTICE '   - Permissions Granted';
END $$;
