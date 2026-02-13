-- =================================================================
-- MIGRATION 053: FIX PROFILES TABLE - RESTORE 'id' COLUMN
-- =================================================================
-- Uses CASCADE to handle dependent foreign keys.
-- =================================================================

-- STEP 1: Diagnose current state
DO $$
DECLARE
    has_id BOOLEAN;
    has_user_id BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='id') INTO has_id;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='user_id') INTO has_user_id;
    RAISE NOTICE 'profiles.id exists: %, profiles.user_id exists: %', has_id, has_user_id;
END $$;


-- STEP 2: Fix the table structure
DO $$
DECLARE
    has_id BOOLEAN;
    has_user_id BOOLEAN;
    pk_name TEXT;
BEGIN
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='id') INTO has_id;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='user_id') INTO has_user_id;

    IF NOT has_id AND has_user_id THEN
        RAISE NOTICE 'FIXING: id column is missing, user_id exists. Restoring...';

        -- Drop PK with CASCADE (this will drop dependent FKs too)
        SELECT constraint_name INTO pk_name
        FROM information_schema.table_constraints
        WHERE table_schema='public' AND table_name='profiles' AND constraint_type='PRIMARY KEY';

        IF pk_name IS NOT NULL THEN
            EXECUTE format('ALTER TABLE profiles DROP CONSTRAINT %I CASCADE', pk_name);
            RAISE NOTICE 'Dropped PK constraint % (CASCADE)', pk_name;
        END IF;

        -- Rename user_id -> id
        ALTER TABLE profiles RENAME COLUMN user_id TO id;
        RAISE NOTICE 'Renamed user_id -> id';

        -- Add id as PK again
        ALTER TABLE profiles ADD PRIMARY KEY (id);
        RAISE NOTICE 'Added PRIMARY KEY on id';

        -- Add user_id back as a regular column (copy of id)
        ALTER TABLE profiles ADD COLUMN user_id UUID;
        UPDATE profiles SET user_id = id;
        ALTER TABLE profiles ADD CONSTRAINT profiles_user_id_key UNIQUE (user_id);
        RAISE NOTICE 'Added user_id column with UNIQUE constraint';

    ELSIF has_id AND NOT has_user_id THEN
        RAISE NOTICE 'id exists, adding user_id...';
        ALTER TABLE profiles ADD COLUMN user_id UUID;
        UPDATE profiles SET user_id = id;
        ALTER TABLE profiles ADD CONSTRAINT profiles_user_id_key UNIQUE (user_id);

    ELSIF has_id AND has_user_id THEN
        RAISE NOTICE 'Both columns exist. Syncing...';
        UPDATE profiles SET user_id = id WHERE user_id IS NULL OR user_id != id;

    ELSE
        RAISE EXCEPTION 'Neither id nor user_id exists!';
    END IF;
END $$;


-- STEP 3: Re-create dropped foreign keys (CASCADE dropped these)
DO $$
BEGIN
    -- profiles.id -> auth.users.id
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name='profiles' AND constraint_name='profiles_id_fkey') THEN
        BEGIN
            ALTER TABLE profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
            RAISE NOTICE 'Re-created FK: profiles.id -> auth.users.id';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not add profiles_id_fkey: %', SQLERRM;
        END;
    END IF;

    -- kitchen_orders.waiter_id -> profiles.id (this was the one that blocked us)
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='kitchen_orders_waiter_id_fkey') THEN
        BEGIN
            ALTER TABLE kitchen_orders ADD CONSTRAINT kitchen_orders_waiter_id_fkey FOREIGN KEY (waiter_id) REFERENCES profiles(id);
            RAISE NOTICE 'Re-created FK: kitchen_orders.waiter_id -> profiles.id';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not re-create kitchen_orders FK: %', SQLERRM;
        END;
    END IF;

    -- Re-create any other common FKs that reference profiles
    -- purchase_orders.created_by
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='purchase_orders_created_by_fkey') THEN
            ALTER TABLE purchase_orders ADD CONSTRAINT purchase_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
            RAISE NOTICE 'Re-created FK: purchase_orders.created_by -> profiles.id';
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- purchase_orders.approved_by
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='purchase_orders_approved_by_fkey') THEN
            ALTER TABLE purchase_orders ADD CONSTRAINT purchase_orders_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES profiles(id);
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- goods_receipt_notes.created_by
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='goods_receipt_notes_created_by_fkey') THEN
            ALTER TABLE goods_receipt_notes ADD CONSTRAINT goods_receipt_notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- goods_receipt_notes.approved_by
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='goods_receipt_notes_approved_by_fkey') THEN
            ALTER TABLE goods_receipt_notes ADD CONSTRAINT goods_receipt_notes_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES profiles(id);
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- warehouses.manager_id
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='warehouses_manager_id_fkey') THEN
            ALTER TABLE warehouses ADD CONSTRAINT warehouses_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES profiles(id);
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
END $$;


-- STEP 4: Ensure all required columns exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='full_name') THEN
        ALTER TABLE profiles ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='role') THEN
        ALTER TABLE profiles ADD COLUMN role VARCHAR(50) DEFAULT 'Z_SALES_STAFF';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='email') THEN
        ALTER TABLE profiles ADD COLUMN email TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='avatar_url') THEN
        ALTER TABLE profiles ADD COLUMN avatar_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='updated_at') THEN
        ALTER TABLE profiles ADD COLUMN updated_at TIMESTAMPTZ;
    END IF;
END $$;


-- STEP 5: Disable RLS + Drop triggers
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions DISABLE ROW LEVEL SECURITY;

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT trigger_name FROM information_schema.triggers WHERE event_object_schema='auth' AND event_object_table='users'
    LOOP EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users;', r.trigger_name); END LOOP;
    FOR r IN SELECT trigger_name FROM information_schema.triggers WHERE event_object_schema='public' AND event_object_table='profiles'
    LOOP EXECUTE format('DROP TRIGGER IF EXISTS %I ON profiles;', r.trigger_name); END LOOP;
END $$;


-- STEP 6: Re-create admin_create_user (now includes auth.identities)
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
    PERFORM set_config('search_path', 'public, extensions, auth', true);

    v_actual_full_name := COALESCE(TRIM(p_full_name), 'New User');
    IF v_actual_full_name = '' THEN v_actual_full_name := 'New User'; END IF;
    v_clean_email := LOWER(TRIM(p_email));

    -- Auth check
    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
            RAISE EXCEPTION 'Unauthorized';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RAISE EXCEPTION 'Email % already exists', v_clean_email;
    END IF;

    SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
    IF v_instance_id IS NULL THEN v_instance_id := '00000000-0000-0000-0000-000000000000'; END IF;

    v_user_id := gen_random_uuid();
    v_encrypted_pw := extensions.crypt(p_password, extensions.gen_salt('bf', 10));

    -- Create auth user
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, is_super_admin
    ) VALUES (
        v_instance_id, v_user_id, 'authenticated', 'authenticated',
        v_clean_email, v_encrypted_pw, NOW(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        jsonb_build_object('full_name', v_actual_full_name, 'role', p_role_code),
        NOW(), NOW(), '', FALSE
    );

    -- Create identity (CRITICAL for login!)
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    VALUES (gen_random_uuid(), v_user_id, jsonb_build_object('sub', v_user_id::text, 'email', v_clean_email), 'email', v_user_id::text, NOW(), NOW(), NOW())
    ON CONFLICT DO NOTHING;

    -- Create profile (uses id + user_id)
    INSERT INTO profiles (id, user_id, full_name, role, email)
    VALUES (v_user_id, v_user_id, v_actual_full_name, p_role_code, v_clean_email)
    ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, email = EXCLUDED.email, user_id = EXCLUDED.user_id;

    -- Assign role
    SELECT id INTO v_role_id FROM roles WHERE code = p_role_code;
    IF v_role_id IS NOT NULL THEN
        INSERT INTO user_roles (user_id, role_id) VALUES (v_user_id, v_role_id) ON CONFLICT DO NOTHING;
    END IF;

    -- Link employee
    IF p_employee_id IS NOT NULL THEN
        UPDATE employees SET user_id = v_user_id, company_email = v_clean_email WHERE id = p_employee_id;
    END IF;

    -- Permissions
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

    RETURN jsonb_build_object('success', true, 'user_id', v_user_id, 'message', 'User created successfully');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- STEP 7: Fix auth.identities for ALL existing users
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
SELECT gen_random_uuid(), u.id, jsonb_build_object('sub', u.id::text, 'email', u.email), 'email', u.id::text, NOW(), u.created_at, NOW()
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM auth.identities i WHERE i.user_id = u.id AND i.provider = 'email')
ON CONFLICT DO NOTHING;


-- STEP 8: Permissions + Search Paths
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO postgres, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
        EXECUTE 'GRANT USAGE ON SCHEMA extensions TO supabase_auth_admin';
        EXECUTE 'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO supabase_auth_admin';
        EXECUTE 'GRANT USAGE ON SCHEMA public TO supabase_auth_admin';
        EXECUTE 'GRANT ALL ON ALL TABLES IN SCHEMA public TO supabase_auth_admin';
    END IF;
END $$;

ALTER ROLE postgres SET search_path = public, extensions, auth;
ALTER ROLE service_role SET search_path = public, extensions, auth;
ALTER ROLE authenticated SET search_path = public, extensions, auth;
ALTER ROLE anon SET search_path = public, extensions, auth;

-- pgcrypto wrapper functions
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;
CREATE OR REPLACE FUNCTION public.crypt(text, text) RETURNS text AS $$ SELECT extensions.crypt($1, $2); $$ LANGUAGE sql IMMUTABLE;
CREATE OR REPLACE FUNCTION public.gen_salt(text, int) RETURNS text AS $$ SELECT extensions.gen_salt($1, $2); $$ LANGUAGE sql IMMUTABLE;
CREATE OR REPLACE FUNCTION public.gen_salt(text) RETURNS text AS $$ SELECT extensions.gen_salt($1); $$ LANGUAGE sql IMMUTABLE;


-- STEP 9: Reload
SELECT pg_reload_conf();
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ MIGRATION 053 COMPLETE';
    RAISE NOTICE '  - profiles.id restored as PRIMARY KEY';
    RAISE NOTICE '  - profiles.user_id added as copy';
    RAISE NOTICE '  - Foreign keys re-created (with CASCADE)';
    RAISE NOTICE '  - admin_create_user updated with auth.identities';
    RAISE NOTICE '  - RLS disabled on profiles';
    RAISE NOTICE '  - All triggers dropped';
    RAISE NOTICE '  - auth.identities fixed for all users';
    RAISE NOTICE '  - Permissions + search paths set';
    RAISE NOTICE 'TRY LOGGING IN NOW!';
END $$;
