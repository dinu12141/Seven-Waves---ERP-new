-- 1. Create Sequence Table
CREATE TABLE IF NOT EXISTS item_series (
    prefix TEXT PRIMARY KEY,
    current_val INTEGER DEFAULT 0,
    description TEXT
);

-- Insert default prefixes
INSERT INTO item_series (prefix, description) VALUES
('RM', 'Raw Material'),
('FG', 'Finished Good'),
('SF', 'Semi-Finished'),
('TG', 'Trading Good'),
('SR', 'Service'),
('FA', 'Fixed Asset')
ON CONFLICT (prefix) DO NOTHING;

-- 2. Function to generate next code
CREATE OR REPLACE FUNCTION generate_next_item_code(p_prefix TEXT)
RETURNS TEXT AS $$
DECLARE
    next_val INTEGER;
    new_code TEXT;
BEGIN
    -- Atomic update and return
    UPDATE item_series
    SET current_val = current_val + 1
    WHERE prefix = p_prefix
    RETURNING current_val INTO next_val;

    IF next_val IS NULL THEN
        -- Initialize if not exists
        INSERT INTO item_series (prefix, current_val) VALUES (p_prefix, 1);
        next_val := 1;
    END IF;

    -- Format: PREFIX-0001 (4 digits)
    new_code := p_prefix || '-' || LPAD(next_val::TEXT, 4, '0');
    RETURN new_code;
END;
$$ LANGUAGE plpgsql;

-- 3. Update Item Master (items)
-- Ensure item_code is unique.
ALTER TABLE items ADD CONSTRAINT items_item_code_key UNIQUE (item_code);

-- 4. Foreign Keys with Cascade (Example for PO Lines)
-- Add item_code column if not exists
ALTER TABLE po_lines ADD COLUMN IF NOT EXISTS item_code TEXT;

-- Update item_code based on item_id (Data Migration)
UPDATE po_lines 
SET item_code = items.item_code 
FROM items 
WHERE po_lines.item_id = items.id 
AND po_lines.item_code IS NULL;

-- Add FK Constraint
ALTER TABLE po_lines 
ADD CONSTRAINT fk_po_lines_item_code 
FOREIGN KEY (item_code) REFERENCES items(item_code) 
ON UPDATE CASCADE;

-- Repeat for other tables: grn_lines, warehouse_stock, stock_transactions
-- GRN Lines
ALTER TABLE grn_lines ADD COLUMN IF NOT EXISTS item_code TEXT;
UPDATE grn_lines SET item_code = items.item_code FROM items WHERE grn_lines.item_id = items.id AND grn_lines.item_code IS NULL;
ALTER TABLE grn_lines ADD CONSTRAINT fk_grn_lines_item_code FOREIGN KEY (item_code) REFERENCES items(item_code) ON UPDATE CASCADE;

-- Warehouse Stock
ALTER TABLE warehouse_stock ADD COLUMN IF NOT EXISTS item_code TEXT;
UPDATE warehouse_stock SET item_code = items.item_code FROM items WHERE warehouse_stock.item_id = items.id AND warehouse_stock.item_code IS NULL;
ALTER TABLE warehouse_stock ADD CONSTRAINT fk_warehouse_stock_item_code FOREIGN KEY (item_code) REFERENCES items(item_code) ON UPDATE CASCADE;

-- Stock Transactions
ALTER TABLE stock_transactions ADD COLUMN IF NOT EXISTS item_code TEXT;
UPDATE stock_transactions SET item_code = items.item_code FROM items WHERE stock_transactions.item_id = items.id AND stock_transactions.item_code IS NULL;
ALTER TABLE stock_transactions ADD CONSTRAINT fk_stock_transactions_item_code FOREIGN KEY (item_code) REFERENCES items(item_code) ON UPDATE CASCADE;
