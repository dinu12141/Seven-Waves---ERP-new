---
description: Verify HRMS Fixes and Setup
---

1. **Database Permissions**:
   - Go to your Supabase Dashboard -> SQL Editor.
   - Open (or paste content of) `database_migrations/DISABLE_RLS.sql`.
   - Run the script. This is CRITICAL to resolve the "406" and permission errors.

2. **Verify Frontend**:
   - Navigate to the HRMS module.
   - **Employees**: Create a new employee with a "Salary Structure" selected in the Salary tab. Save it.
   - View the employee again. Verify the salary structure and base amount are persisted.
   - **Attendance**: Open the Attendance page. Verify you see a list of ALL active employees, not just those who checked in.
   - **Payroll**: Run a payroll batch and verify entries are created.

3. **Troubleshooting**:
   - If you still see "406" errors, ensure `DISABLE_RLS.sql` ran successfully.
   - If salary data isn't saving, ensure the latest `EmployeesPage.vue` code is loaded.
