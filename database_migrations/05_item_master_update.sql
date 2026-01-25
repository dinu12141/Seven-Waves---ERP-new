-- =====================================================
-- Item Master Data Enhancements (SAP HANA Style)
-- =====================================================

-- Add SAP OITM columns to items table
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS foreign_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS item_type VARCHAR(20) DEFAULT 'Items' CHECK (item_type IN ('Items', 'Labor', 'Travel')),
ADD COLUMN IF NOT EXISTS valuation_method VARCHAR(20) DEFAULT 'Moving Average' CHECK (valuation_method IN ('Moving Average', 'Standard', 'FIFO')),
ADD COLUMN IF NOT EXISTS procurement_method VARCHAR(10) DEFAULT 'Buy' CHECK (procurement_method IN ('Buy', 'Make')),
ADD COLUMN IF NOT EXISTS barcode VARCHAR(50),
ADD COLUMN IF NOT EXISTS gl_account_code VARCHAR(50),
ADD COLUMN IF NOT EXISTS tax_group_id UUID, -- Placeholder for Tax Group link
ADD COLUMN IF NOT EXISTS uom_group_id UUID, -- Placeholder for UoM Group
ADD COLUMN IF NOT EXISTS manufacturer VARCHAR(100),
ADD COLUMN IF NOT EXISTS shipping_type VARCHAR(50),
ADD COLUMN IF NOT EXISTS manage_serial_numbers BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS manage_batch_numbers BOOLEAN DEFAULT false;

-- Add comments for documentation
COMMENT ON COLUMN items.item_type IS 'Items (Material), Labor, or Travel';
COMMENT ON COLUMN items.valuation_method IS 'Moving Average, Standard, or FIFO';
COMMENT ON COLUMN items.procurement_method IS 'Buy or Make';
COMMENT ON COLUMN items.gl_account_code IS 'Link to Chart of Accounts';

-- Ensure existing columns match requirements (renaming or aliasing if needed in UI)
-- default_supplier_id serves as "Primary Vendor"

-- Add index for barcode which is often searched
CREATE INDEX IF NOT EXISTS idx_items_barcode ON items(barcode);
