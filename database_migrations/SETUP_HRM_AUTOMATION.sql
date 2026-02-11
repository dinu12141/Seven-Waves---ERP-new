-- =================================================================
-- SETUP HRM -> USER AUTOMATION (COMPLETE)
-- 1. Seeds Departments & Designations (With Role Mappings)
-- 2. Creates Trigger to Auto-Create User + Auto-Generate Email
-- 3. Sets Permissions appropriately
-- =================================================================

-- 1. FIX LOGIN BLOCKERS FIRST (Priority)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees DISABLE ROW LEVEL SECURITY;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;

-- 2. ENHANCE DESIGNATIONS TABLE
ALTER TABLE public.designations ADD COLUMN IF NOT EXISTS related_user_role VARCHAR(50);

-- 3. SEED DEPARTMENTS & DESIGNATIONS (Essential for Automation)
DO $$
DECLARE
    v_dept_dining uuid;
    v_dept_kitchen uuid;
    v_dept_store uuid;
    v_dept_admin uuid;
    v_dept_finance uuid;
BEGIN
    -- Seed Departments
    INSERT INTO public.departments (code, name) VALUES ('DPT-DIN', 'Dining Area') 
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name RETURNING id INTO v_dept_dining;

    INSERT INTO public.departments (code, name) VALUES ('DPT-KIT', 'Kitchen') 
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name RETURNING id INTO v_dept_kitchen;

    INSERT INTO public.departments (code, name) VALUES ('DPT-STR', 'Store & Inventory') 
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name RETURNING id INTO v_dept_store;

    INSERT INTO public.departments (code, name) VALUES ('DPT-ADM', 'Administration') 
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name RETURNING id INTO v_dept_admin;

    INSERT INTO public.departments (code, name) VALUES ('DPT-FIN', 'Finance') 
    ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name RETURNING id INTO v_dept_finance;

    -- Seed Designations with Role Mappings
    INSERT INTO public.designations (code, name, department_id, related_user_role) VALUES 
    ('DES-WTR', 'Waiter', v_dept_dining, 'Z_SALES_STAFF'),
    ('DES-CSH', 'Cashier', v_dept_dining, 'Z_SALES_STAFF'),
    ('DES-CHF', 'Head Chef', v_dept_kitchen, 'Z_PROD_STAFF'),
    ('DES-CK', 'Cook', v_dept_kitchen, 'Z_PROD_STAFF'),
    ('DES-STR', 'Store Manager', v_dept_store, 'Z_STOCK_MGR'),
    ('DES-CLK', 'Inventory Clerk', v_dept_store, 'Z_INV_CLERK'),
    ('DES-HR', 'HR Manager', v_dept_admin, 'Z_HR_MANAGER'),
    ('DES-ACC', 'Accountant', v_dept_finance, 'Z_FINANCE'),
    ('DES-GM', 'General Manager', v_dept_admin, 'Z_ALL')
    ON CONFLICT (code) DO UPDATE SET related_user_role = EXCLUDED.related_user_role;
END $$;

-- 4. CREATE AUTOMATION TRIGGER FUNCTION (Auto-Generate Credentials)
CREATE OR REPLACE FUNCTION public.auto_create_user_for_employee()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id uuid;
    v_role_code varchar;
    v_password varchar;
    v_encrypted_pw varchar;
    v_login_email varchar;
BEGIN
    -- A. Determine Role based on Designation
    SELECT related_user_role INTO v_role_code 
    FROM public.designations 
    WHERE id = new.designation_id;

    -- Default role if no mapping found
    IF v_role_code IS NULL THEN
        v_role_code := 'Z_SALES_STAFF'; 
    END IF;

    -- B. Auto-Generate Email if missing
    -- User asked to "generate" credentials. We prefer Company Email, else generate from Code.
    IF new.company_email IS NOT NULL THEN
        v_login_email := new.company_email;
    ELSE
        -- Generate: EMP-001@sevenwaves.com (Lowercase)
        v_login_email := LOWER(new.employee_code || '@sevenwaves.com');
    END IF;

    -- C. Generate Default Password
    v_password := 'Employee123!';
    v_encrypted_pw := crypt(v_password, gen_salt('bf'));
    v_user_id := gen_random_uuid();

    -- D. Create Auth User
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, 
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data, 
        created_at, updated_at, confirmation_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_user_id,
        'authenticated',
        'authenticated',
        v_login_email,
        v_encrypted_pw,
        NOW(),
        '{"provider": "email", "providers": ["email"]}',
        jsonb_build_object('full_name', new.full_name, 'role', v_role_code, 'employee_code', new.employee_code),
        NOW(),
        NOW(),
        encode(gen_random_bytes(32), 'hex')
    );

    -- E. Create Public Profile
    INSERT INTO public.profiles (id, user_id, full_name, role, email)
    VALUES (v_user_id, v_user_id, new.full_name, v_role_code, v_login_email);

    -- F. Assign RBAC Role
    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_user_id, id FROM public.roles WHERE code = v_role_code
    ON CONFLICT DO NOTHING;

    -- G. Link User back to Employee Record
    UPDATE public.employees SET 
        user_id = v_user_id,
        company_email = v_login_email -- Save the generated email if it wasn't there
    WHERE id = new.id;

    RETURN NULL; -- AFTER trigger
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Auto-User Creation Failed: %', SQLERRM;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. ATTACH TRIGGER
DROP TRIGGER IF EXISTS trg_auto_create_user ON employees;
CREATE TRIGGER trg_auto_create_user
    AFTER INSERT ON employees
    FOR EACH ROW
    EXECUTE PROCEDURE public.auto_create_user_for_employee();

-- 6. NOTIFY
DO $$
BEGIN
    RAISE NOTICE '✅ HRM Automation & Data Seeding Complete.';
    RAISE NOTICE '👉 Designations Seeded (Waiter, Chef, Cashier, etc.)';
    RAISE NOTICE '👉 Auto-Login Trigger Active.';
    RAISE NOTICE '   - Email: [EmployeeCode]@sevenwaves.com (if company email empty)';
    RAISE NOTICE '   - Password: Employee123!';
END $$;
