-- =================================================================
-- SEED REAL USERS (ULTIMATE FIX)
-- 1. Fixes Schema (Role Type)
-- 2. Fixes Trigger (Missing user_id)
-- 3. Disables Trigger during Seed (Prevents conflicts)
-- 4. Seeds Users (Directly into Auth & Profiles)
-- =================================================================

-- 1. Enable Crypto Extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Fix Profile Role Type (Handle ALL RLS Dependencies)
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Only proceed if the column type needs changing
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'role' 
        AND data_type NOT IN ('character varying', 'text')
    ) THEN
        RAISE NOTICE 'Fixing profiles.role type with deep dependency handling...';

        -- A. Drop Dependent Policies on OTHER tables
        DROP POLICY IF EXISTS "employees_hr_policy" ON employees;
        DROP POLICY IF EXISTS "salary_slips_hr_policy" ON salary_slips;
        DROP POLICY IF EXISTS "attendance_policy" ON attendance;
        DROP POLICY IF EXISTS "leave_applications_policy" ON leave_applications;

        -- B. Drop policies on PROFILES table
        FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'profiles') LOOP
            EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON profiles';
        END LOOP;
        
        -- C. Convert to VARCHAR
        ALTER TABLE profiles ALTER COLUMN role TYPE VARCHAR(50) USING role::text;

        -- D. Restore Policies on PROFILES
        EXECUTE 'CREATE POLICY "Profiles are viewable by everyone" ON profiles FOR SELECT USING (true)';
        EXECUTE 'CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id)';
        EXECUTE 'CREATE POLICY "Users can insert their own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id)';

        -- E. Restore Dependent Policies on OTHER tables
        CREATE POLICY employees_hr_policy ON employees FOR ALL TO authenticated USING (
            EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'hr_officer', 'Z_ALL', 'Z_HR_MANAGER'))
            OR user_id = auth.uid()
        );
        CREATE POLICY salary_slips_hr_policy ON salary_slips FOR ALL TO authenticated USING (
            EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'Z_ALL', 'Z_HR_MANAGER'))
            OR employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
        );
        CREATE POLICY attendance_policy ON attendance FOR ALL TO authenticated USING (
            EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'hr_officer', 'Z_ALL', 'Z_HR_MANAGER'))
            OR employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
        );
        CREATE POLICY leave_applications_policy ON leave_applications FOR ALL TO authenticated USING (
            EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'hr_manager', 'hr_officer', 'Z_ALL', 'Z_HR_MANAGER'))
            OR employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
        );

        RAISE NOTICE '✅ Policy dependencies resolved and restored.';
    END IF;
END $$;

-- 3. FIX THE BROKEN TRIGGER (This was causing the error!)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, user_id, full_name, role, email)
  VALUES (
    new.id,
    new.id, -- FIX: Include user_id (same as id)
    COALESCE(new.raw_user_meta_data->>'full_name', 'New User'),
    COALESCE(new.raw_user_meta_data->>'role', 'Z_SALES_STAFF'),
    new.email
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    email = EXCLUDED.email;
  
  -- Also assign to user_roles table for RBAC
  INSERT INTO public.user_roles (user_id, role_id)
  SELECT 
    new.id, 
    id 
  FROM public.roles 
  WHERE code = COALESCE(new.raw_user_meta_data->>'role', 'Z_SALES_STAFF')
  ON CONFLICT DO NOTHING;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Define Users Data & EXECUTE SEED
DO $$
DECLARE
    v_users text[][] := ARRAY[
        ['admin@sevenwaves.com', 'Admin123!', 'System Administrator', 'Z_ALL'],
        ['store@sevenwaves.com', 'Store123!', 'Store Manager', 'Z_STOCK_MGR'],
        ['clerk@sevenwaves.com', 'Clerk123!', 'Inventory Clerk', 'Z_INV_CLERK'],
        ['chef@sevenwaves.com', 'Chef123!', 'Head Chef', 'Z_PROD_STAFF'],
        ['waiter@sevenwaves.com', 'Waiter123!', 'John Waiter', 'Z_SALES_STAFF'],
        ['cashier@sevenwaves.com', 'Cashier123!', 'Jane Cashier', 'Z_SALES_STAFF'],
        ['hr@sevenwaves.com', 'HR123!', 'HR Director', 'Z_HR_MANAGER'],
        ['finance@sevenwaves.com', 'Finance123!', 'Finance Controller', 'Z_FINANCE']
    ];
    v_user text[];
    v_user_id uuid;
    v_role_id uuid;
BEGIN
    -- (Removed Trigger Disable/Enable to avoid Permission Errors)

    FOREACH v_user SLICE 1 IN ARRAY v_users
    LOOP
        -- A. Check if user exists
        SELECT id INTO v_user_id FROM auth.users WHERE email = v_user[1];

        IF v_user_id IS NOT NULL THEN
            -- Update existing user
            UPDATE auth.users SET
                encrypted_password = crypt(v_user[2], gen_salt('bf')),
                raw_user_meta_data = jsonb_build_object('full_name', v_user[3], 'role', v_user[4]),
                updated_at = NOW()
            WHERE id = v_user_id;
        ELSE
            -- Insert new user
            v_user_id := gen_random_uuid();
            INSERT INTO auth.users (
                instance_id,
                id,
                aud,
                role,
                email,
                encrypted_password,
                email_confirmed_at,
                raw_app_meta_data,
                raw_user_meta_data,
                created_at,
                updated_at
            ) VALUES (
                '00000000-0000-0000-0000-000000000000',
                v_user_id,
                'authenticated',
                'authenticated',
                v_user[1],
                crypt(v_user[2], gen_salt('bf')),
                NOW(),
                '{"provider": "email", "providers": ["email"]}',
                jsonb_build_object('full_name', v_user[3], 'role', v_user[4]),
                NOW(),
                NOW()
            );
        END IF;

        -- B. Insert/Update PUBLIC.PROFILES (Smart Upsert)
        -- Find existing profile to preserve ID (avoid FK violations)
        DECLARE
            v_profile_id uuid;
        BEGIN
            SELECT id INTO v_profile_id FROM public.profiles 
            WHERE user_id = v_user_id OR email = v_user[1] 
            LIMIT 1;

            IF v_profile_id IS NOT NULL THEN
                -- Update existing (Do NOT change ID)
                UPDATE public.profiles SET
                    full_name = v_user[3],
                    role = v_user[4],
                    email = v_user[1],
                    user_id = v_user_id -- Ensure linked to current auth user
                WHERE id = v_profile_id;
            ELSE
                -- Insert new (Safe to set ID = user_id)
                INSERT INTO public.profiles (id, user_id, full_name, role, email)
                VALUES (v_user_id, v_user_id, v_user[3], v_user[4], v_user[1])
                ON CONFLICT (id) DO UPDATE SET -- Fallback just in case
                    full_name = EXCLUDED.full_name,
                    role = EXCLUDED.role,
                    email = EXCLUDED.email;
            END IF;
        END;

        -- C. Assign Role in RBAC
        SELECT id INTO v_role_id FROM public.roles WHERE code = v_user[4];
        
        IF v_role_id IS NOT NULL THEN
            INSERT INTO public.user_roles (user_id, role_id)
            VALUES (v_user_id, v_role_id)
            ON CONFLICT (user_id, role_id) DO NOTHING;
        END IF;

    RAISE NOTICE '✅ Processed User: % (%)', v_user[3], v_user[1];
    END LOOP;

    -- RE-ENABLE TRIGGER (Removed)
    -- ALTER TABLE auth.users ENABLE TRIGGER on_auth_user_created;
    RAISE NOTICE '✅ All Verification Users Created!';
END $$;
