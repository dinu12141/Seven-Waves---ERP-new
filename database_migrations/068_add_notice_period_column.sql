-- =================================================================
-- MIGRATION: ADD NOTICE PERIOD COLUMN
-- =================================================================

-- Add notice_period_days column to employees table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employees' 
        AND column_name = 'notice_period_days'
    ) THEN
        ALTER TABLE public.employees
        ADD COLUMN notice_period_days INTEGER DEFAULT 0;
    END IF;
END $$;
