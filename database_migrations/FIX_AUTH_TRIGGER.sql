-- =================================================================
-- FIX AUTH TRIGGER
-- Run this to fix "Database error saving new user"
-- =================================================================

-- 1. Create Trigger Function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, email)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', 'New User'),
    COALESCE(new.raw_user_meta_data->>'role', 'Z_SALES_STAFF'),
    new.email
  );
  
  -- Also assign to user_roles table for RBAC
  INSERT INTO public.user_roles (user_id, role_id)
  SELECT 
    new.id, 
    id 
  FROM public.roles 
  WHERE code = COALESCE(new.raw_user_meta_data->>'role', 'Z_SALES_STAFF')
  ON CONFLICT DO NOTHING;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop Existing Trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 3. Create New Trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 4. Ensure PROFILES has necessary columns (Safety Check)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'role') THEN
        ALTER TABLE profiles ADD COLUMN role VARCHAR(50) DEFAULT 'Z_SALES_STAFF';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'email') THEN
        ALTER TABLE profiles ADD COLUMN email VARCHAR(255);
    END IF;
END $$;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ Auth Trigger Fixed! New users will now include metadata.';
END $$;
