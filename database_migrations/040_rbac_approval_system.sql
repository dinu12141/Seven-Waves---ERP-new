-- =================================================================
-- MIGRATION 040: RBAC FIXES, JWT AUTH & APPROVAL SYSTEM
-- =================================================================

-- 1. FIX: PROFILES RLS (Infinite Recursion Fix)
--    Uses JWT metadata for role checks to avoid table recursion.
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update profiles" ON profiles;
DROP POLICY IF EXISTS "Profiles Access Policy" ON profiles;
DROP POLICY IF EXISTS "Admins Update Policy" ON profiles;
DROP POLICY IF EXISTS "Users Insert Own" ON profiles;

CREATE POLICY "Profiles Access Policy" ON profiles
    FOR SELECT TO authenticated
    USING (
        auth.uid() = id 
        OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin')
    );

CREATE POLICY "Admins Update Policy" ON profiles
    FOR UPDATE TO authenticated
    USING (
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin')
    );

CREATE POLICY "Users Insert Own" ON profiles
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = id);


-- 2. FIX: PERMISSIONS TABLE RLS
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read access to all authenticated users" ON permissions;
CREATE POLICY "Allow read access to all authenticated users" ON permissions
    FOR SELECT TO authenticated USING (true);


-- 3. UPDATED FUNCTION: ADMIN CREATE USER (Fixes Unauthorized Error)
--    Now uses JWT role check instead of querying profiles table.
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
    v_clean_email := LOWER(TRIM(p_email));

    -- A. Authorization Check (JWT based)
    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        -- Fallback: Check profile directly
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        IF v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
             RAISE EXCEPTION 'Unauthorized: Only administrators and HR managers can create users';
        END IF;
    END IF;

    -- B. Check if email already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RAISE EXCEPTION 'A user with email % already exists', v_clean_email;
    END IF;

    -- C. Get instance ID
    SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
    IF v_instance_id IS NULL THEN
        v_instance_id := '00000000-0000-0000-0000-000000000000';
    END IF;

    -- D. Create auth.users record
    v_user_id := gen_random_uuid();
    v_encrypted_pw := crypt(p_password, gen_salt('bf', 10));

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
        jsonb_build_object(
            'full_name', p_full_name,
            'role', p_role_code
        ),
        NOW(),
        NOW(),
        '',
        FALSE
    );

    -- E. Create profile
    INSERT INTO profiles (id, user_id, full_name, role, email)
    VALUES (v_user_id, v_user_id, p_full_name, p_role_code, v_clean_email)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        email = EXCLUDED.email;

    -- F. Assign role
    SELECT id INTO v_role_id FROM roles WHERE code = p_role_code;
    IF v_role_id IS NOT NULL THEN
        INSERT INTO user_roles (user_id, role_id)
        VALUES (v_user_id, v_role_id)
        ON CONFLICT DO NOTHING;
    END IF;

    -- G. Link to employee
    IF p_employee_id IS NOT NULL THEN
        UPDATE employees SET
            user_id = v_user_id,
            company_email = v_clean_email
        WHERE id = p_employee_id;
    END IF;

    -- H. Apply permissions
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
        'role', p_role_code,
        'message', 'User created successfully'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. UPDATED FUNCTION: ADMIN UPDATE USER
CREATE OR REPLACE FUNCTION admin_update_user(
    p_user_id UUID,
    p_email VARCHAR,
    p_password VARCHAR DEFAULT NULL,
    p_full_name VARCHAR DEFAULT NULL,
    p_role VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_clean_email VARCHAR;
    v_role_id UUID;
BEGIN
    v_clean_email := LOWER(TRIM(p_email));

    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        IF v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
             RAISE EXCEPTION 'Unauthorized: Only administrators can update users';
        END IF;
    END IF;

    -- Update auth.users
    UPDATE auth.users
    SET 
        email = v_clean_email,
        raw_user_meta_data = raw_user_meta_data || 
            jsonb_build_object(
                'role', COALESCE(p_role, raw_user_meta_data->>'role'),
                'full_name', COALESCE(p_full_name, raw_user_meta_data->>'full_name')
            ),
        updated_at = NOW(),
        encrypted_password = CASE 
            WHEN p_password IS NOT NULL AND LENGTH(p_password) > 0 
            THEN crypt(p_password, gen_salt('bf', 10))
            ELSE encrypted_password
        END
    WHERE id = p_user_id;

    -- Update profiles
    UPDATE profiles
    SET 
        full_name = COALESCE(p_full_name, full_name),
        role = COALESCE(p_role, role),
        email = v_clean_email,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Sync roles
    IF p_role IS NOT NULL THEN
        SELECT id INTO v_role_id FROM roles WHERE code = p_role;
        DELETE FROM user_roles WHERE user_id = p_user_id;
        IF v_role_id IS NOT NULL THEN
            INSERT INTO user_roles (user_id, role_id) VALUES (p_user_id, v_role_id);
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'User updated successfully');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. UPDATED FUNCTION: UPDATE PERMISSIONS (JWT Auth)
CREATE OR REPLACE FUNCTION update_user_permissions(
    p_target_user_id UUID,
    p_permissions JSONB 
)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_perm JSONB;
    v_perm_id UUID;
BEGIN
    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        -- Fallback
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        IF v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
            RAISE EXCEPTION 'Unauthorized: Only administrators and HR managers can modify permissions';
        END IF;
    END IF;

    DELETE FROM user_permissions WHERE user_id = p_target_user_id;

    IF p_permissions IS NOT NULL AND jsonb_array_length(p_permissions) > 0 THEN
        FOR v_perm IN SELECT * FROM jsonb_array_elements(p_permissions)
        LOOP
            v_perm_id := (v_perm->>'permission_id')::UUID;
            INSERT INTO user_permissions (user_id, permission_id, grant_type, granted_by)
            VALUES (
                p_target_user_id,
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

    RETURN jsonb_build_object('success', true, 'message', 'Permissions updated successfully');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. APPROVAL SYSTEM TABLES & FUNCTIONS (Unchanged from plan)
CREATE TABLE IF NOT EXISTS permission_change_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID REFERENCES auth.users(id) NOT NULL,
    target_user_id UUID REFERENCES auth.users(id) NOT NULL,
    requested_permissions JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    admin_comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pcr_status ON permission_change_requests(status);
CREATE INDEX IF NOT EXISTS idx_pcr_target ON permission_change_requests(target_user_id);
ALTER TABLE permission_change_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Access to requests" ON permission_change_requests;
CREATE POLICY "Access to requests" ON permission_change_requests
    FOR ALL TO authenticated
    USING (
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin')
        OR 
        auth.uid() = requester_id
    );

CREATE OR REPLACE FUNCTION request_permission_change(p_target_user_id UUID, p_permissions JSONB)
RETURNS JSONB AS $$
DECLARE
    v_req_id UUID;
BEGIN
    INSERT INTO permission_change_requests (requester_id, target_user_id, requested_permissions)
    VALUES (auth.uid(), p_target_user_id, p_permissions)
    RETURNING id INTO v_req_id;
    RETURN jsonb_build_object('success', true, 'request_id', v_req_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION process_permission_request(p_request_id UUID, p_status VARCHAR, p_admin_comment TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
    v_req RECORD;
    v_caller_role VARCHAR;
    v_perm_item JSONB;
BEGIN
    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;
    IF v_caller_role NOT IN ('Z_ALL', 'admin') THEN
         -- Fallback
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        IF v_caller_role NOT IN ('Z_ALL', 'admin') THEN
            RAISE EXCEPTION 'Unauthorized: Only Dashboard Admins can process requests';
        END IF;
    END IF;

    SELECT * INTO v_req FROM permission_change_requests WHERE id = p_request_id;
    IF v_req IS NULL THEN RAISE EXCEPTION 'Request not found'; END IF;
    IF v_req.status != 'pending' THEN RAISE EXCEPTION 'Request is already processed'; END IF;

    UPDATE permission_change_requests
    SET status = p_status, admin_comment = p_admin_comment, updated_at = NOW()
    WHERE id = p_request_id;

    IF p_status = 'approved' THEN
        DELETE FROM user_permissions WHERE user_id = v_req.target_user_id;
        IF v_req.requested_permissions IS NOT NULL AND jsonb_array_length(v_req.requested_permissions) > 0 THEN
            FOR v_perm_item IN SELECT * FROM jsonb_array_elements(v_req.requested_permissions)
            LOOP
                INSERT INTO user_permissions (user_id, permission_id, grant_type, granted_by)
                VALUES (
                    v_req.target_user_id,
                    (v_perm_item->>'permission_id')::UUID,
                    COALESCE(v_perm_item->>'grant_type', 'allow'),
                    auth.uid()
                )
                ON CONFLICT (user_id, permission_id) DO UPDATE SET
                    grant_type = EXCLUDED.grant_type, updated_at = NOW();
            END LOOP;
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Request processed successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION admin_update_user(UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION request_permission_change(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION process_permission_request(UUID, VARCHAR, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
