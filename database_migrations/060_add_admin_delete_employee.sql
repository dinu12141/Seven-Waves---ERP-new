-- =================================================================
-- MIGRATION: ADD ADMIN_DELETE_EMPLOYEE FUNCTION
-- =================================================================

-- Create a robust function to delete an employee and their associated user account
CREATE OR REPLACE FUNCTION admin_delete_employee(p_employee_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator (postgres/admin)
SET search_path = public, auth, pg_temp -- Secure search path
AS $$
DECLARE
    v_user_id UUID;
    v_employee_exists BOOLEAN;
    v_caller_role VARCHAR;
BEGIN
    -- 0. Security Check
    -- Get the role from the JWT or profiles table
    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;
    
    -- If JWT role is missing or not sufficient, check profiles table fallback
    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        
        IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
             RAISE EXCEPTION 'Unauthorized: Only administrators or HR managers can delete employees';
        END IF;
    END IF;

    -- 1. Check if the employee exists AND GET THE USER_ID TO AVOID RACE CONDITION
    SELECT user_id INTO v_user_id FROM employees WHERE id = p_employee_id FOR UPDATE;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Employee not found'
        );
    END IF;

    -- 2. If there is a linked user, try to delete them
    -- (This usually cascades but we handle it defensively)
    IF v_user_id IS NOT NULL THEN
        -- Check if the user exists in auth.users before trying to delete
        DELETE FROM auth.users WHERE id = v_user_id;

        -- Redundant check for profile cleanup (Usually cascades from auth.users)
        DELETE FROM public.profiles WHERE id = v_user_id;
    END IF;

    -- 3. Delete the employee record
    -- If cascade deletion happened (via foreign key from user -> employee), this is a no-op 
    -- If no cascade, this cleans up the employee record.
    DELETE FROM employees WHERE id = p_employee_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Employee and associated user account deleted successfully'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

-- Grant execute permission to authenticated users (application logic controls access)
GRANT EXECUTE ON FUNCTION admin_delete_employee(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_employee(UUID) TO service_role;
