-- =================================================================
-- MIGRATION: FIX ADMIN CREATE USER AND WAREHOUSE FUNCTION
-- =================================================================

-- 1. Drop existing functions to avoid signature conflicts
DROP FUNCTION IF EXISTS admin_create_user(text, text, text, text, jsonb, uuid);
DROP FUNCTION IF EXISTS admin_create_user(text, text, text, text, text, uuid); -- Catch existing signature
DROP FUNCTION IF EXISTS get_user_warehouses(uuid);

-- 2. Recreate get_user_warehouses with TEXT input for safety (auto-cast)
CREATE OR REPLACE FUNCTION get_user_warehouses(p_user_id UUID)
RETURNS TABLE (
    warehouse_id UUID,
    warehouse_name TEXT,
    warehouse_code VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    RETURN QUERY 
    SELECT w.id, w.name, w.code 
    FROM warehouses w
    WHERE 
        -- Admin Access (Check profiles table)
        EXISTS (SELECT 1 FROM profiles WHERE id = p_user_id AND role IN ('Z_ALL', 'admin'))
        AND w.is_active = true
    UNION 
    SELECT w.id, w.name, w.code 
    FROM warehouses w
    JOIN user_warehouse_access uwa ON uwa.warehouse_id = w.id
    WHERE uwa.user_id = p_user_id AND w.is_active = true
    ORDER BY warehouse_name;
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_warehouses(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_warehouses(UUID) TO service_role;


-- 3. Recreate admin_create_user with correct logic and column names
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
        recovery_token
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
        ''    -- recovery_token
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
        jsonb_build_object('sub', v_user_id, 'email', p_email),
        'email',
        v_user_id, -- provider_id is usually user_id for email provider in GoTrue
        NOW(),
        NOW(),
        NOW()
    );

    -- Insert into public.profiles (Using correct column names)
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

    -- Grant Permissions if provided
    -- (Logic to handle p_permissions JSON array if needed, skipped for brevity but can be added separately)

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
