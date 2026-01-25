-- =====================================================
-- SAP Procurement Flow - Database Migration
-- Implements PR -> PO -> GRPO Logic
-- =====================================================

-- 1. Create Purchase Requests Table (OPRQ)
CREATE TABLE IF NOT EXISTS purchase_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    requester_id UUID REFERENCES profiles(id),
    required_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'Open' CHECK (status IN ('Open', 'Closed', 'Cancelled', 'Ordered')),
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS purchase_request_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID REFERENCES purchase_requests(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id),
    required_quantity DECIMAL(10, 2) NOT NULL,
    uom_id UUID REFERENCES units_of_measure(id),
    open_quantity DECIMAL(10, 2) NOT NULL DEFAULT 0, -- Remaining Qty to be ordered
    preferred_vendor_id UUID REFERENCES suppliers(id),
    line_status VARCHAR(20) DEFAULT 'Open' CHECK (line_status IN ('Open', 'Closed'))
);

-- 2. Enhance Purchase Orders (OPOR) - Already exists, but ensure fields
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS tax_code_id UUID, -- Placeholder
ADD COLUMN IF NOT EXISTS doc_status VARCHAR(20) DEFAULT 'Open' CHECK (doc_status IN ('Open', 'Closed', 'Cancelled')),
ADD COLUMN IF NOT EXISTS base_type VARCHAR(20), -- 'PurchaseRequest', etc.
ADD COLUMN IF NOT EXISTS base_entry UUID; -- Link to PR ID

ALTER TABLE po_lines
ADD COLUMN IF NOT EXISTS base_line_id UUID, -- Link to PR Line ID
ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS line_total DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS open_quantity DECIMAL(10, 2); -- Qty remaining to be received (GRPO)

-- 3. Inventory Alerts Table (OALT)
CREATE TABLE IF NOT EXISTS inventory_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID REFERENCES items(id),
    warehouse_id UUID REFERENCES warehouses(id),
    alert_type VARCHAR(50) DEFAULT 'LowStock',
    message TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- A. Auto-Update Ordered Qty in Warehouse Stock when PO is Approved
-- Note: 'quantity_ordered' in warehouse_stock matches SAP 'Ordered'
CREATE OR REPLACE FUNCTION update_ordered_stock_on_po() RETURNS TRIGGER AS $$
BEGIN
    -- When PO Line is Created (pending approval logic handled in app, or assume 'Open' means approved/sent)
    -- In SAP, 'Ordered' increases as soon as PO is added.
    IF (TG_OP = 'INSERT') THEN
        UPDATE warehouse_stock
        SET quantity_ordered = quantity_ordered + NEW.quantity
        WHERE item_id = NEW.item_id 
          AND warehouse_id = (SELECT warehouse_id FROM purchase_orders WHERE id = NEW.purchase_order_id);
    
    -- If Line Updated (Qty changed)
    ELSIF (TG_OP = 'UPDATE') THEN
        UPDATE warehouse_stock
        SET quantity_ordered = quantity_ordered - OLD.quantity + NEW.quantity
        WHERE item_id = NEW.item_id 
          AND warehouse_id = (SELECT warehouse_id FROM purchase_orders WHERE id = NEW.purchase_order_id);
          
    -- If Line Deleted
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE warehouse_stock
        SET quantity_ordered = quantity_ordered - OLD.quantity
        WHERE item_id = OLD.item_id 
          AND warehouse_id = (SELECT warehouse_id FROM purchase_orders WHERE id = OLD.purchase_order_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_po_stock_ordered
AFTER INSERT OR UPDATE OR DELETE ON po_lines
FOR EACH ROW EXECUTE FUNCTION update_ordered_stock_on_po();

-- B. Auto-Update 'On Hand' and decrease 'Ordered' when GRN (GRPO) is added
-- Existing GRN logic might update 'On Hand', ensure it also REDUCES 'Ordered'
CREATE OR REPLACE FUNCTION update_stock_on_grn_sap() RETURNS TRIGGER AS $$
DECLARE
    po_line_record RECORD;
BEGIN
    IF (TG_OP = 'INSERT') THEN
         -- 1. Increase Stock (Already implemented in many systems, ensuring here)
         -- Handled by existing triggers? If duplicate, logic should be checked. 
         -- Assuming existing trigger handles On Hand.
         
         -- 2. Decrease 'Ordered' Stock (This matches SAP Logic: Available = Stock + Ordered - Committed)
         -- When received, it moves from 'Ordered' to 'Stock'.
         
         -- It seems we need to know WHICH PO this came from.
         IF NEW.po_line_id IS NOT NULL THEN
             SELECT * INTO po_line_record FROM po_lines WHERE id = NEW.po_line_id;
             
             UPDATE warehouse_stock
             SET quantity_ordered = quantity_ordered - NEW.quantity
             WHERE item_id = NEW.item_id
               AND warehouse_id = NEW.warehouse_id; -- Or PO warehouse?
         END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_grn_sap_update
AFTER INSERT ON grn_lines
FOR EACH ROW EXECUTE FUNCTION update_stock_on_grn_sap();

-- C. Check Low Stock Trigger (Runs on Stock Update)
CREATE OR REPLACE FUNCTION check_min_stock_alert() RETURNS TRIGGER AS $$
DECLARE
    current_available DECIMAL;
    min_stock DECIMAL;
    item_record RECORD;
BEGIN
    SELECT * INTO item_record FROM items WHERE id = NEW.item_id;
    min_stock := item_record.min_stock_level;

    -- Formula: Available = OnHand - Committed + Ordered
    current_available := NEW.quantity_on_hand - NEW.quantity_committed + NEW.quantity_ordered;

    IF current_available < min_stock THEN
        -- Insert Alert if not recently alerted? (Simple version: always insert)
        INSERT INTO inventory_alerts (item_id, warehouse_id, message)
        VALUES (NEW.item_id, NEW.warehouse_id, 'Stock fell below minimum level. Current Available: ' || current_available);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_check_min_stock
AFTER UPDATE ON warehouse_stock
FOR EACH ROW EXECUTE FUNCTION check_min_stock_alert();
