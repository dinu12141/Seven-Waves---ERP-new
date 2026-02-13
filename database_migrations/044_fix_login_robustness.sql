-- =================================================================
-- MIGRATION 044: ROBUST LOGIN FIX & CLEANUP
-- =================================================================

-- 1. ENSURE EXTENSIONS ARE AVAILABLE
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 2. DROP ALL REMAINING TRIGGERS ON AUTH.USERS
--    (Safety measure: some might be named differently)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_signup ON auth.users;
DROP TRIGGER IF EXISTS on_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_signup ON auth.users;
DROP TRIGGER IF EXISTS create_profile_on_signup ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;
DROP TRIGGER IF EXISTS check_for_duplicate_emails ON auth.users;
DROP TRIGGER IF EXISTS sync_user_metadata ON auth.users;

-- 3. REDEFINE ADMIN_CREATE_USER WITH EXPLICIT SEARCH PATH
--    This ensures 'crypt' and 'gen_salt' are found correctly.
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
    -- Set search path to ensure extensions are found
    -- schema 'extensions' is where pgcrypto usually lives in Supabase
    -- schema 'public' is for our tables
    -- schema 'auth' is for auth tables
    PERFORM set_config('search_path', 'public, extensions, auth', true);

    v_clean_email := LOWER(TRIM(p_email));

    -- A. Authorization Check
    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        IF v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
             RAISE EXCEPTION 'Unauthorized: Only administrators and HR managers can create users';
        END IF;
    END IF;

    -- B. Check existence
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RAISE EXCEPTION 'A user with email % already exists', v_clean_email;
    END IF;

    -- C. Get Instance ID (Robust fallback)
    SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
    IF v_instance_id IS NULL THEN
        -- Default for hosted supabase
        v_instance_id := '00000000-0000-0000-0000-000000000000'; 
    END IF;

    -- D. Prepare Data
    v_user_id := gen_random_uuid();
    
    -- IMPORTANT: Explicitly use extensions.crypt and extensions.gen_salt if searching fails
    -- But since we set search_path, crypt() should work.
    -- We force cost 10 for Supabase compatibility.
    v_encrypted_pw := crypt(p_password, gen_salt('bf', 10));

    -- E. Insert into auth.users
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
        NOW(), -- Auto-confirm
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        jsonb_build_object(
            'full_name', p_full_name,
            'role', p_role_code
        ),
        NOW(),
        NOW(),
        '',
        FALSE
    );

    -- F. Create profile
    INSERT INTO profiles (id, user_id, full_name, role, email)
    VALUES (v_user_id, v_user_id, p_full_name, p_role_code, v_clean_email)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        email = EXCLUDED.email;

    -- G. Assign role
    SELECT id INTO v_role_id FROM roles WHERE code = p_role_code;
    IF v_role_id IS NOT NULL THEN
        INSERT INTO user_roles (user_id, role_id)
        VALUES (v_user_id, v_role_id)
        ON CONFLICT DO NOTHING;
    END IF;

    -- H. Link to employee
    IF p_employee_id IS NOT NULL THEN
        UPDATE employees SET
            user_id = v_user_id,
            company_email = v_clean_email
        WHERE id = p_employee_id;
    END IF;

    -- I. Permissions
    IF p_permissions IS NOT NULL AND jsonb_array_length(p_permissions) > 0 THEN
        FOR v_perm IN SELECT * FROM jsonb_array_elements(p_permissions)
        LOOP
            v_perm_id := (v_perm->>'permission_id')::UUID;
            INSERT INTO user_permissions (user_id, permission_id, grant_type, granted_by)
            VALUES (
                v_user_id,
                v_perm_id,
                COALESCE(v_perm->>'grant_type', 'allow'),
                auth.uid()
            )
            ON CONFLICT (user_id, permission_id) DO UPDATE SET
                grant_type = EXCLUDED.grant_type,
                granted_by = EXCLUDED.granted_by,
                updated_at = NOW();
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true, 
        'user_id', v_user_id, 
        'email', v_clean_email,
        'message', 'User created successfully'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. HELPER FUNCTION TO FIX BROKEN PASSWORDS (EMERGENCY TOOL)
CREATE OR REPLACE FUNCTION admin_reset_password(
    p_email VARCHAR,
    p_new_password VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    v_clean_email VARCHAR;
    v_encrypted_pw VARCHAR;
BEGIN
    PERFORM set_config('search_path', 'public, extensions, auth', true);
    v_clean_email := LOWER(TRIM(p_email));
    
    -- Authorization check (simplified for emergency)
    IF (auth.jwt() -> 'user_metadata' ->> 'role') NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
         RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_encrypted_pw := crypt(p_new_password, gen_salt('bf', 10));

    UPDATE auth.users
    SET encrypted_password = v_encrypted_pw,
        updated_at = NOW()
    WHERE email = v_clean_email;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Password reset successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RELOAD SCHEMA
NOTIFY pgrst, 'reload schema';
