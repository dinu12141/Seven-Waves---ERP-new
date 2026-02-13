-- =================================================================
-- MIGRATION: UPDATE GRANT TYPE CONSTRAINT
-- =================================================================

-- 1. Drop existing constraint
ALTER TABLE public.user_permissions
DROP CONSTRAINT IF EXISTS user_permissions_grant_type_check;

-- 2. Add updated constraint allowing 'explicit'
ALTER TABLE public.user_permissions
ADD CONSTRAINT user_permissions_grant_type_check
CHECK (grant_type IN ('allow', 'deny', 'explicit'));
