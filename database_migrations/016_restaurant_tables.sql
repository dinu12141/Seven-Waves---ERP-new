-- =================================================================
-- SEVEN WAVES ERP - RESTAURANT TABLES & RESERVATIONS
-- Migration: 016_restaurant_tables.sql
-- =================================================================

-- =====================================================
-- 1. RESTAURANT TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS restaurant_tables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_number VARCHAR(20) UNIQUE NOT NULL,
    
    -- Capacity & Location
    capacity INTEGER NOT NULL DEFAULT 4,
    location VARCHAR(50), -- 'Indoor', 'Outdoor', 'Terrace', 'VIP Room'
    floor_number INTEGER DEFAULT 1,
    section VARCHAR(50), -- 'Main Hall', 'Private', 'Bar Area'
    
    -- Status
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN (
        'available',
        'occupied', 
        'reserved',
        'cleaning',
        'out_of_service'
    )),
    
    -- Current Order (if occupied)
    current_order_id UUID,
    current_waiter_id UUID REFERENCES auth.users(id),
    
    -- Display Settings
    position_x INTEGER, -- For visual table layout
    position_y INTEGER,
    shape VARCHAR(20) DEFAULT 'square' CHECK (shape IN ('square', 'round', 'rectangle')),
    
    -- Metadata
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. RESERVATIONS
-- =====================================================

CREATE TABLE IF NOT EXISTS reservations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reservation_number VARCHAR(50) UNIQUE NOT NULL,
    
    -- Customer Details
    customer_name VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20),
    customer_email VARCHAR(100),
    party_size INTEGER NOT NULL DEFAULT 2,
    
    -- Table Assignment
    table_id UUID REFERENCES restaurant_tables(id),
    
    -- Timing
    reservation_date DATE NOT NULL,
    reservation_time TIME NOT NULL,
    duration_minutes INTEGER DEFAULT 90, -- Expected duration
    
    -- Status Workflow
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',      -- Requested, awaiting confirmation
        'confirmed',    -- Confirmed by staff
        'seated',       -- Customer arrived and seated
        'completed',    -- Finished dining
        'no_show',      -- Customer didn't arrive
        'cancelled'     -- Cancelled by customer/staff
    )),
    
    -- Special Requests
    special_requests TEXT,
    occasion VARCHAR(50), -- 'Birthday', 'Anniversary', 'Business', etc.
    
    -- Notification
    reminder_sent BOOLEAN DEFAULT false,
    confirmation_sent BOOLEAN DEFAULT false,
    
    -- Staff Assignment
    created_by UUID REFERENCES auth.users(id),
    confirmed_by UUID REFERENCES auth.users(id),
    confirmed_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. TABLE STATUS HISTORY (For analytics)
-- =====================================================

CREATE TABLE IF NOT EXISTS table_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_id UUID NOT NULL REFERENCES restaurant_tables(id) ON DELETE CASCADE,
    previous_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    order_id UUID,
    reservation_id UUID REFERENCES reservations(id),
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 4. GENERATE RESERVATION NUMBER
-- =====================================================

CREATE OR REPLACE FUNCTION generate_reservation_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.reservation_number IS NULL THEN
        NEW.reservation_number := 'RES-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
            LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_reservation_number ON reservations;
CREATE TRIGGER set_reservation_number
    BEFORE INSERT ON reservations
    FOR EACH ROW EXECUTE FUNCTION generate_reservation_number();

-- =====================================================
-- 5. TABLE STATUS CHANGE TRIGGER
-- =====================================================

CREATE OR REPLACE FUNCTION log_table_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO table_status_history (
            table_id, previous_status, new_status, 
            order_id, changed_by
        ) VALUES (
            NEW.id, OLD.status, NEW.status,
            NEW.current_order_id, auth.uid()
        );
    END IF;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS track_table_status ON restaurant_tables;
CREATE TRIGGER track_table_status
    BEFORE UPDATE ON restaurant_tables
    FOR EACH ROW EXECUTE FUNCTION log_table_status_change();

-- =====================================================
-- 6. AUTO-UPDATE TABLE STATUS ON RESERVATION
-- =====================================================

CREATE OR REPLACE FUNCTION update_table_on_reservation()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        -- When reservation is seated
        IF NEW.status = 'seated' AND OLD.status != 'seated' THEN
            UPDATE restaurant_tables SET status = 'occupied'
            WHERE id = NEW.table_id;
        END IF;
        
        -- When reservation is completed or cancelled
        IF NEW.status IN ('completed', 'cancelled', 'no_show') 
        AND OLD.status NOT IN ('completed', 'cancelled', 'no_show') THEN
            UPDATE restaurant_tables SET status = 'available', current_order_id = NULL
            WHERE id = NEW.table_id;
        END IF;
    ELSIF TG_OP = 'INSERT' THEN
        -- Mark table as reserved
        IF NEW.status = 'confirmed' AND NEW.table_id IS NOT NULL THEN
            UPDATE restaurant_tables SET status = 'reserved'
            WHERE id = NEW.table_id AND status = 'available';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_table_reservation ON reservations;
CREATE TRIGGER sync_table_reservation
    AFTER INSERT OR UPDATE ON reservations
    FOR EACH ROW EXECUTE FUNCTION update_table_on_reservation();

-- =====================================================
-- 7. INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_tables_status ON restaurant_tables(status);
CREATE INDEX IF NOT EXISTS idx_tables_location ON restaurant_tables(location);
CREATE INDEX IF NOT EXISTS idx_reservations_date ON reservations(reservation_date);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_reservations_table ON reservations(table_id);
CREATE INDEX IF NOT EXISTS idx_reservations_customer ON reservations(customer_phone);
CREATE INDEX IF NOT EXISTS idx_table_history_table ON table_status_history(table_id);

-- =====================================================
-- 8. RLS POLICIES
-- =====================================================

ALTER TABLE restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE table_status_history ENABLE ROW LEVEL SECURITY;

-- Restaurant Tables: Viewable by all staff, manageable by managers
DROP POLICY IF EXISTS tables_view_policy ON restaurant_tables;
CREATE POLICY tables_view_policy ON restaurant_tables
    FOR SELECT TO authenticated
    USING (
        has_permission(auth.uid(), 'tables', 'view')
    );

DROP POLICY IF EXISTS tables_manage_policy ON restaurant_tables;
CREATE POLICY tables_manage_policy ON restaurant_tables
    FOR ALL TO authenticated
    USING (
        has_permission(auth.uid(), 'tables', 'manage')
    );

-- Reservations
DROP POLICY IF EXISTS reservations_view_policy ON reservations;
CREATE POLICY reservations_view_policy ON reservations
    FOR SELECT TO authenticated
    USING (
        has_permission(auth.uid(), 'reservations', 'read')
    );

DROP POLICY IF EXISTS reservations_manage_policy ON reservations;
CREATE POLICY reservations_manage_policy ON reservations
    FOR ALL TO authenticated
    USING (
        has_permission(auth.uid(), 'reservations', 'create')
        OR has_permission(auth.uid(), 'reservations', 'update')
    );

-- Table History: Read-only for managers
DROP POLICY IF EXISTS table_history_policy ON table_status_history;
CREATE POLICY table_history_policy ON table_status_history
    FOR SELECT TO authenticated
    USING (
        has_permission(auth.uid(), 'reports', 'sales')
    );

-- =====================================================
-- 9. RPC FUNCTIONS
-- =====================================================

-- Get available tables for reservation
CREATE OR REPLACE FUNCTION get_available_tables(
    p_date DATE,
    p_time TIME,
    p_party_size INTEGER DEFAULT 2,
    p_duration_minutes INTEGER DEFAULT 90
)
RETURNS TABLE (
    table_id UUID,
    table_number VARCHAR,
    capacity INTEGER,
    location VARCHAR,
    section VARCHAR
) AS $$
DECLARE
    time_window_start TIME;
    time_window_end TIME;
BEGIN
    -- Calculate time window
    time_window_start := p_time - INTERVAL '1 hour';
    time_window_end := p_time + (p_duration_minutes || ' minutes')::INTERVAL;
    
    RETURN QUERY
    SELECT 
        rt.id AS table_id,
        rt.table_number,
        rt.capacity,
        rt.location,
        rt.section
    FROM restaurant_tables rt
    WHERE rt.is_active = true
    AND rt.capacity >= p_party_size
    AND rt.status IN ('available', 'reserved')
    AND rt.id NOT IN (
        SELECT r.table_id
        FROM reservations r
        WHERE r.reservation_date = p_date
        AND r.status IN ('pending', 'confirmed', 'seated')
        AND r.table_id IS NOT NULL
        AND (
            (r.reservation_time <= time_window_end AND 
             r.reservation_time + (r.duration_minutes || ' minutes')::INTERVAL >= p_time)
        )
    )
    ORDER BY rt.capacity, rt.table_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get today's reservations
CREATE OR REPLACE FUNCTION get_todays_reservations()
RETURNS TABLE (
    id UUID,
    reservation_number VARCHAR,
    customer_name VARCHAR,
    customer_phone VARCHAR,
    party_size INTEGER,
    table_number VARCHAR,
    reservation_time TIME,
    status VARCHAR,
    special_requests TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.reservation_number,
        r.customer_name,
        r.customer_phone,
        r.party_size,
        rt.table_number,
        r.reservation_time,
        r.status,
        r.special_requests
    FROM reservations r
    LEFT JOIN restaurant_tables rt ON rt.id = r.table_id
    WHERE r.reservation_date = CURRENT_DATE
    AND r.status NOT IN ('cancelled', 'no_show')
    ORDER BY r.reservation_time;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update table status
CREATE OR REPLACE FUNCTION update_table_status(
    p_table_id UUID,
    p_new_status VARCHAR,
    p_order_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE restaurant_tables
    SET status = p_new_status,
        current_order_id = COALESCE(p_order_id, current_order_id),
        current_waiter_id = CASE WHEN p_new_status = 'occupied' THEN auth.uid() ELSE current_waiter_id END
    WHERE id = p_table_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 10. SEED DATA - SAMPLE TABLES
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

-- =====================================================
-- 11. GRANT PERMISSIONS
-- =====================================================

GRANT ALL ON restaurant_tables TO authenticated;
GRANT ALL ON reservations TO authenticated;
GRANT ALL ON table_status_history TO authenticated;

GRANT EXECUTE ON FUNCTION get_available_tables TO authenticated;
GRANT EXECUTE ON FUNCTION get_todays_reservations TO authenticated;
GRANT EXECUTE ON FUNCTION update_table_status TO authenticated;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ Restaurant Tables & Reservations installed successfully!';
    RAISE NOTICE '📊 Tables created: restaurant_tables, reservations, table_status_history';
    RAISE NOTICE '🍽️ Sample tables seeded: T01-T10, BAR1-BAR3, TK01';
    RAISE NOTICE '📋 RPC functions: get_available_tables, get_todays_reservations, update_table_status';
END $$;
