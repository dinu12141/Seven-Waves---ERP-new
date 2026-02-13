-- =================================================================
-- MIGRATION 059: CLEAN RECREATE OF ADMIN USER
-- =================================================================

-- 1. Clean up existing admin users to start fresh
DELETE FROM auth.users WHERE email IN ('admin@sevenwaves.lk', 'admin@admin.com');

-- 2. Use our robust 'admin_create_user' function to create the admin correctly
--    This ensures password hashing (bcrypt cost 10), metadata, profile, and permissions are all set perfectly.
DO $$
DECLARE
    v_result JSONB;
BEGIN
    -- Create admin@sevenwaves.lk
    -- Password: 'Admin123!'
    v_result := admin_create_user(
        p_email := 'admin@sevenwaves.lk',
        p_password := 'Admin123!',
        p_full_name := 'System Administrator',
        p_role_code := 'Z_ALL',
        p_permissions := NULL, -- Will get Master Permission via trigger or manual grant below
        p_employee_id := NULL
    );
    
    RAISE NOTICE 'Created admin@sevenwaves.lk: %', v_result;

    -- Create admin@admin.com (Backup)
    -- Password: 'Admin123!'
    v_result := admin_create_user(
        p_email := 'admin@admin.com',
        p_password := 'Admin123!',
        p_full_name := 'Backup Admin',
        p_role_code := 'Z_ALL'
    );
    
    RAISE NOTICE 'Created admin@admin.com: %', v_result;
END $$;


-- 3. Double-check: Grant Master Permission Explicitly
--    (Just in case admin_create_user didn't add it automatically)
DO $$
DECLARE
    v_user_id UUID;
    v_perm_id UUID;
BEGIN
    -- For admin@sevenwaves.lk
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'admin@sevenwaves.lk';
    SELECT id INTO v_perm_id FROM permissions WHERE module = '*' AND action = '*';

    IF v_user_id IS NOT NULL AND v_perm_id IS NOT NULL THEN
        INSERT INTO public.user_permissions (user_id, permission_id, grant_type, granted_by)
        VALUES (v_user_id, v_perm_id, 'allow', v_user_id)
        ON CONFLICT (user_id, permission_id) DO UPDATE SET grant_type = 'allow';
    END IF;

    -- For admin@admin.com
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'admin@admin.com';
    
    IF v_user_id IS NOT NULL AND v_perm_id IS NOT NULL THEN
        INSERT INTO public.user_permissions (user_id, permission_id, grant_type, granted_by)
        VALUES (v_user_id, v_perm_id, 'allow', v_user_id)
        ON CONFLICT (user_id, permission_id) DO UPDATE SET grant_type = 'allow';
    END IF;
END $$;
