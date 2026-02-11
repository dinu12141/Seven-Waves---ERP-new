-- =================================================================
-- FIX ZOMBIE TRIGGERS (Restoring Missing Functions)
-- =================================================================

-- 1. Restore 'handle_new_user' as a DUMMY function (Safe Mode)
-- This fixes errors if a trigger still points to this function.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Just return the user without doing anything.
  -- This allows the login/insert to PROCEED even if logic is broken.
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Restore 'auto_create_user_for_employee' as a DUMMY function
CREATE OR REPLACE FUNCTION public.auto_create_user_for_employee()
RETURNS TRIGGER AS $$
BEGIN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Restore 'sync_user_profile' (Common name)
CREATE OR REPLACE FUNCTION public.sync_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. GRANT PERMISSIONS to these functions (Crucial)
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.auto_create_user_for_employee() TO postgres, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sync_user_profile() TO postgres, anon, authenticated, service_role;

-- 5. NOW, Try to Drop the Triggers Safely (Again)
-- We do this AFTER restoring functions, so the DROP command itself doesn't crash on invalid references.
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 6. Grant Public Schema Access (Fix "Schema Error")
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;

-- 7. NOTIFY (Just in case)
NOTIFY pgrst, 'reload schema';
