-- =================================================================
-- FIX LOGIN & SCHEMA CACHE
-- =================================================================

-- 1. Reload PostgREST Schema Cache (Critical after DDL changes)
NOTIFY pgrst, 'reload schema';

-- 2. Ensure Permissions are Correct
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;

GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;

-- 3. Verify & Fix Profiles RLS (Just in case)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- 4. Fix User Roles RLS (To ensure get_user_permissions works)
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "User roles viewable by everyone" ON public.user_roles;
CREATE POLICY "User roles viewable by everyone" ON public.user_roles FOR SELECT USING (true);

-- 5. Fix Roles RLS
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Roles viewable by everyone" ON public.roles;
CREATE POLICY "Roles viewable by everyone" ON public.roles FOR SELECT USING (true);

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ Schema Cache Reloaded';
    RAISE NOTICE '✅ Permissions & RLS Re-applied';
    RAISE NOTICE '👉 Try Logging in now!';
END $$;
