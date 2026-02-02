-- =====================================================
-- SAP HANA Stock Module Alignment Migration
-- Seven Waves ERP - Based on Requirement Documents
-- =====================================================

-- =====================================================
-- 1. ITEM MASTER ENHANCEMENTS (MARA/MARD Alignment)
-- =====================================================

-- Add Item Identity (Servable/Non-Servable) - Critical for Seven Waves
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS item_identity VARCHAR(20) DEFAULT 'Non-Servable' 
    CHECK (item_identity IN ('Servable', 'Non-Servable'));

-- Add Item Category (Raw Material/Finished Good/Packing Set)
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS item_category VARCHAR(30) DEFAULT 'Raw Material'
    CHECK (item_category IN ('Raw Material', 'Finished Good', 'Packing Set', 'Semi-Finished'));

-- Add Barcode field for GRN handling
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS barcode VARCHAR(50);

-- Add default supplier reference
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS default_supplier_id UUID REFERENCES suppliers(id);

-- Create index for barcode lookups (GRN scanning)
CREATE INDEX IF NOT EXISTS idx_items_barcode ON items(barcode) WHERE barcode IS NOT NULL;

COMMENT ON COLUMN items.item_identity IS 'Servable items can be served to customers, Non-Servable are production-only';
COMMENT ON COLUMN items.item_category IS 'Seven Waves material categorization';
COMMENT ON COLUMN items.barcode IS 'Product barcode for GRN scanning';

-- =====================================================
-- 2. WAREHOUSE ENHANCEMENTS
-- =====================================================

ALTER TABLE warehouses
ADD COLUMN IF NOT EXISTS category VARCHAR(30) DEFAULT 'Stores'
    CHECK (category IN ('Selling', 'Branch', 'Stores', 'Service', 'Production')),
ADD COLUMN IF NOT EXISTS city VARCHAR(100),
ADD COLUMN IF NOT EXISTS contact_no VARCHAR(20),
ADD COLUMN IF NOT EXISTS address TEXT;

-- =====================================================
-- 3. STOCK REQUESTS (Good Request Note)
-- =====================================================

-- Stock Request Header
CREATE TABLE IF NOT EXISTS stock_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    request_type VARCHAR(30) DEFAULT 'Internal' 
        CHECK (request_type IN ('Internal', 'Kitchen', 'Branch')),
    requester_id UUID REFERENCES profiles(id) NOT NULL,
    from_warehouse_id UUID REFERENCES warehouses(id) NOT NULL,
    need_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'Pending' 
        CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Issued', 'Cancelled')),
    remarks TEXT,
    approved_by UUID REFERENCES profiles(id),
    approved_at TIMESTAMPTZ,
    rejected_reason TEXT,
    issued_by UUID REFERENCES profiles(id),
    issued_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Stock Request Lines
CREATE TABLE IF NOT EXISTS stock_request_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID REFERENCES stock_requests(id) ON DELETE CASCADE,
    line_num INT NOT NULL,
    item_id UUID REFERENCES items(id) NOT NULL,
    item_code VARCHAR(50),
    requested_quantity DECIMAL(15, 4) NOT NULL CHECK (requested_quantity > 0),
    available_stock DECIMAL(15, 4) DEFAULT 0,
    approved_quantity DECIMAL(15, 4),
    issued_quantity DECIMAL(15, 4) DEFAULT 0,
    uom_id UUID REFERENCES units_of_measure(id),
    confirmation BOOLEAN DEFAULT false,
    UNIQUE(request_id, line_num)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_stock_requests_status ON stock_requests(status);
CREATE INDEX IF NOT EXISTS idx_stock_requests_requester ON stock_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_stock_request_lines_request ON stock_request_lines(request_id);

-- =====================================================
-- 4. PRODUCTION ORDERS (Product Finishing Note)
-- =====================================================

-- Production Order Header
CREATE TABLE IF NOT EXISTS production_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    recipe_id UUID REFERENCES recipes(id) NOT NULL,
    finished_item_id UUID REFERENCES items(id) NOT NULL,
    production_warehouse_id UUID REFERENCES warehouses(id) NOT NULL,
    target_quantity DECIMAL(15, 4) NOT NULL,
    actual_quantity DECIMAL(15, 4),
    status VARCHAR(20) DEFAULT 'Planned' 
        CHECK (status IN ('Planned', 'Released', 'In Progress', 'Finished', 'Cancelled')),
    planned_start_date DATE,
    actual_start_date DATE,
    finished_at TIMESTAMPTZ,
    created_by UUID REFERENCES profiles(id),
    finished_by UUID REFERENCES profiles(id),
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Production Order Components (for backflushing)
CREATE TABLE IF NOT EXISTS production_order_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    production_order_id UUID REFERENCES production_orders(id) ON DELETE CASCADE,
    line_num INT NOT NULL,
    item_id UUID REFERENCES items(id) NOT NULL,
    item_code VARCHAR(50),
    required_quantity DECIMAL(15, 4) NOT NULL,
    issued_quantity DECIMAL(15, 4) DEFAULT 0,
    uom_id UUID REFERENCES units_of_measure(id),
    warehouse_id UUID REFERENCES warehouses(id),
    backflushed BOOLEAN DEFAULT false,
    UNIQUE(production_order_id, line_num)
);

CREATE INDEX IF NOT EXISTS idx_production_orders_status ON production_orders(status);
CREATE INDEX IF NOT EXISTS idx_production_order_components_order ON production_order_components(production_order_id);

-- =====================================================
-- 5. BACKFLUSHING TRIGGER
-- Auto-deduct raw materials when production is finished
-- =====================================================

CREATE OR REPLACE FUNCTION process_production_finishing()
RETURNS TRIGGER AS $$
DECLARE
    component RECORD;
    deduct_qty DECIMAL;
    ratio DECIMAL;
BEGIN
    -- Only trigger when status changes to 'Finished'
    IF NEW.status = 'Finished' AND (OLD.status IS NULL OR OLD.status != 'Finished') THEN
        
        -- Calculate production ratio
        ratio := COALESCE(NEW.actual_quantity, NEW.target_quantity) / NEW.target_quantity;
        
        -- Loop through all components
        FOR component IN 
            SELECT poc.*, i.item_code AS code
            FROM production_order_components poc
            JOIN items i ON i.id = poc.item_id
            WHERE poc.production_order_id = NEW.id
              AND poc.backflushed = false
        LOOP
            -- Calculate quantity to deduct
            deduct_qty := component.required_quantity * ratio;
            
            -- Deduct from production warehouse stock
            UPDATE warehouse_stock
            SET quantity_on_hand = GREATEST(0, quantity_on_hand - deduct_qty),
                updated_at = NOW()
            WHERE item_id = component.item_id 
              AND warehouse_id = component.warehouse_id;
            
            -- Create stock transaction for audit trail
            INSERT INTO stock_transactions (
                item_id, warehouse_id, transaction_type, 
                quantity, doc_number, notes, item_code
            ) VALUES (
                component.item_id,
                component.warehouse_id,
                'BACKFLUSH',
                -deduct_qty,
                NEW.doc_number,
                'Auto-backflush: ' || NEW.doc_number,
                component.code
            );
            
            -- Mark component as backflushed
            UPDATE production_order_components
            SET backflushed = true, issued_quantity = deduct_qty
            WHERE id = component.id;
        END LOOP;
        
        -- Increase finished goods stock
        INSERT INTO warehouse_stock (item_id, warehouse_id, quantity_on_hand, item_code)
        VALUES (NEW.finished_item_id, NEW.production_warehouse_id, COALESCE(NEW.actual_quantity, NEW.target_quantity), 
               (SELECT item_code FROM items WHERE id = NEW.finished_item_id))
        ON CONFLICT (item_id, warehouse_id) 
        DO UPDATE SET quantity_on_hand = warehouse_stock.quantity_on_hand + COALESCE(NEW.actual_quantity, NEW.target_quantity);
        
        -- Create receipt transaction for finished goods
        INSERT INTO stock_transactions (
            item_id, warehouse_id, transaction_type,
            quantity, doc_number, notes
        ) VALUES (
            NEW.finished_item_id,
            NEW.production_warehouse_id,
            'PRODUCTION_RECEIPT',
            COALESCE(NEW.actual_quantity, NEW.target_quantity),
            NEW.doc_number,
            'Finished goods from production'
        );
        
        -- Update finished timestamp
        NEW.finished_at := NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_production_finishing ON production_orders;
CREATE TRIGGER trg_production_finishing
BEFORE UPDATE ON production_orders
FOR EACH ROW EXECUTE FUNCTION process_production_finishing();

-- =====================================================
-- 6. STOCK REQUEST APPROVAL TRIGGER
-- Auto-update status when approved
-- =====================================================

CREATE OR REPLACE FUNCTION on_stock_request_approved()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'Approved' AND OLD.status = 'Pending' THEN
        NEW.approved_at := NOW();
        -- Auto-fill approved quantities if not set
        UPDATE stock_request_lines
        SET approved_quantity = COALESCE(approved_quantity, requested_quantity)
        WHERE request_id = NEW.id AND approved_quantity IS NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stock_request_approved ON stock_requests;
CREATE TRIGGER trg_stock_request_approved
BEFORE UPDATE ON stock_requests
FOR EACH ROW EXECUTE FUNCTION on_stock_request_approved();

-- =====================================================
-- 7. HELPER FUNCTIONS
-- =====================================================

-- Generate Stock Request Number
CREATE OR REPLACE FUNCTION generate_stock_request_number()
RETURNS TEXT AS $$
DECLARE
    new_num TEXT;
    seq_num INT;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(doc_number FROM 'SRQ-(\d+)') AS INT)), 0) + 1
    INTO seq_num
    FROM stock_requests
    WHERE doc_number LIKE 'SRQ-%';
    
    new_num := 'SRQ-' || LPAD(seq_num::TEXT, 6, '0');
    RETURN new_num;
END;
$$ LANGUAGE plpgsql;

-- Generate Production Order Number
CREATE OR REPLACE FUNCTION generate_production_order_number()
RETURNS TEXT AS $$
DECLARE
    new_num TEXT;
    seq_num INT;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(doc_number FROM 'PRD-(\d+)') AS INT)), 0) + 1
    INTO seq_num
    FROM production_orders
    WHERE doc_number LIKE 'PRD-%';
    
    new_num := 'PRD-' || LPAD(seq_num::TEXT, 6, '0');
    RETURN new_num;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. RLS POLICIES
-- =====================================================

ALTER TABLE stock_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_request_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_order_components ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view/create stock requests
CREATE POLICY "Users can view stock requests" ON stock_requests
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can create stock requests" ON stock_requests
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update stock requests" ON stock_requests
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Users can view stock request lines" ON stock_request_lines
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can manage stock request lines" ON stock_request_lines
    FOR ALL USING (auth.role() = 'authenticated');

-- Production orders policies
CREATE POLICY "Users can view production orders" ON production_orders
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can create production orders" ON production_orders
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update production orders" ON production_orders
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Users can view production components" ON production_order_components
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can manage production components" ON production_order_components
    FOR ALL USING (auth.role() = 'authenticated');
