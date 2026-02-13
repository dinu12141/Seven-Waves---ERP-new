-- =================================================================
-- MIGRATION 043: CLEAN UP AUTH TRIGGERS & FIX 500 ERROR
-- =================================================================

-- 1. DROP ZOMBIE TRIGGERS ON AUTH.USERS
--    These triggers often conflict with manual user creation and cause 
--    infinite loops or failures during login/signup.
--    We will recreate ONLY what is necessary if needed, but for now, 
--    we rely on 'admin_create_user' to handle everything safely.

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_signup ON auth.users;
DROP TRIGGER IF EXISTS on_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_signup ON auth.users;
DROP TRIGGER IF EXISTS create_profile_on_signup ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;

-- 2. DROP POTENTIAL RECURSIVE TRIGGERS ON PROFILES
DROP TRIGGER IF EXISTS on_profile_update ON profiles;
DROP TRIGGER IF EXISTS sync_user_meta_data ON profiles;

-- 3. ENSURE PROFILES RLS IS NON-RECURSIVE & SIMPLE
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop all known policies on profiles
DROP POLICY IF EXISTS "Profiles Access Policy" ON profiles;
DROP POLICY IF EXISTS "Admins Update Policy" ON profiles;
DROP POLICY IF EXISTS "Users Insert Own" ON profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update profiles" ON profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;

-- Create CLEAN policies
-- A. READ: Users read own; Admins/HR read all. 
--    Using JWT metadata avoids querying the table itself (recursion).
CREATE POLICY "Profiles Read Access" ON profiles
    FOR SELECT TO authenticated
    USING (
        auth.uid() = id 
        OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin', 'director', 'finance_manager', 'hr_manager')
        OR
        -- Fallback: If JWT metadata is missing/stale, allow reading own only (safest)
        -- We DO NOT query profiles table here to avoid recursion.
        id = auth.uid()
    );

-- B. UPDATE: Admins/HR update all; Users update own (limited fields usually, but strict here)
CREATE POLICY "Profiles Update Access" ON profiles
    FOR UPDATE TO authenticated
    USING (
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin')
        OR id = auth.uid()
    )
    WITH CHECK (
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin')
        OR id = auth.uid()
    );

-- C. INSERT: Allow if ID matches (standard) OR if Admin
CREATE POLICY "Profiles Insert Access" ON profiles
    FOR INSERT TO authenticated
    WITH CHECK (
        id = auth.uid() 
        OR 
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('Z_ALL', 'Z_HR_MANAGER', 'admin')
    );


-- 4. CLEANUP ANY ORPHANED PERMISSIONS
--    Sometimes bad data in user_permissions causes issues with view logic.
DELETE FROM user_permissions WHERE user_id NOT IN (SELECT id FROM auth.users);


-- Reload schema
NOTIFY pgrst, 'reload schema';
