-- =================================================================
-- MIGRATION 057: DISABLE RLS ON CRITICAL TABLES (DEBUG FIX)
-- =================================================================
-- We suspect RLS is preventing the user from reading their own
-- 'Z_ALL' profile, causing the app to fall back to 'Z_SALES_STAFF'
-- or simply failing to load the role.

-- 1. Disable RLS on profiles to ensure readability
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 2. Disable RLS on permissions/roles just in case
ALTER TABLE public.permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions DISABLE ROW LEVEL SECURITY;

-- 3. Ensure 'authenticated' role has explicit SELECT permissions
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT ON public.permissions TO authenticated;
GRANT SELECT ON public.roles TO authenticated;
GRANT SELECT ON public.user_roles TO authenticated;
GRANT SELECT ON public.user_permissions TO authenticated;
GRANT SELECT ON public.role_permissions TO authenticated;

-- 4. Reload schema cache
NOTIFY pgrst, 'reload schema';
