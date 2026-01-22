-- =====================================================
-- Recipe/BOM Module - Database Schema
-- Seven Waves ERP - Stock Module Expansion
-- =====================================================

-- Create recipes table (header)
CREATE TABLE IF NOT EXISTS recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_code VARCHAR(50) UNIQUE NOT NULL,
  sales_item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  target_warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  recipe_name VARCHAR(255) NOT NULL,
  description TEXT,
  yield_quantity DECIMAL(15, 4) DEFAULT 1,
  yield_uom_id UUID REFERENCES units_of_measure(id),
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_recipes_sales_item ON recipes(sales_item_id);
CREATE INDEX IF NOT EXISTS idx_recipes_warehouse ON recipes(target_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_recipes_active ON recipes(is_active);

-- Create recipe_lines table (ingredients)
CREATE TABLE IF NOT EXISTS recipe_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  line_num INT NOT NULL,
  item_id UUID NOT NULL REFERENCES items(id),
  quantity DECIMAL(15, 4) NOT NULL CHECK (quantity > 0),
  uom_id UUID NOT NULL REFERENCES units_of_measure(id),
  unit_cost DECIMAL(15, 4) DEFAULT 0,
  line_total DECIMAL(15, 4) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(recipe_id, line_num)
);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_recipe_lines_recipe ON recipe_lines(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_lines_item ON recipe_lines(item_id);

-- Add comment descriptions
COMMENT ON TABLE recipes IS 'SAP B1 HANA Recipe/Bill of Materials header table';
COMMENT ON TABLE recipe_lines IS 'SAP B1 HANA Recipe/BOM ingredient lines';
COMMENT ON COLUMN recipes.target_warehouse_id IS 'Warehouse where this recipe is produced (K1 or K2)';
COMMENT ON COLUMN recipes.yield_quantity IS 'Output quantity from this recipe';
COMMENT ON COLUMN recipe_lines.line_num IS 'Line sequence number within recipe';
COMMENT ON COLUMN recipe_lines.unit_cost IS 'Cost per unit at time of recipe creation';
COMMENT ON COLUMN recipe_lines.line_total IS 'Calculated as quantity * unit_cost';
