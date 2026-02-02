-- =================================================================
-- ADMIN SETUP HELPER
-- =================================================================

-- 1. Ensure 'role' column exists in profiles (It seems missing in base schema)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'role') THEN
        ALTER TABLE profiles ADD COLUMN role VARCHAR(20) DEFAULT 'waiter';
    END IF;
END $$;

-- 2. Create the Admin User logic
-- INSTRUCTIONS:
-- Since we cannot easily insert into auth.users (password hashing is complex),
-- please perform the following steps:

-- STEP 1: Go to Supabase Dashboard -> Authentication -> Users
-- STEP 2: click "Add User" and create a user with email: 'admin@sevenwaves.com' and a password of your choice.
-- STEP 3: Run the following SQL to grant Admin permissions to this user:

INSERT INTO public.profiles (id, full_name, role)
SELECT id, 'System Admin', 'admin'
FROM auth.users
WHERE email = 'admin@sevenwaves.com'
ON CONFLICT (id) DO UPDATE
SET role = 'admin', full_name = 'System Admin';

-- Verify
SELECT * FROM profiles WHERE role = 'admin';
