-- =================================================================
-- FIX WAITER RELATIONSHIPS & OTHERS
-- Migration: FIX_WAITER_RELATIONSHIPS.sql
-- =================================================================

-- 1. RESTAURANT TABLES
ALTER TABLE restaurant_tables
    DROP CONSTRAINT IF EXISTS restaurant_tables_current_waiter_id_fkey;

ALTER TABLE restaurant_tables
    ADD CONSTRAINT restaurant_tables_current_waiter_id_fkey
    FOREIGN KEY (current_waiter_id) REFERENCES profiles(id);

-- Optional: Fix created_by if used for display
-- Note: created_by often links to auth.users for audit, but if we display names, we might want profiles.
-- Keeping created_by as auth.users is standard for audit, but let's check if the app tries to join it.
-- The app issue was specifically `current_waiter:current_waiter_id(full_name)`.

-- 2. ORDER HEADERS
ALTER TABLE order_headers
    DROP CONSTRAINT IF EXISTS order_headers_assigned_waiter_id_fkey;

ALTER TABLE order_headers
    ADD CONSTRAINT order_headers_assigned_waiter_id_fkey
    FOREIGN KEY (assigned_waiter_id) REFERENCES profiles(id);
    
-- 3. KITCHEN ORDERS
ALTER TABLE kitchen_orders
    DROP CONSTRAINT IF EXISTS kitchen_orders_assigned_cook_id_fkey;

ALTER TABLE kitchen_orders
    ADD CONSTRAINT kitchen_orders_assigned_cook_id_fkey
    FOREIGN KEY (assigned_cook_id) REFERENCES profiles(id);

-- 4. KOT NOTIFICATIONS
ALTER TABLE kot_notifications
    DROP CONSTRAINT IF EXISTS kot_notifications_target_user_id_fkey;

ALTER TABLE kot_notifications
    ADD CONSTRAINT kot_notifications_target_user_id_fkey
    FOREIGN KEY (target_user_id) REFERENCES profiles(id);

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ Fixed table relationships to point to public.profiles!';
END $$;
