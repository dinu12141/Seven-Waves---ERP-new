-- =====================================================
-- Stock Transfer Module - Database Schema
-- Seven Waves ERP - Warehouse Transfer Functionality
-- =====================================================

-- Create stock_transfers table (header)
CREATE TABLE IF NOT EXISTS stock_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_number VARCHAR(50) UNIQUE NOT NULL,
  transfer_date DATE NOT NULL DEFAULT CURRENT_DATE,
  from_warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  to_warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'completed', 'cancelled')),
  total_cost DECIMAL(15, 4) DEFAULT 0,
  notes TEXT,
  created_by UUID REFERENCES auth.users(id),
  approved_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT different_warehouses CHECK (from_warehouse_id != to_warehouse_id)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_stock_transfers_from_warehouse ON stock_transfers(from_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_to_warehouse ON stock_transfers(to_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_status ON stock_transfers(status);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_date ON stock_transfers(transfer_date);

-- Create stock_transfer_lines table
CREATE TABLE IF NOT EXISTS stock_transfer_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id UUID NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
  line_num INT NOT NULL,
  item_id UUID NOT NULL REFERENCES items(id),
  item_description VARCHAR(255),
  quantity DECIMAL(15, 4) NOT NULL CHECK (quantity > 0),
  uom_id UUID NOT NULL REFERENCES units_of_measure(id),
  unit_cost DECIMAL(15, 4) DEFAULT 0,
  line_total DECIMAL(15, 4) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(transfer_id, line_num)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_stock_transfer_lines_transfer ON stock_transfer_lines(transfer_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfer_lines_item ON stock_transfer_lines(item_id);

-- Add comment descriptions
COMMENT ON TABLE stock_transfers IS 'SAP B1 HANA Stock Transfer documents (warehouse to warehouse)';
COMMENT ON TABLE stock_transfer_lines IS 'Stock Transfer line items';
COMMENT ON COLUMN stock_transfers.status IS 'draft: not yet executed, completed: stock moved, cancelled: voided';
COMMENT ON CONSTRAINT different_warehouses ON stock_transfers IS 'Cannot transfer to same warehouse';
