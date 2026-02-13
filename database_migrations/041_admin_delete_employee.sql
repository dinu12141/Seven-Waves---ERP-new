-- =================================================================
-- MIGRATION 041: ADMIN DELETE EMPLOYEE & USER
-- =================================================================

-- 1. FUNCTION: Delete Employee and Linked User
--    Deletes the employee record and, if a user account is linked, deletes that too.
CREATE OR REPLACE FUNCTION admin_delete_employee(
    p_employee_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_caller_role VARCHAR;
BEGIN
    -- Check Authorization using JWT
    SELECT (auth.jwt() -> 'user_metadata' ->> 'role') INTO v_caller_role;

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
        -- Fallback check
        SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
        IF v_caller_role NOT IN ('Z_ALL', 'Z_HR_MANAGER', 'admin') THEN
             RAISE EXCEPTION 'Unauthorized: Only administrators can delete employees';
        END IF;
    END IF;

    -- Get the linked user ID
    SELECT user_id INTO v_user_id FROM employees WHERE id = p_employee_id;

    -- Delete the Employee (This might trigger foreign key constraints if other tables reference it)
    -- If you have salary assignments, etc., ensure ON DELETE CASCADE is set on those tables 
    -- OR delete them manually here.
    
    -- Manually delete dependent records if cascading isn't set (Safe approach)
    DELETE FROM employee_salary_assignments WHERE employee_id = p_employee_id;
    -- Add other dependent tables here if needed

    DELETE FROM employees WHERE id = p_employee_id;

    -- If there was a linked user, delete them from auth.users
    IF v_user_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = v_user_id;
        -- Profiles and other user-related data will cascade delete if set up correctly
        -- If not, manual cleanup:
        DELETE FROM profiles WHERE id = v_user_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Employee and linked user deleted');

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. GRANT EXECUTE
GRANT EXECUTE ON FUNCTION admin_delete_employee(UUID) TO authenticated;

-- Force schema reload
NOTIFY pgrst, 'reload schema';
