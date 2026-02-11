-- =================================================================
-- SIMPLE AUTH FIX - Works within Supabase constraints
-- =================================================================

-- Step 1: Drop ALL custom triggers on auth.users
DO $$
DECLARE
    trigger_rec RECORD;
BEGIN
    FOR trigger_rec IN 
        SELECT tgname 
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'auth' 
        AND c.relname = 'users'
        AND NOT tgisinternal
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users CASCADE', trigger_rec.tgname);
        RAISE NOTICE '✓ Dropped trigger: %', trigger_rec.tgname;
    END LOOP;
    
    RAISE NOTICE '✓ All custom triggers removed';
END $$;

-- Step 2: Grant permissions to public schema (no reserved role modifications)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, service_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, service_role;

-- Step 3: Disable RLS on auth-related tables
DO $$
DECLARE
    table_rec RECORD;
    tables_to_fix TEXT[] := ARRAY['user_profiles', 'user_roles', 'roles', 'permissions'];
BEGIN
    FOREACH table_rec.tablename IN ARRAY tables_to_fix
    LOOP
        IF EXISTS (
            SELECT FROM pg_tables 
            WHERE schemaname = 'public' 
            AND tablename = table_rec.tablename
        ) THEN
            EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', table_rec.tablename);
            RAISE NOTICE '✓ Disabled RLS on: public.%', table_rec.tablename;
        END IF;
    END LOOP;
END $$;

-- Step 4: Ensure user_profiles exists with minimal structure
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;

-- Step 5: Create dummy functions to satisfy any lingering references
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$ 
BEGIN 
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.sync_user_profile() 
RETURNS TRIGGER AS $$ 
BEGIN 
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.auto_create_user_for_employee() 
RETURNS TRIGGER AS $$ 
BEGIN 
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ AUTH FIX COMPLETED SUCCESSFULLY';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✓ Custom triggers removed from auth.users';
    RAISE NOTICE '✓ Public schema permissions granted';
    RAISE NOTICE '✓ RLS disabled on auth tables';
    RAISE NOTICE '✓ Dummy functions created';
    RAISE NOTICE '✓ Schema cache reloaded';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 Try logging in now!';
    RAISE NOTICE '========================================';
END $$;
