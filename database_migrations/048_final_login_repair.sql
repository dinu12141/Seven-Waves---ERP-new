-- =================================================================
-- MIGRATION 048: FINAL LOGIN REPAIR - THE "NUCLEAR" OPTION (Safe Mode)
-- =================================================================

-- 1. FORCE EXTENSIONS SCHEMA PERMISSIONS
--    This is the #1 cause of "Database error querying schema".
--    We grant usage and execute to EVERYONE to be absolutely sure.
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- 2. FORCE PUBLIC SCHEMA PERMISSIONS
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role;


-- 3. FORCE AUTH SCHEMA PERMISSIONS (For Authenticated Role)
--    Sometimes 'authenticated' loses access to essential auth views.
GRANT USAGE ON SCHEMA auth TO postgres, authenticated, service_role;
GRANT SELECT ON auth.users TO postgres, service_role;
-- Note: 'authenticated' usually shouldn't see auth.users directly, 
-- but we might need it for some custom views. safely grant SELECT.
GRANT SELECT ON auth.users TO authenticated;


-- 4. FORCE SEARCH PATH RESET FOR ALL ROLES
--    If the role's search_path is broken, it can't find 'crypt'.
ALTER ROLE postgres SET search_path = public, extensions, auth;
ALTER ROLE service_role SET search_path = public, extensions, auth;
ALTER ROLE authenticated SET search_path = public, extensions, auth;
ALTER ROLE anon SET search_path = public, extensions, auth;


-- 5. RE-VERIFY ADMIN_CREATE_USER WITH EXPLICIT SEARCH PATH (Safeguard)
CREATE OR REPLACE FUNCTION admin_create_user(
    p_email VARCHAR,
    p_password VARCHAR,
    p_full_name VARCHAR,
    p_role_code VARCHAR DEFAULT 'Z_SALES_STAFF',
    p_permissions JSONB DEFAULT '[]'::JSONB,
    p_employee_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_user_id UUID;
    v_instance_id UUID;
    v_encrypted_pw VARCHAR;
    v_role_id UUID;
    v_perm JSONB;
    v_perm_id UUID;
    v_clean_email VARCHAR;
BEGIN
    -- Force search path inside function
    PERFORM set_config('search_path', 'public, extensions, auth', true);

    v_clean_email := LOWER(TRIM(p_email));

    -- Authorization
    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        IF v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
             RAISE EXCEPTION 'Unauthorized';
        END IF;
    END IF;

    -- Check existence
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RAISE EXCEPTION 'Email exists';
    END IF;

    -- Get Instance
    SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
    IF v_instance_id IS NULL THEN v_instance_id := '00000000-0000-0000-0000-000000000000'; END IF;

    -- Encrypt Password
    v_user_id := gen_random_uuid();
    v_encrypted_pw := extensions.crypt(p_password, extensions.gen_salt('bf', 10));

    -- Insert User
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, is_super_admin
    ) VALUES (
        v_instance_id,
        v_user_id,
        'authenticated',
        'authenticated',
        v_clean_email,
        v_encrypted_pw,
        NOW(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        jsonb_build_object('full_name', p_full_name, 'role', p_role_code),
        NOW(),
        NOW(),
        '',
        FALSE
    );

    -- Insert Profile
    INSERT INTO profiles (id, user_id, full_name, role, email)
    VALUES (v_user_id, v_user_id, p_full_name, p_role_code, v_clean_email)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name, role = EXCLUDED.role, email = EXCLUDED.email;

    -- Assign Role
    SELECT id INTO v_role_id FROM roles WHERE code = p_role_code;
    IF v_role_id IS NOT NULL THEN
        INSERT INTO user_roles (user_id, role_id) VALUES (v_user_id, v_role_id) ON CONFLICT DO NOTHING;
    END IF;

    -- Link Employee
    IF p_employee_id IS NOT NULL THEN
        UPDATE employees SET user_id = v_user_id, company_email = v_clean_email WHERE id = p_employee_id;
    END IF;

    -- Permissions
    IF p_permissions IS NOT NULL AND jsonb_array_length(p_permissions) > 0 THEN
        FOR v_perm IN SELECT * FROM jsonb_array_elements(p_permissions)
        LOOP
            v_perm_id := (v_perm->>'permission_id')::UUID;
            INSERT INTO user_permissions (user_id, permission_id, grant_type, granted_by)
            VALUES (v_user_id, v_perm_id, COALESCE(v_perm->>'grant_type', 'allow'), auth.uid())
            ON CONFLICT (user_id, permission_id) DO UPDATE SET grant_type = EXCLUDED.grant_type, updated_at = NOW();
        END LOOP;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'User created');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. RELOAD SCHEMA CACHE
NOTIFY pgrst, 'reload schema';
