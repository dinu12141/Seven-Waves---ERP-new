-- =================================================================
-- QUICK RLS ENABLE SCRIPT (ERROR-FREE VERSION)
-- Run this in Supabase SQL Editor
-- =================================================================

-- This is the corrected version with proper column names

-- 1. Enable RLS on tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_hierarchy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_status_history ENABLE ROW LEVEL SECURITY;

-- 2. User Profiles Policies
DROP POLICY IF EXISTS "user_profiles_select_own" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_own" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_service_role_all" ON public.user_profiles;

CREATE POLICY "user_profiles_select_own" ON public.user_profiles
FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY "user_profiles_update_own" ON public.user_profiles
FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "user_profiles_service_role_all" ON public.user_profiles
FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 3. Table Sessions Policies (FIXED - uses created_by)
DROP POLICY IF EXISTS "table_sessions_owner_all" ON public.table_sessions;
DROP POLICY IF EXISTS "table_sessions_service_role_all" ON public.table_sessions;

CREATE POLICY "table_sessions_owner_all" ON public.table_sessions
FOR ALL TO authenticated USING (auth.uid() = created_by) WITH CHECK (auth.uid() = created_by);

CREATE POLICY "table_sessions_service_role_all" ON public.table_sessions
FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 4. Suppliers Policies
DROP POLICY IF EXISTS "suppliers_authenticated_read" ON public.suppliers;
DROP POLICY IF EXISTS "suppliers_service_role_all" ON public.suppliers;

CREATE POLICY "suppliers_authenticated_read" ON public.suppliers
FOR SELECT TO authenticated USING (true);

CREATE POLICY "suppliers_service_role_all" ON public.suppliers
FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 5. Employees Policies
DROP POLICY IF EXISTS "employees_authenticated_read" ON public.employees;
DROP POLICY IF EXISTS "employees_service_role_all" ON public.employees;

CREATE POLICY "employees_authenticated_read" ON public.employees
FOR SELECT TO authenticated USING (true);

CREATE POLICY "employees_service_role_all" ON public.employees
FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 6. Sales Hierarchy Policies
DROP POLICY IF EXISTS "sales_hierarchy_authenticated_read" ON public.sales_hierarchy;
DROP POLICY IF EXISTS "sales_hierarchy_service_role_all" ON public.sales_hierarchy;

CREATE POLICY "sales_hierarchy_authenticated_read" ON public.sales_hierarchy
FOR SELECT TO authenticated USING (true);

CREATE POLICY "sales_hierarchy_service_role_all" ON public.sales_hierarchy
FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 7. Table Status History Policies
DROP POLICY IF EXISTS "table_status_history_authenticated_read" ON public.table_status_history;
DROP POLICY IF EXISTS "table_status_history_service_role_all" ON public.table_status_history;

CREATE POLICY "table_status_history_authenticated_read" ON public.table_status_history
FOR SELECT TO authenticated USING (true);

CREATE POLICY "table_status_history_service_role_all" ON public.table_status_history
FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Verification
SELECT 'RLS ENABLED ON: ' || tablename as status
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('user_profiles', 'table_sessions', 'suppliers', 'employees', 'sales_hierarchy', 'table_status_history')
AND rowsecurity = true
ORDER BY tablename;
