-- =====================================================
-- Item Master Enhancements
-- Add is_inventory_item flag
-- =====================================================

-- Add is_inventory_item column to items table
ALTER TABLE items 
ADD COLUMN IF NOT EXISTS is_inventory_item BOOLEAN DEFAULT true;

-- Update existing items to have is_inventory_item = true
UPDATE items SET is_inventory_item = true WHERE is_inventory_item IS NULL;

-- Add comment
COMMENT ON COLUMN items.is_inventory_item IS 'Indicates if this item is tracked in inventory (SAP B1 HANA Item Type)';
