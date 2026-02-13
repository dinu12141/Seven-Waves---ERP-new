-- =================================================================
-- MIGRATION: ADD ADMIN UPDATE USER FUNCTION
-- =================================================================

CREATE OR REPLACE FUNCTION admin_update_user(
    p_user_id UUID,
    p_email TEXT DEFAULT NULL,
    p_password TEXT DEFAULT NULL,
    p_full_name TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    -- 1. Update Auth User (Email/Password)
    IF p_email IS NOT NULL OR p_password IS NOT NULL THEN
        -- Check if email usage
        IF p_email IS NOT NULL AND EXISTS (SELECT 1 FROM auth.users WHERE email = p_email AND id != p_user_id) THEN
             RETURN jsonb_build_object('success', false, 'error', 'Email already in use');
        END IF;

        UPDATE auth.users
        SET
            email = COALESCE(p_email, email),
            encrypted_password = CASE WHEN p_password IS NOT NULL THEN crypt(p_password, gen_salt('bf')) ELSE encrypted_password END,
            updated_at = NOW(),
            raw_user_meta_data = CASE 
                WHEN p_full_name IS NOT NULL OR p_role IS NOT NULL THEN 
                    raw_user_meta_data || jsonb_build_object(
                        'full_name', COALESCE(p_full_name, raw_user_meta_data->>'full_name'),
                        'role', COALESCE(p_role, raw_user_meta_data->>'role')
                    )
                ELSE raw_user_meta_data 
            END
        WHERE id = p_user_id;
    END IF;

    -- Update identity if email changed (Critical for login)
    IF p_email IS NOT NULL THEN
         UPDATE auth.identities
         SET 
            identity_data = jsonb_set(identity_data, '{email}', to_jsonb(p_email)),
            email = p_email
         WHERE user_id = p_user_id;
    END IF;

    -- 2. Update Profile (Name/Role)
    UPDATE public.profiles
    SET
        full_name = COALESCE(p_full_name, full_name),
        role = COALESCE(p_role, role),
        email = COALESCE(p_email, email), -- Sync email to profile
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN jsonb_build_object('success', true, 'message', 'User updated successfully');

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_update_user(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_update_user(uuid, text, text, text, text) TO service_role;
