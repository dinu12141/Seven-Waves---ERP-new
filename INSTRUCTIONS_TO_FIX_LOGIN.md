# CRITICAL FIX: Duplicate Profile Error

I have created a new migration script that definitively fixes the `duplicate key value violates unique constraint "profiles_user_id_key"` error.

**File:** `database_migrations/050_fix_duplicate_profile_error.sql`

## Steps to Apply Fix:

1.  Open **Supabase Dashboard**.
2.  Go to the **SQL Editor**.
3.  Open or Copy/Paste the content of `database_migrations/050_fix_duplicate_profile_error.sql`.
4.  **Run the script**.

## Why this works:

This script updates the `admin_create_user` function to use a "Check-Update-Insert" pattern (Upsert) that specifically handles conflicts on the `user_id` column. It safely handles cases where a trigger might have already created a partial profile.

After running this, please try creating the employee again.
