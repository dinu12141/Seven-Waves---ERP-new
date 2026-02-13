-- =================================================================
-- MIGRATION 058: FORCE RESET ADMIN PASSWORD
-- =================================================================

-- 1. Ensure pgcrypto is available
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;

-- 2. Force update the password for admin@sevenwaves.com
--    Password: 'Admin123!'
UPDATE auth.users
SET encrypted_password = crypt('Admin123!', gen_salt('bf')),
    email_confirmed_at = NOW(),
    updated_at = NOW(),
    raw_app_meta_data = '{"provider": "email", "providers": ["email"]}'::jsonb,
    raw_user_meta_data = '{"full_name": "Super Admin", "role": "Z_ALL"}'::jsonb
WHERE email = 'admin@sevenwaves.com';

-- 3. Also fix admin@admin.com just in case
UPDATE auth.users
SET encrypted_password = crypt('Admin123!', gen_salt('bf')),
    email_confirmed_at = NOW(),
    updated_at = NOW(),
    raw_app_meta_data = '{"provider": "email", "providers": ["email"]}'::jsonb,
    raw_user_meta_data = '{"full_name": "Admin User", "role": "Z_ALL"}'::jsonb
WHERE email = 'admin@admin.com';

-- 4. Check if they exist, if not, print a warning (found nothing to update)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email IN ('admin@sevenwaves.com', 'admin@admin.com')) THEN
        RAISE NOTICE '⚠️ No admin users found to update! Please run MIGRATION 049 first.';
    ELSE
        RAISE NOTICE '✅ Passwords reset to: Admin123!';
    END IF;
END $$;
