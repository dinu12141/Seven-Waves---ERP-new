-- =================================================================
-- SEVEN WAVES ERP - TABLE-WISE ORDERING & TRACKING SYSTEM
-- Migration: 019_table_ordering_system.sql
-- SAP O2C (Order-to-Cash) and PP (Production Planning) Standards
-- =================================================================

-- =====================================================
-- 1. RESTAURANT TABLES (Base Infrastructure)
-- =====================================================

CREATE TABLE IF NOT EXISTS restaurant_tables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_number VARCHAR(20) UNIQUE NOT NULL,
    
    -- Capacity & Location
    capacity INTEGER NOT NULL DEFAULT 4,
    location VARCHAR(50), -- 'Indoor', 'Outdoor', 'Terrace', 'VIP Room'
    floor_number INTEGER DEFAULT 1,
    section VARCHAR(50), -- 'Main Hall', 'Private', 'Bar Area'
    
    -- Status
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN (
        'available', 'occupied', 'reserved', 'cleaning', 'out_of_service'
    )),
    
    -- Current Order (if occupied)
    current_order_id UUID,
    current_waiter_id UUID REFERENCES auth.users(id),
    current_session_id UUID,
    
    -- Display Settings
    position_x INTEGER,
    position_y INTEGER,
    shape VARCHAR(20) DEFAULT 'square' CHECK (shape IN ('square', 'round', 'rectangle')),
    
    -- Metadata
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 2. RESERVATIONS
-- =====================================================

CREATE TABLE IF NOT EXISTS reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservation_number VARCHAR(50) UNIQUE,
    customer_name VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20),
    customer_email VARCHAR(100),
    party_size INTEGER NOT NULL DEFAULT 2,
    table_id UUID REFERENCES restaurant_tables(id),
    reservation_date DATE NOT NULL,
    reservation_time TIME NOT NULL,
    duration_minutes INTEGER DEFAULT 90,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending', 'confirmed', 'seated', 'completed', 'no_show', 'cancelled'
    )),
    special_requests TEXT,
    occasion VARCHAR(50),
    reminder_sent BOOLEAN DEFAULT false,
    confirmation_sent BOOLEAN DEFAULT false,
    created_by UUID REFERENCES auth.users(id),
    confirmed_by UUID REFERENCES auth.users(id),
    confirmed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 3. TABLE STATUS HISTORY (Analytics)
-- =====================================================

CREATE TABLE IF NOT EXISTS table_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_id UUID NOT NULL REFERENCES restaurant_tables(id) ON DELETE CASCADE,
    previous_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    order_id UUID,
    reservation_id UUID REFERENCES reservations(id),
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 4. TABLE SESSIONS (Fixed-Device Authentication)
-- SAP Partner Authorization Model
-- =====================================================

CREATE TABLE IF NOT EXISTS table_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_id UUID REFERENCES restaurant_tables(id) ON DELETE CASCADE,
    access_token VARCHAR(64) UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    device_fingerprint TEXT,
    device_name VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- =====================================================
-- 5. ORDER HEADERS (SAP SD Sales Document - VBAK)
-- =====================================================

CREATE TABLE IF NOT EXISTS order_headers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) UNIQUE NOT NULL,
    
    -- Table & Session
    table_id UUID REFERENCES restaurant_tables(id),
    table_session_id UUID REFERENCES table_sessions(id),
    
    -- Order Type
    order_type VARCHAR(20) DEFAULT 'Dine-In' CHECK (order_type IN ('Dine-In', 'Takeaway', 'Delivery')),
    
    -- Status Workflow
    status VARCHAR(30) DEFAULT 'Ordered' CHECK (status IN (
        'Ordered', 'Preparing', 'Partially Served', 'Served', 'Billed', 'Closed', 'Cancelled'
    )),
    
    -- Waiter Assignment
    assigned_waiter_id UUID REFERENCES auth.users(id),
    
    -- Customer Info (optional for loyalty)
    customer_id UUID,
    customer_name VARCHAR(100),
    customer_phone VARCHAR(20),
    pax_count INTEGER DEFAULT 1,
    
    -- Totals
    subtotal DECIMAL(15,2) DEFAULT 0,
    tax_amount DECIMAL(15,2) DEFAULT 0,
    discount_amount DECIMAL(15,2) DEFAULT 0,
    service_charge DECIMAL(15,2) DEFAULT 0,
    total_amount DECIMAL(15,2) DEFAULT 0,
    
    -- Special Instructions
    special_instructions TEXT,
    
    -- Timestamps
    ordered_at TIMESTAMPTZ DEFAULT NOW(),
    preparing_at TIMESTAMPTZ,
    served_at TIMESTAMPTZ,
    billed_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    
    -- Audit
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 6. ORDER ITEMS (SAP SD Sales Document Lines - VBAP)
-- =====================================================

CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES order_headers(id) ON DELETE CASCADE,
    line_number INTEGER NOT NULL,
    
    -- Item Reference
    item_id UUID REFERENCES items(id),
    item_code VARCHAR(50),
    item_name VARCHAR(255) NOT NULL,
    
    -- Quantity & Price
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(15,2) NOT NULL,
    discount_percent DECIMAL(5,2) DEFAULT 0,
    line_total DECIMAL(15,2) NOT NULL,
    
    -- Item-level Status
    status VARCHAR(30) DEFAULT 'Ordered' CHECK (status IN (
        'Ordered', 'Preparing', 'Ready', 'Served', 'Cancelled'
    )),
    
    -- Special Notes
    special_notes TEXT,
    kot_number VARCHAR(50),
    
    -- Timestamps
    prepared_at TIMESTAMPTZ,
    ready_at TIMESTAMPTZ,
    served_at TIMESTAMPTZ,
    
    -- Constraints
    UNIQUE(order_id, line_number),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 7. KITCHEN ORDERS (KOT - Kitchen Order Ticket)
-- Maps to SAP PP Production Order
-- =====================================================

CREATE TABLE IF NOT EXISTS kitchen_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kot_number VARCHAR(50) UNIQUE NOT NULL,
    
    -- References
    order_id UUID NOT NULL REFERENCES order_headers(id) ON DELETE CASCADE,
    order_item_id UUID REFERENCES order_items(id) ON DELETE CASCADE,
    table_id UUID REFERENCES restaurant_tables(id),
    
    -- Item Info (denormalized for kitchen display)
    item_id UUID REFERENCES items(id),
    item_code VARCHAR(50),
    item_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL,
    
    -- KOT Status
    status VARCHAR(30) DEFAULT 'Pending' CHECK (status IN (
        'Pending', 'In Progress', 'Ready', 'Served', 'Cancelled'
    )),
    
    -- Priority for kitchen
    priority VARCHAR(20) DEFAULT 'Normal' CHECK (priority IN ('Low', 'Normal', 'High', 'Rush')),
    
    -- Kitchen Station (for routing)
    kitchen_station VARCHAR(50),
    
    -- Staff Assignment
    assigned_cook_id UUID REFERENCES auth.users(id),
    
    -- Special Instructions
    special_notes TEXT,
    table_number VARCHAR(20),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    served_at TIMESTAMPTZ
);

-- =====================================================
-- 8. KOT NOTIFICATIONS (Real-time Event Queue)
-- =====================================================

CREATE TABLE IF NOT EXISTS kot_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- References
    kot_id UUID REFERENCES kitchen_orders(id) ON DELETE CASCADE,
    order_id UUID REFERENCES order_headers(id) ON DELETE CASCADE,
    order_item_id UUID REFERENCES order_items(id) ON DELETE CASCADE,
    
    -- Notification Type
    notification_type VARCHAR(50) NOT NULL CHECK (notification_type IN (
        'NEW_ORDER', 'STATUS_UPDATE', 'READY_TO_SERVE', 'ITEM_CANCELLED', 
        'URGENT', 'TABLE_SEATED', 'BILL_REQUESTED'
    )),
    
    -- Target Routing
    target_role VARCHAR(50), -- 'KITCHEN', 'CASHIER', 'MANAGEMENT', 'WAITER'
    target_user_id UUID REFERENCES auth.users(id),
    
    -- Context
    table_id UUID REFERENCES restaurant_tables(id),
    table_number VARCHAR(20),
    
    -- Message
    title VARCHAR(200),
    message TEXT,
    payload JSONB,
    
    -- Status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    read_by UUID REFERENCES auth.users(id),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_tables_status ON restaurant_tables(status);
CREATE INDEX IF NOT EXISTS idx_tables_location ON restaurant_tables(location);
CREATE INDEX IF NOT EXISTS idx_reservations_date ON reservations(reservation_date);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_table_sessions_table ON table_sessions(table_id);
CREATE INDEX IF NOT EXISTS idx_table_sessions_token ON table_sessions(access_token);
CREATE INDEX IF NOT EXISTS idx_order_headers_table ON order_headers(table_id);
CREATE INDEX IF NOT EXISTS idx_order_headers_status ON order_headers(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_status ON order_items(status);
CREATE INDEX IF NOT EXISTS idx_kitchen_orders_order ON kitchen_orders(order_id);
CREATE INDEX IF NOT EXISTS idx_kitchen_orders_status ON kitchen_orders(status);
CREATE INDEX IF NOT EXISTS idx_kot_notifications_role ON kot_notifications(target_role);
CREATE INDEX IF NOT EXISTS idx_kot_notifications_user ON kot_notifications(target_user_id);
CREATE INDEX IF NOT EXISTS idx_kot_notifications_unread ON kot_notifications(is_read) WHERE is_read = false;

-- =====================================================
-- RLS POLICIES
-- =====================================================

ALTER TABLE restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE table_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_headers ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitchen_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE kot_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE table_status_history ENABLE ROW LEVEL SECURITY;

-- Basic policies (allow authenticated users)
CREATE POLICY restaurant_tables_policy ON restaurant_tables FOR ALL TO authenticated USING (true);
CREATE POLICY reservations_policy ON reservations FOR ALL TO authenticated USING (true);
CREATE POLICY table_sessions_policy ON table_sessions FOR ALL TO authenticated USING (true);
CREATE POLICY order_headers_policy ON order_headers FOR ALL TO authenticated USING (true);
CREATE POLICY order_items_policy ON order_items FOR ALL TO authenticated USING (true);
CREATE POLICY kitchen_orders_policy ON kitchen_orders FOR ALL TO authenticated USING (true);
CREATE POLICY kot_notifications_policy ON kot_notifications FOR ALL TO authenticated USING (true);
CREATE POLICY table_history_policy ON table_status_history FOR ALL TO authenticated USING (true);

-- =====================================================
-- TRIGGERS & FUNCTIONS
-- =====================================================

-- Order Number Sequence
CREATE SEQUENCE IF NOT EXISTS order_number_seq START 1;
CREATE SEQUENCE IF NOT EXISTS kot_number_seq START 1;

-- Generate Order Number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_number IS NULL THEN
        NEW.order_number := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
            LPAD(nextval('order_number_seq')::TEXT, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_order_number ON order_headers;
CREATE TRIGGER set_order_number
    BEFORE INSERT ON order_headers
    FOR EACH ROW EXECUTE FUNCTION generate_order_number();

-- Create KOT and Notifications on Order Item Insert
CREATE OR REPLACE FUNCTION create_kot_on_order_item()
RETURNS TRIGGER AS $$
DECLARE
    v_order RECORD;
    v_kot_number TEXT;
    v_kot_id UUID;
BEGIN
    -- Get order details
    SELECT oh.*, rt.table_number 
    INTO v_order
    FROM order_headers oh
    LEFT JOIN restaurant_tables rt ON rt.id = oh.table_id
    WHERE oh.id = NEW.order_id;
    
    -- Generate KOT number
    v_kot_number := 'KOT-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
        LPAD(nextval('kot_number_seq')::TEXT, 4, '0');
    
    -- Insert Kitchen Order
    INSERT INTO kitchen_orders (
        kot_number, order_id, order_item_id, table_id,
        item_id, item_code, item_name, quantity,
        special_notes, table_number
    ) VALUES (
        v_kot_number, NEW.order_id, NEW.id, v_order.table_id,
        NEW.item_id, NEW.item_code, NEW.item_name, NEW.quantity,
        NEW.special_notes, v_order.table_number
    ) RETURNING id INTO v_kot_id;
    
    -- Update order item with KOT number
    NEW.kot_number := v_kot_number;
    
    -- Create notifications for KITCHEN, CASHIER, MANAGEMENT
    INSERT INTO kot_notifications (kot_id, order_id, order_item_id, notification_type, target_role, table_id, table_number, title, message, payload)
    VALUES 
        (v_kot_id, NEW.order_id, NEW.id, 'NEW_ORDER', 'KITCHEN', v_order.table_id, v_order.table_number, 'New Order - ' || v_order.table_number, NEW.quantity || 'x ' || NEW.item_name, jsonb_build_object('kot_number', v_kot_number, 'item_name', NEW.item_name, 'quantity', NEW.quantity)),
        (v_kot_id, NEW.order_id, NEW.id, 'NEW_ORDER', 'CASHIER', v_order.table_id, v_order.table_number, 'New Order - ' || v_order.table_number, 'Order placed: ' || NEW.quantity || 'x ' || NEW.item_name, NULL),
        (v_kot_id, NEW.order_id, NEW.id, 'NEW_ORDER', 'MANAGEMENT', v_order.table_id, v_order.table_number, 'New Order - ' || v_order.table_number, 'Floor Activity: ' || NEW.quantity || 'x ' || NEW.item_name, NULL);
    
    -- Notify assigned waiter
    IF v_order.assigned_waiter_id IS NOT NULL THEN
        INSERT INTO kot_notifications (kot_id, order_id, order_item_id, notification_type, target_role, target_user_id, table_id, table_number, title, message)
        VALUES (v_kot_id, NEW.order_id, NEW.id, 'NEW_ORDER', 'WAITER', v_order.assigned_waiter_id, v_order.table_id, v_order.table_number, 'Your Table Order - ' || v_order.table_number, 'Customer ordered: ' || NEW.quantity || 'x ' || NEW.item_name);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS create_kot_on_order_item ON order_items;
CREATE TRIGGER create_kot_on_order_item
    BEFORE INSERT ON order_items
    FOR EACH ROW EXECUTE FUNCTION create_kot_on_order_item();

-- Backflush stock when order served
CREATE OR REPLACE FUNCTION backflush_on_order_served()
RETURNS TRIGGER AS $$
DECLARE
    v_recipe RECORD;
    v_component RECORD;
    v_kitchen_warehouse_id UUID;
    v_deduct_qty DECIMAL;
BEGIN
    IF NEW.status = 'Served' AND OLD.status != 'Served' THEN
        SELECT r.* INTO v_recipe FROM recipes r WHERE r.sales_item_id = NEW.item_id AND r.is_active = true LIMIT 1;
        
        IF v_recipe.id IS NULL THEN RETURN NEW; END IF;
        
        v_kitchen_warehouse_id := v_recipe.target_warehouse_id;
        
        FOR v_component IN 
            SELECT rl.*, i.item_code AS material_code
            FROM recipe_lines rl JOIN items i ON i.id = rl.item_id
            WHERE rl.recipe_id = v_recipe.id
        LOOP
            v_deduct_qty := (v_component.quantity * NEW.quantity) / COALESCE(v_recipe.yield_quantity, 1);
            
            UPDATE warehouse_stock SET quantity_on_hand = GREATEST(0, quantity_on_hand - v_deduct_qty)
            WHERE item_id = v_component.item_id AND warehouse_id = v_kitchen_warehouse_id;
            
            INSERT INTO stock_transactions (item_id, warehouse_id, transaction_type, quantity, doc_number, notes, item_code)
            VALUES (v_component.item_id, v_kitchen_warehouse_id, 'BACKFLUSH', -v_deduct_qty, NEW.kot_number, 'Auto-backflush: ' || NEW.item_name, v_component.material_code);
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS backflush_on_order_served ON kitchen_orders;
CREATE TRIGGER backflush_on_order_served
    AFTER UPDATE ON kitchen_orders
    FOR EACH ROW EXECUTE FUNCTION backflush_on_order_served();

-- =====================================================
-- RPC FUNCTIONS
-- =====================================================

-- Get customer menu (Servable items only)
CREATE OR REPLACE FUNCTION get_customer_menu(p_table_id UUID DEFAULT NULL)
RETURNS TABLE (item_id UUID, item_code VARCHAR, item_name VARCHAR, category_name TEXT, selling_price DECIMAL, description TEXT, is_available BOOLEAN) AS $$
BEGIN
    RETURN QUERY
    SELECT i.id, i.item_code, i.item_name, COALESCE(ic.name, 'Uncategorized')::TEXT, i.selling_price, i.description, true
    FROM items i LEFT JOIN item_categories ic ON ic.id = i.category_id
    WHERE i.item_identity = 'Servable' AND i.is_active = true AND i.is_sales_item = true
    ORDER BY ic.name NULLS LAST, i.item_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Validate table access token
CREATE OR REPLACE FUNCTION validate_table_token(p_access_token TEXT)
RETURNS TABLE (session_id UUID, table_id UUID, table_number VARCHAR, table_status VARCHAR, capacity INTEGER, location VARCHAR) AS $$
BEGIN
    UPDATE table_sessions SET last_activity_at = NOW() WHERE access_token = p_access_token AND is_active = true;
    RETURN QUERY
    SELECT ts.id, ts.table_id, rt.table_number, rt.status, rt.capacity, rt.location
    FROM table_sessions ts JOIN restaurant_tables rt ON rt.id = ts.table_id
    WHERE ts.access_token = p_access_token AND ts.is_active = true AND (ts.expires_at IS NULL OR ts.expires_at > NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create table session
CREATE OR REPLACE FUNCTION create_table_session(p_table_id UUID, p_device_name VARCHAR DEFAULT NULL, p_expires_days INTEGER DEFAULT NULL)
RETURNS TABLE (session_id UUID, access_token VARCHAR, table_number VARCHAR) AS $$
DECLARE v_session_id UUID; v_token VARCHAR;
BEGIN
    INSERT INTO table_sessions (table_id, device_name, expires_at, created_by)
    VALUES (p_table_id, p_device_name, CASE WHEN p_expires_days IS NOT NULL THEN NOW() + (p_expires_days || ' days')::INTERVAL ELSE NULL END, auth.uid())
    RETURNING id, table_sessions.access_token INTO v_session_id, v_token;
    UPDATE restaurant_tables SET current_session_id = v_session_id WHERE id = p_table_id;
    RETURN QUERY SELECT v_session_id, v_token, rt.table_number FROM restaurant_tables rt WHERE rt.id = p_table_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get kitchen orders
CREATE OR REPLACE FUNCTION get_kitchen_orders(p_station VARCHAR DEFAULT NULL, p_status VARCHAR DEFAULT NULL)
RETURNS TABLE (kot_id UUID, kot_number VARCHAR, table_number VARCHAR, item_name VARCHAR, quantity INTEGER, status VARCHAR, priority VARCHAR, special_notes TEXT, created_at TIMESTAMPTZ, elapsed_minutes INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT ko.id, ko.kot_number, ko.table_number, ko.item_name::VARCHAR, ko.quantity, ko.status, ko.priority, ko.special_notes, ko.created_at, EXTRACT(EPOCH FROM (NOW() - ko.created_at))::INTEGER / 60
    FROM kitchen_orders ko
    WHERE (p_station IS NULL OR ko.kitchen_station = p_station) AND (p_status IS NULL OR ko.status = p_status) AND ko.status NOT IN ('Served', 'Cancelled')
    ORDER BY CASE ko.priority WHEN 'Rush' THEN 1 WHEN 'High' THEN 2 WHEN 'Normal' THEN 3 ELSE 4 END, ko.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- GRANTS
-- =====================================================

GRANT ALL ON restaurant_tables TO authenticated;
GRANT ALL ON reservations TO authenticated;
GRANT ALL ON table_sessions TO authenticated;
GRANT ALL ON order_headers TO authenticated;
GRANT ALL ON order_items TO authenticated;
GRANT ALL ON kitchen_orders TO authenticated;
GRANT ALL ON kot_notifications TO authenticated;
GRANT ALL ON table_status_history TO authenticated;

GRANT SELECT ON table_sessions TO anon;
GRANT SELECT, INSERT ON order_headers TO anon;
GRANT SELECT, INSERT ON order_items TO anon;

GRANT EXECUTE ON FUNCTION get_customer_menu TO authenticated, anon;
GRANT EXECUTE ON FUNCTION validate_table_token TO authenticated, anon;
GRANT EXECUTE ON FUNCTION create_table_session TO authenticated;
GRANT EXECUTE ON FUNCTION get_kitchen_orders TO authenticated;

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO restaurant_tables (table_number, capacity, location, section, position_x, position_y, shape) VALUES
('T01', 2, 'Indoor', 'Main Hall', 100, 100, 'square'),
('T02', 2, 'Indoor', 'Main Hall', 200, 100, 'square'),
('T03', 4, 'Indoor', 'Main Hall', 300, 100, 'square'),
('T04', 4, 'Indoor', 'Main Hall', 100, 200, 'square'),
('T05', 6, 'Indoor', 'Main Hall', 200, 200, 'rectangle'),
('T06', 6, 'Indoor', 'Main Hall', 350, 200, 'rectangle'),
('T07', 8, 'Indoor', 'Private', 100, 350, 'rectangle'),
('T08', 4, 'Outdoor', 'Terrace', 500, 100, 'round'),
('T09', 4, 'Outdoor', 'Terrace', 600, 100, 'round'),
('T10', 10, 'Indoor', 'VIP Room', 500, 300, 'rectangle'),
('BAR1', 1, 'Indoor', 'Bar Area', 700, 100, 'square'),
('BAR2', 1, 'Indoor', 'Bar Area', 750, 100, 'square'),
('BAR3', 1, 'Indoor', 'Bar Area', 800, 100, 'square'),
('TK01', 0, 'Counter', 'Takeaway', 0, 0, 'square')
ON CONFLICT (table_number) DO NOTHING;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ Table Ordering System installed successfully!';
    RAISE NOTICE '📊 Tables: restaurant_tables, reservations, table_sessions, order_headers, order_items, kitchen_orders, kot_notifications';
    RAISE NOTICE '🔔 Real-time: Notifications routed to KITCHEN, CASHIER, MANAGEMENT, WAITER';
    RAISE NOTICE '📦 Backflushing: Auto-deduct stock on Served status';
END $$;
