-- =================================================================
-- MIGRATION: UPDATE USER MANAGEMENT FUNCTIONS FOR GRANULAR PERMISSIONS
-- =================================================================

-- 1. Drop existing functions to avoid signature conflicts
DROP FUNCTION IF EXISTS public.admin_create_user(text, text, text, text, jsonb, uuid);
DROP FUNCTION IF EXISTS public.admin_update_user(uuid, text, text, text, text);

-- 2. Recreate admin_create_user with permission handling
CREATE OR REPLACE FUNCTION public.admin_create_user(
    p_email text,
    p_password text,
    p_full_name text,
    p_role_code text,
    p_permissions jsonb DEFAULT NULL, -- Array of permission IDs
    p_employee_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID;
    v_encrypted_pw TEXT;
    v_perm_id UUID;
    v_perm_item JSONB;
BEGIN
    -- Validate inputs
    IF p_email IS NULL OR p_password IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Email and password are required');
    END IF;

    -- Generate ID and Password Hash
    v_user_id := gen_random_uuid();
    v_encrypted_pw := crypt(p_password, gen_salt('bf'));

    -- Insert into auth.users
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
        is_sso_user
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_user_id,
        'authenticated',
        'authenticated',
        p_email,
        v_encrypted_pw,
        NOW(),
        NOW(),
        NOW(),
        '{"provider": "email", "providers": ["email"]}',
        jsonb_build_object(
            'full_name', p_full_name,
            'role', p_role_code
        ),
        FALSE,
        FALSE
    );

    -- Insert into auth.identities
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
        v_user_id::text,
        NOW(),
        NOW(),
        NOW()
    );

    -- Insert into public.profiles
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

    -- Handle Permissions
    IF p_permissions IS NOT NULL AND jsonb_array_length(p_permissions) > 0 THEN
        FOR v_perm_item IN SELECT * FROM jsonb_array_elements(p_permissions)
        LOOP
            -- Extract ID handling potential string/object structure
            IF jsonb_typeof(v_perm_item) = 'string' THEN
                v_perm_id := (v_perm_item #>> '{}')::uuid;
            ELSE
                 -- Assume it might be an object {id: ...} or just take the value
                v_perm_id := (v_perm_item->>'id')::uuid;
                IF v_perm_id IS NULL THEN
                     v_perm_id := (v_perm_item #>> '{}')::uuid; -- Fallback
                END IF;
            END IF;

            INSERT INTO user_permissions (user_id, permission_id, grant_type)
            VALUES (v_user_id, v_perm_id, 'explicit')
            ON CONFLICT DO NOTHING;
        END LOOP;
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
$function$;

-- 3. Create admin_update_user with permission handling
CREATE OR REPLACE FUNCTION public.admin_update_user(
    p_user_id uuid,
    p_email text,
    p_password text,
    p_full_name text,
    p_role text,
    p_permissions jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_item jsonb;
    v_perm_id uuid;
BEGIN
    -- Update auth.users (Email/Password if provided)
    UPDATE auth.users
    SET 
        email = COALESCE(p_email, email),
        encrypted_password = CASE WHEN p_password IS NOT NULL AND p_password <> '' 
                             THEN crypt(p_password, gen_salt('bf')) 
                             ELSE encrypted_password END,
        raw_user_meta_data = raw_user_meta_data || jsonb_build_object('full_name', p_full_name, 'role', p_role),
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Update public.profiles
    UPDATE public.profiles
    SET 
        email = COALESCE(p_email, email),
        full_name = p_full_name,
        role = p_role,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Update Permissions
    IF p_permissions IS NOT NULL THEN
        -- Clear existing explicit permissions (handle both 'explicit' and legacy 'allow')
        DELETE FROM user_permissions 
        WHERE user_id = p_user_id 
        AND (grant_type = 'explicit' OR grant_type = 'allow');

        -- Insert new permissions
        IF jsonb_array_length(p_permissions) > 0 THEN
             FOR v_item IN SELECT * FROM jsonb_array_elements(p_permissions)
             LOOP
                -- Handle both string IDs and object wrapper
                IF jsonb_typeof(v_item) = 'string' THEN
                    v_perm_id := (v_item #>> '{}')::uuid;
                ELSE
                    v_perm_id := (v_item->>'id')::uuid;
                    IF v_perm_id IS NULL THEN
                        v_perm_id := (v_item #>> '{}')::uuid; -- Fallback
                    END IF;
                END IF;

                INSERT INTO user_permissions (user_id, permission_id, grant_type)
                VALUES (p_user_id, v_perm_id, 'explicit')
                ON CONFLICT (user_id, permission_id) DO UPDATE
                SET grant_type = 'explicit', updated_at = NOW();
             END LOOP;
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- 4. Create standalone update_user_permissions for direct calls
CREATE OR REPLACE FUNCTION public.update_user_permissions(
    p_target_user_id uuid,
    p_permissions jsonb -- Array of strings (IDs) or objects
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_item jsonb;
    v_perm_id uuid;
    v_grant_type text;
BEGIN
    IF p_permissions IS NOT NULL THEN
        -- Clear existing explicit permissions (handle both 'explicit' and legacy 'allow')
        DELETE FROM user_permissions 
        WHERE user_id = p_target_user_id 
        AND (grant_type = 'explicit' OR grant_type = 'allow');

        IF jsonb_array_length(p_permissions) > 0 THEN
             FOR v_item IN SELECT * FROM jsonb_array_elements(p_permissions)
             LOOP
                -- Handle both string IDs and object wrapper
                IF jsonb_typeof(v_item) = 'string' THEN
                    v_perm_id := (v_item #>> '{}')::uuid;
                    v_grant_type := 'explicit';
                ELSE
                    v_perm_id := (v_item->>'id')::uuid;
                    IF v_perm_id IS NULL THEN
                         -- Try permission_id key as well for backward compatibility
                         v_perm_id := (v_item->>'permission_id')::uuid;
                    END IF;
                    IF v_perm_id IS NULL THEN
                         v_perm_id := (v_item #>> '{}')::uuid; -- Fallback
                    END IF;
                    v_grant_type := COALESCE(v_item->>'grant_type', 'explicit');
                END IF;

                INSERT INTO user_permissions (user_id, permission_id, grant_type, granted_by)
                VALUES (p_target_user_id, v_perm_id, v_grant_type, auth.uid())
                ON CONFLICT (user_id, permission_id) DO UPDATE 
                SET grant_type = EXCLUDED.grant_type, updated_at = NOW();
             END LOOP;
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Permissions updated successfully');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;
