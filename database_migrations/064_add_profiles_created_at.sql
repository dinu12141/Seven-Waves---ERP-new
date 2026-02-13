-- =================================================================
-- MIGRATION: ADD CREATED_AT TO PROFILES TABLE
-- =================================================================

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Backfill existing rows (optional but good practice)
UPDATE public.profiles SET created_at = NOW() WHERE created_at IS NULL;
UPDATE public.profiles SET updated_at = NOW() WHERE updated_at IS NULL;
