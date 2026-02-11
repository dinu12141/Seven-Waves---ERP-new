-- =================================================================
-- ENABLE RLS & CREATE SECURE POLICIES
-- Migration to fix security vulnerabilities
-- =================================================================

-- WARNING: This enables RLS which was previously disabled to fix login issues.
-- These policies are designed to maintain auth functionality while securing data.

-- =================================================================
-- 1. ENABLE RLS ON ALL VULNERABLE TABLES
-- =================================================================

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_hierarchy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_status_history ENABLE ROW LEVEL SECURITY;

-- =================================================================
-- 2. USER_PROFILES POLICIES
-- Users can read/update their own profile
-- Service role has full access (for auth operations)
-- =================================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "user_profiles_select_own" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_own" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_service_role_all" ON public.user_profiles;

-- Allow users to read their own profile
CREATE POLICY "user_profiles_select_own" 
ON public.user_profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "user_profiles_update_own" 
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Allow service_role full access (critical for auth operations)
CREATE POLICY "user_profiles_service_role_all" 
ON public.user_profiles
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- =================================================================
-- 3. TABLE_SESSIONS POLICIES
-- Only session creator has access
-- =================================================================

DROP POLICY IF EXISTS "table_sessions_owner_all" ON public.table_sessions;
DROP POLICY IF EXISTS "table_sessions_service_role_all" ON public.table_sessions;

-- Allow users to manage sessions they created
CREATE POLICY "table_sessions_owner_all" 
ON public.table_sessions
FOR ALL
TO authenticated
USING (auth.uid() = created_by)
WITH CHECK (auth.uid() = created_by);

-- Service role full access
CREATE POLICY "table_sessions_service_role_all" 
ON public.table_sessions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);


-- =================================================================
-- 4. SUPPLIERS POLICIES
-- Authenticated: Read access
-- Service role / Admins: Write access
-- =================================================================

DROP POLICY IF EXISTS "suppliers_authenticated_read" ON public.suppliers;
DROP POLICY IF EXISTS "suppliers_service_role_all" ON public.suppliers;

-- Authenticated users can read
CREATE POLICY "suppliers_authenticated_read" 
ON public.suppliers
FOR SELECT
TO authenticated
USING (true);

-- Service role can do everything
CREATE POLICY "suppliers_service_role_all" 
ON public.suppliers
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- =================================================================
-- 5. EMPLOYEES POLICIES
-- Authenticated: Read access
-- Service role: Write access
-- =================================================================

DROP POLICY IF EXISTS "employees_authenticated_read" ON public.employees;
DROP POLICY IF EXISTS "employees_service_role_all" ON public.employees;

-- Authenticated users can read
CREATE POLICY "employees_authenticated_read" 
ON public.employees
FOR SELECT
TO authenticated
USING (true);

-- Service role can do everything
CREATE POLICY "employees_service_role_all" 
ON public.employees
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- =================================================================
-- 6. SALES_HIERARCHY POLICIES
-- Authenticated: Read access
-- Service role: Write access
-- =================================================================

DROP POLICY IF EXISTS "sales_hierarchy_authenticated_read" ON public.sales_hierarchy;
DROP POLICY IF EXISTS "sales_hierarchy_service_role_all" ON public.sales_hierarchy;

-- Authenticated users can read
CREATE POLICY "sales_hierarchy_authenticated_read" 
ON public.sales_hierarchy
FOR SELECT
TO authenticated
USING (true);

-- Service role can do everything
CREATE POLICY "sales_hierarchy_service_role_all" 
ON public.sales_hierarchy
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- =================================================================
-- 7. TABLE_STATUS_HISTORY POLICIES
-- Authenticated: Read access
-- Service role: Write access
-- =================================================================

DROP POLICY IF EXISTS "table_status_history_authenticated_read" ON public.table_status_history;
DROP POLICY IF EXISTS "table_status_history_service_role_all" ON public.table_status_history;

-- Authenticated users can read
CREATE POLICY "table_status_history_authenticated_read" 
ON public.table_status_history
FOR SELECT
TO authenticated
USING (true);

-- Service role can do everything
CREATE POLICY "table_status_history_service_role_all" 
ON public.table_status_history
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- =================================================================
-- 8. VERIFICATION
-- =================================================================

DO $$
DECLARE
    table_rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ RLS POLICIES ENABLED';
    RAISE NOTICE '========================================';
    
    FOR table_rec IN 
        SELECT 
            schemaname,
            tablename,
            rowsecurity
        FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename IN ('user_profiles', 'table_sessions', 'suppliers', 'employees', 'sales_hierarchy', 'table_status_history')
        ORDER BY tablename
    LOOP
        IF table_rec.rowsecurity THEN
            RAISE NOTICE '✓ RLS ENABLED on %.%', table_rec.schemaname, table_rec.tablename;
        ELSE
            RAISE WARNING '✗ RLS NOT ENABLED on %.%', table_rec.schemaname, table_rec.tablename;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Security Summary:';
    RAISE NOTICE '- user_profiles: Own profile access + service_role';
    RAISE NOTICE '- table_sessions: Own session access + service_role';
    RAISE NOTICE '- suppliers: Authenticated read + service_role all';
    RAISE NOTICE '- employees: Authenticated read + service_role all';
    RAISE NOTICE '- sales_hierarchy: Authenticated read + service_role all';
    RAISE NOTICE '- table_status_history: Authenticated read + service_role all';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 No public (unauthenticated) access allowed';
    RAISE NOTICE '========================================';
END $$;
