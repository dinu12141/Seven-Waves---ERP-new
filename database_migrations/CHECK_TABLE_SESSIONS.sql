-- Quick diagnostic to check table_sessions structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'table_sessions'
ORDER BY ordinal_position;
