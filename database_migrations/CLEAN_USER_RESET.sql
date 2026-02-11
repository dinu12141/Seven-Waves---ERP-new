-- =================================================================
-- CLEAN USER RESET (Manual Fix for emp-2026-0003)
-- =================================================================

-- 1. DELETE THE USER (Clean Slate)
DELETE FROM auth.users WHERE email = 'emp-2026-0003@sevenwaves.com';
DELETE FROM public.employees WHERE company_email = 'emp-2026-0003@sevenwaves.com';
DELETE FROM public.profiles WHERE email = 'emp-2026-0003@sevenwaves.com';

-- 2. FORCE CACHE RELOAD
NOTIFY pgrst, 'reload schema';

-- 3. INSERT EMPLOYEE (Without Triggers first)
-- Temporarily disable trigger to prevent "Double Insert"
ALTER TABLE public.employees DISABLE TRIGGER ALL;

INSERT INTO public.employees (
    employee_code, first_name, last_name, email, company_email, 
    designation_id, department_id, status, employment_type,
    created_at, updated_at
) VALUES (
    'EMP-2026-0003', 'Test', 'Waiter', 'test.waiter@email.com', 'emp-2026-0003@sevenwaves.com',
    (SELECT id FROM designations WHERE name ILIKE '%Waiter%' LIMIT 1),
    (SELECT id FROM departments WHERE name ILIKE '%Service%' LIMIT 1),
    'Active', 'Permanent',
    NOW(), NOW()
);

-- 4. MANUALLY CREATE AUTH USER (Bypassing Automation to Verify Login)
DO $$
DECLARE
    v_user_id uuid := gen_random_uuid();
    v_instance_id uuid;
BEGIN
    SELECT instance_id INTO v_instance_id FROM auth.users LIMIT 1;
    IF v_instance_id IS NULL THEN v_instance_id := '00000000-0000-0000-0000-000000000000'; END IF;

    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, 
        email_confirmed_at, raw_user_meta_data, created_at, updated_at
    ) VALUES (
        v_instance_id,
        v_user_id,
        'authenticated',
        'authenticated',
        'emp-2026-0003@sevenwaves.com',
        crypt('Employee123!', gen_salt('bf')),
        NOW(),
        '{"role": "Z_SALES_STAFF", "full_name": "Test Waiter"}',
        NOW(),
        NOW()
    );

    -- Link Profile
    INSERT INTO public.profiles (id, user_id, full_name, role, email)
    VALUES (v_user_id, v_user_id, 'Test Waiter', 'Z_SALES_STAFF', 'emp-2026-0003@sevenwaves.com');

    -- Link Employee
    UPDATE public.employees 
    SET user_id = v_user_id 
    WHERE company_email = 'emp-2026-0003@sevenwaves.com';

END $$;

-- 5. RE-ENABLE TRIGGERS
ALTER TABLE public.employees ENABLE TRIGGER ALL;

DO $$
BEGIN
    RAISE NOTICE '✅ User Re-Created Manually.';
    RAISE NOTICE '   - Email: emp-2026-0003@sevenwaves.com';
    RAISE NOTICE '   - Pass: Employee123!';
END $$;
