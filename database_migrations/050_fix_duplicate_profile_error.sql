-- =================================================================
-- MIGRATION 050: FIX DUPLICATE PROFILE ERROR & TRIGGER CLEANUP
-- =================================================================

-- 1. DROP ALL TRIGGERS AGAIN (Just to be absolutely safe)
--    We are doing this dynamically to catch any zombies.
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


-- 2. RE-CREATE ADMIN_CREATE_USER WITH UPSERT ON USER_ID
--    This fixes the "duplicate key value violates unique constraint profiles_user_id_key" error.
CREATE OR REPLACE FUNCTION admin_create_user(
    p_email VARCHAR,
    p_password VARCHAR,
    p_full_name VARCHAR DEFAULT 'New User',
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
    v_actual_full_name VARCHAR;
BEGIN
    -- Force search path inside function
    PERFORM set_config('search_path', 'public, extensions, auth', true);

    -- Ensure full_name is NOT NULL for the logic
    v_actual_full_name := COALESCE(TRIM(p_full_name), 'New User');
    IF v_actual_full_name = '' THEN v_actual_full_name := 'New User'; END IF;

    v_clean_email := LOWER(TRIM(p_email));

    -- Authorization Check
    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        IF v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
             RAISE EXCEPTION 'Unauthorized';
        END IF;
    END IF;

    -- Check if user already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RAISE EXCEPTION 'Email % already exists', v_clean_email;
    END IF;

    -- Get Instance ID (Supabase internal)
    SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
    IF v_instance_id IS NULL THEN v_instance_id := '00000000-0000-0000-0000-000000000000'; END IF;

    -- Create UUID and Encrypted Password
    v_user_id := gen_random_uuid();
    v_encrypted_pw := extensions.crypt(p_password, extensions.gen_salt('bf', 10));

    -- A. INSERT INTO auth.users
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
        jsonb_build_object('full_name', v_actual_full_name, 'role', p_role_code),
        NOW(),
        NOW(),
        '',
        FALSE
    );

    -- B. INSERT INTO profiles (With Conflict Handling for user_id)
    --    We use "ON CONFLICT (id)" AND "ON CONFLICT (user_id)" logic via UPDATE check.
    
    -- First, try to update if it exists (covers trigger case or manual insert race)
    UPDATE profiles 
    SET full_name = v_actual_full_name, role = p_role_code, email = v_clean_email
    WHERE user_id = v_user_id;

    IF NOT FOUND THEN
        -- If update didn't run, insert it.
        BEGIN
            INSERT INTO profiles (id, user_id, full_name, role, email)
            VALUES (v_user_id, v_user_id, v_actual_full_name, p_role_code, v_clean_email);
        EXCEPTION WHEN unique_violation THEN
            -- If we hit a unique violation here, it means a race condition happened between the Update check and Insert.
            -- In that case, we can try Update one last time or ignore it.
            UPDATE profiles 
            SET full_name = v_actual_full_name, role = p_role_code, email = v_clean_email
            WHERE user_id = v_user_id;
        END;
    END IF;

    -- C. ASSIGN ROLE
    SELECT id INTO v_role_id FROM roles WHERE code = p_role_code;
    IF v_role_id IS NOT NULL THEN
        INSERT INTO user_roles (user_id, role_id) VALUES (v_user_id, v_role_id) ON CONFLICT DO NOTHING;
    END IF;

    -- D. LINK TO EMPLOYEE
    IF p_employee_id IS NOT NULL THEN
        UPDATE employees SET user_id = v_user_id, company_email = v_clean_email WHERE id = p_employee_id;
    END IF;

    -- E. CUSTOM PERMISSIONS
    IF p_permissions IS NOT NULL AND jsonb_array_length(p_permissions) > 0 THEN
        FOR v_perm IN SELECT * FROM jsonb_array_elements(p_permissions)
        LOOP
            v_perm_id := (v_perm->>'permission_id')::UUID;
            IF v_perm_id IS NOT NULL THEN
                INSERT INTO user_permissions (user_id, permission_id, grant_type, granted_by)
                VALUES (v_user_id, v_perm_id, COALESCE(v_perm->>'grant_type', 'allow'), auth.uid())
                ON CONFLICT (user_id, permission_id) DO UPDATE SET grant_type = EXCLUDED.grant_type, updated_at = NOW();
            END IF;
        END LOOP;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'User created successfully', 'user_id', v_user_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. RELOAD SCHEMA
NOTIFY pgrst, 'reload schema';
