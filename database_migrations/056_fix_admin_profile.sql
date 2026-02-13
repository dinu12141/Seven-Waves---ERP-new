-- =================================================================
-- MIGRATION 056: FIX ADMIN USER PROFILE & PERMISSIONS
-- =================================================================

-- 1. Ensure the Master Permission exists
INSERT INTO permissions (resource, action, module, description)
VALUES ('*', '*', '*', 'Super Admin Access')
ON CONFLICT (resource, action) DO NOTHING;

-- 2. Repair Admin Profile (admin@sevenwaves.com)
DO $$
DECLARE
    v_user_id UUID;
    v_perm_id UUID;
BEGIN
    -- Get User ID
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'admin@sevenwaves.com';

    IF v_user_id IS NOT NULL THEN
        -- Upsert Profile
        INSERT INTO public.profiles (id, user_id, email, full_name, role)
        VALUES (v_user_id, v_user_id, 'admin@sevenwaves.com', 'Super Admin', 'Z_ALL')
        ON CONFLICT (id) DO UPDATE 
        SET role = 'Z_ALL', full_name = 'Super Admin';

        -- Get Master Permission ID
        SELECT id INTO v_perm_id FROM permissions WHERE resource = '*' AND action = '*';

        -- Grant Master Permission
        IF v_perm_id IS NOT NULL THEN
            INSERT INTO public.user_permissions (user_id, permission_id, grant_type, granted_by)
            VALUES (v_user_id, v_perm_id, 'allow', v_user_id)
            ON CONFLICT (user_id, permission_id) DO UPDATE SET grant_type = 'allow';
        END IF;

        RAISE NOTICE '✅ Fixed admin@sevenwaves.com profile and permissions';
    ELSE
        RAISE NOTICE '⚠️ Admin user not found in auth.users';
    END IF;
END $$;

-- 3. Repair Alternate Admin (admin@admin.com) - Just in case they use this one
DO $$
DECLARE
    v_user_id UUID;
    v_perm_id UUID;
BEGIN
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'admin@admin.com';

    IF v_user_id IS NOT NULL THEN
        INSERT INTO public.profiles (id, user_id, email, full_name, role)
        VALUES (v_user_id, v_user_id, 'admin@admin.com', 'Admin User', 'Z_ALL')
        ON CONFLICT (id) DO UPDATE 
        SET role = 'Z_ALL';

        SELECT id INTO v_perm_id FROM permissions WHERE resource = '*' AND action = '*';

        IF v_perm_id IS NOT NULL THEN
            INSERT INTO public.user_permissions (user_id, permission_id, grant_type, granted_by)
            VALUES (v_user_id, v_perm_id, 'allow', v_user_id)
            ON CONFLICT (user_id, permission_id) DO UPDATE SET grant_type = 'allow';
        END IF;
    END IF;
END $$;
