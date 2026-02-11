-- =================================================================
-- FIX ADMIN PROFILE & ENSURE DATA CONSISTENCY
-- =================================================================

-- 1. Upsert Profile for Admin (Fixes missing profile issue)
INSERT INTO public.profiles (id, user_id, full_name, role, email)
SELECT 
    id, 
    id, -- Explicitly set user_id
    COALESCE(raw_user_meta_data->>'full_name', 'System Administrator'), 
    'Z_ALL', 
    email
FROM auth.users 
WHERE email = 'admin@sevenwaves.com'
ON CONFLICT (id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    role = 'Z_ALL',
    email = EXCLUDED.email;

-- 2. Upsert Profile for emp-2026-0005 (The user in previous screenshots)
INSERT INTO public.profiles (id, user_id, full_name, role, email)
SELECT 
    id, 
    id, 
    COALESCE(raw_user_meta_data->>'full_name', 'Test Employee'), 
    COALESCE(raw_user_meta_data->>'role', 'Z_SALES_STAFF'), 
    email
FROM auth.users 
WHERE email = 'emp-2026-0005@sevenwaves.com'
ON CONFLICT (id) DO UPDATE SET
    user_id = EXCLUDED.user_id;

-- 3. Verify Constraints (Optional check)
DO $$
BEGIN
    RAISE NOTICE '✅ Admin Profile Fixed.';
END $$;
