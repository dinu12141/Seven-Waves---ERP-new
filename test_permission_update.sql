
DO $$
DECLARE
    v_user_id uuid;
    v_perm_id uuid;
    v_result jsonb;
    v_count int;
BEGIN
    -- 1. Create a dummy user
    v_user_id := gen_random_uuid();
    INSERT INTO auth.users (id, email) VALUES (v_user_id, 'test_perm_update@example.com');
    INSERT INTO public.profiles (id, user_id, email, role, full_name) 
    VALUES (v_user_id, v_user_id, 'test_perm_update@example.com', 'Z_SALES_STAFF', 'Test User');

    -- 2. Get a valid permission ID
    SELECT id INTO v_perm_id FROM permissions LIMIT 1;
    IF v_perm_id IS NULL THEN
        RAISE NOTICE 'No permissions found to test with';
        RETURN;
    END IF;

    -- 3. Call admin_update_user with permissions
    -- Passing permissions as a JSONB array of strings (IDs)
    v_result := public.admin_update_user(
        p_user_id := v_user_id,
        p_email := 'test_perm_update@example.com',
        p_password := NULL,
        p_full_name := 'Test User Updated',
        p_role := 'Z_SALES_STAFF',
        p_permissions := jsonb_build_array(v_perm_id)
    );

    IF (v_result->>'success')::boolean IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'admin_update_user failed: %', v_result;
    END IF;

    -- 4. Verify permissions
    SELECT COUNT(*) INTO v_count 
    FROM user_permissions 
    WHERE user_id = v_user_id AND permission_id = v_perm_id;

    IF v_count = 1 THEN
        RAISE NOTICE 'SUCCESS: Permission correctly assigned';
    ELSE
        RAISE NOTICE 'FAILURE: Permission NOT assigned. Count: %', v_count;
    END IF;

    -- 5. Cleanup
    DELETE FROM user_permissions WHERE user_id = v_user_id;
    DELETE FROM public.profiles WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error: %', SQLERRM;
    -- Try to cleanup
    DELETE FROM user_permissions WHERE user_id = v_user_id;
    DELETE FROM public.profiles WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
END $$;
