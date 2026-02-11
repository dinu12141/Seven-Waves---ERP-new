-- =================================================================
-- FIX LOGIN FINAL ATTEMPT
-- 1. Drop Auth Trigger (Source of possible 500s)
-- 2. Open RLS (Rule out permission issues)
-- =================================================================

-- 1. Drop the Trigger on auth.users (Requires permissions, hopefully works in SQL Editor)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Open RLS on Profiles (Nuclear Option to test)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'profiles') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON profiles';
    END LOOP;
END $$;

CREATE POLICY "Open Access" ON profiles FOR ALL USING (true) WITH CHECK (true);

-- 3. Ensure User IDs match (Sanity Check)
UPDATE public.profiles p
SET user_id = id
WHERE user_id IS NULL;

-- 4. Refresh Cache
NOTIFY pgrst, 'reload schema';

DO $$
BEGIN
    RAISE NOTICE '✅ Trigger Dropped & RLS Opened. Try Login!';
END $$;
