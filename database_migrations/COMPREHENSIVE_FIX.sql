-- =================================================================
-- COMPREHENSIVE LOGIN FIX
-- Force Refresh Schema Cache & Verify Permissions
-- =================================================================

-- 1. FORCE Schema Cache Refresh via DDL (The "Kick")
-- Changing table structure forces PostgREST to rebuild its cache
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS _refresh_cache integer;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS _refresh_cache;

-- 2. Send Reload Notification (Standard Method)
NOTIFY pgrst, 'reload schema';

-- 3. Ensure Permissions (Grant Usage to Auth/Anon)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- 4. Ensure Auth Trigger Function is Idempotent (Safe for Login)
-- Even if triggered on update, it should return NEW without error
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Only INSERT if it's a new user or missing profile
  IF (TG_OP = 'INSERT') THEN
      INSERT INTO public.profiles (id, user_id, full_name, role, email)
      VALUES (
        new.id,
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', 'New User'),
        COALESCE(new.raw_user_meta_data->>'role', 'Z_SALES_STAFF'),
        new.email
      )
      ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        email = EXCLUDED.email;
        
      -- Assign default role
      INSERT INTO public.user_roles (user_id, role_id)
      SELECT new.id, id FROM public.roles 
      WHERE code = COALESCE(new.raw_user_meta_data->>'role', 'Z_SALES_STAFF')
      ON CONFLICT DO NOTHING;
  END IF;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Validate Admin User Existence (Diagnostic)
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*) INTO v_count FROM auth.users WHERE email = 'admin@sevenwaves.com';
    RAISE NOTICE 'diagnostic: found % admin users', v_count;
    
    SELECT COUNT(*) INTO v_count FROM public.profiles WHERE email = 'admin@sevenwaves.com';
    RAISE NOTICE 'diagnostic: found % admin profiles', v_count;
END $$;
