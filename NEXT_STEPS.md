# Next Steps - Seven Waves ERP

## 🔴 URGENT: Fix Login Error

You are currently experiencing: **"Database error querying schema"**

### Solution Steps:

#### 1. Run Auth Recovery Script

Open Supabase SQL Editor and run this file:

- Location: `database_migrations/FORCE_AUTH_RECOVERY.sql`
- Or use the quick script below

#### 2. Quick Fix Script

```sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA "extensions";
GRANT ALL ON SCHEMA auth TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres;
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
ALTER TABLE IF EXISTS public.user_profiles DISABLE ROW LEVEL SECURITY;
NOTIFY pgrst, 'reload schema';
```

#### 3. Restart Supabase Project

- Go to: https://supabase.com/dashboard/project/mvvuegptxjykhzpatsmn/settings/general
- Click "Pause project" (wait 1-2 minutes)
- Click "Restore project" (wait 2-3 minutes)

#### 4. Test Login

- Refresh your login page
- Try logging in with your credentials

## 🔒 After Login Works: Enable Security

Run: `database_migrations/ENABLE_RLS_POLICIES.sql`

This will add Row Level Security to protect your data.

## 📞 Need Help?

Let me know:

- ✅ If login is fixed
- ❌ If you're still getting errors
- ❓ If you need clarification

---

Created: 2026-02-04
Project: Seven Waves ERP
