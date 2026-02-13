-- =================================================================
-- MIGRATION 021: Seed Test Users for Development
-- =================================================================
-- Creates 6 test user accounts with password: password123
-- Uses bcrypt hash for Supabase GoTrue compatibility
-- =================================================================

-- First, update the profiles_role_check to include Z_FINANCE and finance_manager
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
CHECK (role IN (
    -- New RBAC roles
    'Z_ALL',
    'Z_STOCK_MGR',
    'Z_INV_CLERK',
    'Z_PROD_STAFF',
    'Z_SALES_STAFF',
    'Z_SALES_MGR',
    'Z_HR_MANAGER',
    'Z_HR_OFFICER',
    'Z_FINANCE',
    'Z_WAITER',
    'Z_CASHIER',
    'Z_KITCHEN',
    -- Legacy roles (for backward compatibility)
    'admin',
    'manager',
    'cashier',
    'kitchen',
    'waiter',
    'director',
    'hr_manager',
    'hr_officer',
    'finance_manager'
));

-- =================================================================
-- Insert test users into auth.users
-- Password: password123
-- bcrypt hash: $2a$10$PznUGzshVgLrkDQuSk.r7ukdZ3hASbMWTE0hR1noGnF.tXFMczPwW
-- =================================================================

DO $$
DECLARE
    v_manager_id UUID := 'a0000000-0000-0000-0000-000000000001';
    v_cashier_id UUID := 'a0000000-0000-0000-0000-000000000002';
    v_waiter_id UUID := 'a0000000-0000-0000-0000-000000000003';
    v_kitchen_id UUID := 'a0000000-0000-0000-0000-000000000004';
    v_hr_id UUID := 'a0000000-0000-0000-0000-000000000005';
    v_finance_id UUID := 'a0000000-0000-0000-0000-000000000006';
    v_password_hash TEXT := '$2a$10$PznUGzshVgLrkDQuSk.r7ukdZ3hASbMWTE0hR1noGnF.tXFMczPwW';
    v_now TIMESTAMPTZ := NOW();
    v_instance_id UUID := '00000000-0000-0000-0000-000000000000';
BEGIN
    -- =====================================================
    -- 1. MANAGER (Z_ALL - Full admin access)
    -- =====================================================
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token,
        email_change_token_new, email_change
    ) VALUES (
        v_manager_id, v_instance_id, 'authenticated', 'authenticated',
        'manager@sevenwaves.com', v_password_hash,
        v_now,
        '{"provider": "email", "providers": ["email"]}',
        '{"full_name": "Test Manager", "role": "Z_ALL"}',
        v_now, v_now, '', '', '', ''
    ) ON CONFLICT (id) DO NOTHING;

    -- Create identity for manager
    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_manager_id, v_manager_id,
        json_build_object('sub', v_manager_id::text, 'email', 'manager@sevenwaves.com')::jsonb,
        'email', v_manager_id::text, v_now, v_now, v_now
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    -- =====================================================
    -- 2. CASHIER (Z_CASHIER)
    -- =====================================================
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token,
        email_change_token_new, email_change
    ) VALUES (
        v_cashier_id, v_instance_id, 'authenticated', 'authenticated',
        'cashier@sevenwaves.com', v_password_hash,
        v_now,
        '{"provider": "email", "providers": ["email"]}',
        '{"full_name": "Test Cashier", "role": "Z_CASHIER"}',
        v_now, v_now, '', '', '', ''
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_cashier_id, v_cashier_id,
        json_build_object('sub', v_cashier_id::text, 'email', 'cashier@sevenwaves.com')::jsonb,
        'email', v_cashier_id::text, v_now, v_now, v_now
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    -- =====================================================
    -- 3. WAITER (Z_WAITER)
    -- =====================================================
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token,
        email_change_token_new, email_change
    ) VALUES (
        v_waiter_id, v_instance_id, 'authenticated', 'authenticated',
        'waiter@sevenwaves.com', v_password_hash,
        v_now,
        '{"provider": "email", "providers": ["email"]}',
        '{"full_name": "Test Waiter", "role": "Z_WAITER"}',
        v_now, v_now, '', '', '', ''
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_waiter_id, v_waiter_id,
        json_build_object('sub', v_waiter_id::text, 'email', 'waiter@sevenwaves.com')::jsonb,
        'email', v_waiter_id::text, v_now, v_now, v_now
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    -- =====================================================
    -- 4. KITCHEN (Z_PROD_STAFF)
    -- =====================================================
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token,
        email_change_token_new, email_change
    ) VALUES (
        v_kitchen_id, v_instance_id, 'authenticated', 'authenticated',
        'kitchen@sevenwaves.com', v_password_hash,
        v_now,
        '{"provider": "email", "providers": ["email"]}',
        '{"full_name": "Main Kitchen", "role": "Z_PROD_STAFF"}',
        v_now, v_now, '', '', '', ''
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_kitchen_id, v_kitchen_id,
        json_build_object('sub', v_kitchen_id::text, 'email', 'kitchen@sevenwaves.com')::jsonb,
        'email', v_kitchen_id::text, v_now, v_now, v_now
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    -- =====================================================
    -- 5. HR ADMIN (Z_HR_MANAGER)
    -- =====================================================
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token,
        email_change_token_new, email_change
    ) VALUES (
        v_hr_id, v_instance_id, 'authenticated', 'authenticated',
        'hr@sevenwaves.com', v_password_hash,
        v_now,
        '{"provider": "email", "providers": ["email"]}',
        '{"full_name": "HR Admin", "role": "Z_HR_MANAGER"}',
        v_now, v_now, '', '', '', ''
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_hr_id, v_hr_id,
        json_build_object('sub', v_hr_id::text, 'email', 'hr@sevenwaves.com')::jsonb,
        'email', v_hr_id::text, v_now, v_now, v_now
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    -- =====================================================
    -- 6. FINANCE (Z_FINANCE)
    -- =====================================================
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token,
        email_change_token_new, email_change
    ) VALUES (
        v_finance_id, v_instance_id, 'authenticated', 'authenticated',
        'finance@sevenwaves.com', v_password_hash,
        v_now,
        '{"provider": "email", "providers": ["email"]}',
        '{"full_name": "Finance Manager", "role": "Z_FINANCE"}',
        v_now, v_now, '', '', '', ''
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_finance_id, v_finance_id,
        json_build_object('sub', v_finance_id::text, 'email', 'finance@sevenwaves.com')::jsonb,
        'email', v_finance_id::text, v_now, v_now, v_now
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    -- =====================================================
    -- INSERT PROFILES
    -- =====================================================
    INSERT INTO public.profiles (id, user_id, full_name, role, avatar_url)
    VALUES
        (v_manager_id, v_manager_id, 'Test Manager', 'Z_ALL', NULL),
        (v_cashier_id, v_cashier_id, 'Test Cashier', 'Z_CASHIER', NULL),
        (v_waiter_id, v_waiter_id, 'Test Waiter', 'Z_WAITER', NULL),
        (v_kitchen_id, v_kitchen_id, 'Main Kitchen', 'Z_PROD_STAFF', NULL),
        (v_hr_id, v_hr_id, 'HR Admin', 'Z_HR_MANAGER', NULL),
        (v_finance_id, v_finance_id, 'Finance Manager', 'Z_FINANCE', NULL)
    ON CONFLICT (id) DO UPDATE SET
        role = EXCLUDED.role,
        full_name = EXCLUDED.full_name;

    -- =====================================================
    -- ASSIGN RBAC ROLES (user_roles table)
    -- =====================================================
    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_manager_id, id FROM roles WHERE code = 'Z_ALL'
    ON CONFLICT (user_id, role_id) DO NOTHING;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_cashier_id, id FROM roles WHERE code = 'Z_CASHIER'
    ON CONFLICT (user_id, role_id) DO NOTHING;

    -- Z_CASHIER role may not exist, fallback to Z_SALES_STAFF
    IF NOT FOUND THEN
        INSERT INTO public.user_roles (user_id, role_id)
        SELECT v_cashier_id, id FROM roles WHERE code = 'Z_SALES_STAFF'
        ON CONFLICT (user_id, role_id) DO NOTHING;
    END IF;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_waiter_id, id FROM roles WHERE code = 'Z_WAITER'
    ON CONFLICT (user_id, role_id) DO NOTHING;

    -- Z_WAITER role may not exist, fallback to Z_SALES_STAFF
    IF NOT FOUND THEN
        INSERT INTO public.user_roles (user_id, role_id)
        SELECT v_waiter_id, id FROM roles WHERE code = 'Z_SALES_STAFF'
        ON CONFLICT (user_id, role_id) DO NOTHING;
    END IF;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_kitchen_id, id FROM roles WHERE code = 'Z_PROD_STAFF'
    ON CONFLICT (user_id, role_id) DO NOTHING;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_hr_id, id FROM roles WHERE code = 'Z_HR_MANAGER'
    ON CONFLICT (user_id, role_id) DO NOTHING;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_finance_id, id FROM roles WHERE code = 'Z_FINANCE'
    ON CONFLICT (user_id, role_id) DO NOTHING;

    RAISE NOTICE '✅ MIGRATION 021 COMPLETE: 6 test users seeded successfully!';
    RAISE NOTICE '📧 Accounts: manager@, cashier@, waiter@, kitchen@, hr@, finance@ @sevenwaves.com';
    RAISE NOTICE '🔑 Password: password123';
END $$;

-- Reload PostgREST schema cache
SELECT pg_reload_conf();
NOTIFY pgrst, 'reload schema';
