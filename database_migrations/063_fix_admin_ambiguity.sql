-- =================================================================
-- MIGRATION: FIX AMBIGUOUS ADMIN CREATE USER FUNCTION
-- =================================================================

-- Drop ALL variations of the function to clear ambiguity
DROP FUNCTION IF EXISTS admin_create_user(text, text, text, text, jsonb, uuid);
DROP FUNCTION IF EXISTS admin_create_user(character varying, character varying, character varying, character varying, jsonb, uuid);

-- Recreate the single correct version using TEXT
CREATE OR REPLACE FUNCTION admin_create_user(
    p_email TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_role_code TEXT,
    p_permissions JSONB DEFAULT NULL,
    p_employee_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_encrypted_pw TEXT;
BEGIN
    -- Validate inputs
    IF p_email IS NULL OR p_password IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Email and password are required');
    END IF;

    -- Generate ID and Password Hash
    v_user_id := gen_random_uuid();
    v_encrypted_pw := crypt(p_password, gen_salt('bf'));

    -- Insert into auth.users (Using explicit columns matching standard Supabase schema)
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        raw_app_meta_data,
        raw_user_meta_data,
        is_super_admin,
        is_sso_user,
        phone,
        phone_change,
        phone_change_token,
        email_change,
        email_change_token_new,
        recovery_token,
        confirmation_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_user_id,
        'authenticated',
        'authenticated',
        p_email,
        v_encrypted_pw,
        NOW(), -- Auto-confirm email
        NOW(),
        NOW(),
        '{"provider": "email", "providers": ["email"]}',
        jsonb_build_object(
            'full_name', p_full_name,
            'role', p_role_code
        ),
        FALSE, -- is_super_admin
        FALSE, -- is_sso_user
        NULL, -- phone
        '',   -- phone_change
        '',   -- phone_change_token
        '',   -- email_change
        '',   -- email_change_token_new
        '',    -- recovery_token
        ''    -- confirmation_token
    );

    -- Insert into auth.identities (Required for login)
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        v_user_id,
        jsonb_build_object('sub', v_user_id, 'email', p_email, 'email_verified', true, 'phone_verified', false),
        'email',
        v_user_id::text, -- user_id is provider_id for email
        NOW(),
        NOW(),
        NOW()
    );

    -- Insert into public.profiles (Using standard call)
    INSERT INTO public.profiles (
        id,
        user_id,
        full_name,
        role,
        email,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        v_user_id,
        p_full_name,
        p_role_code,
        p_email,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET 
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        email = EXCLUDED.email;

    -- Link Employee if provided
    IF p_employee_id IS NOT NULL THEN
        UPDATE employees 
        SET user_id = v_user_id 
        WHERE id = p_employee_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'message', 'User created successfully'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_create_user(text, text, text, text, jsonb, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_create_user(text, text, text, text, jsonb, uuid) TO service_role;
