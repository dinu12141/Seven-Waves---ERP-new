# Database Migration Instructions

## Seven Waves ERP - Stock Module Expansion

This folder contains SQL migration scripts for the new Stock Module features. These scripts must be executed in order on your Supabase database.

### Prerequisites

- Supabase project set up
- Database access credentials
- Supabase CLI (optional but recommended)

### Migration Files

1. **01_recipes_module.sql**
   - Creates `recipes` table (header)
   - Creates `recipe_lines` table (ingredients)
   - Adds indexes and constraints

2. **02_stock_transfers.sql**
   - Creates `stock_transfers` table (header)
   - Creates `stock_transfer_lines` table
   - Adds warehouse validation constraints

3. **03_item_enhancements.sql**
   - Adds `is_inventory_item` column to `items` table
   - Updates existing items

4. **04_stock_transfer_triggers.sql**
   - Creates trigger function `handle_stock_transfer_complete()`
   - Automatically updates warehouse_stock when transfers are completed
   - Creates stock transaction audit records

### Execution Methods

#### Option 1: Supabase Dashboard (Recommended for beginners)

1. Log in to your Supabase Dashboard (https://app.supabase.com)
2. Navigate to your project
3. Go to **SQL Editor** in the left sidebar
4. Create a new query
5. Copy and paste the contents of `01_recipes_module.sql`
6. Click **Run**
7. Repeat steps 4-6 for each migration file in order

#### Option 2: Supabase CLI

```bash
# Navigate to the database_migrations folder
cd "c:\Users\samsung\Desktop\Seven Waves-ERP\database_migrations"

# Execute each migration in order
supabase db execute --file 01_recipes_module.sql
supabase db execute --file 02_stock_transfers.sql
supabase db execute --file 03_item_enhancements.sql
supabase db execute --file 04_stock_transfer_triggers.sql
```

#### Option 3: Direct psql connection

```bash
# Connect to your Supabase database
psql "postgresql://<user>:<password>@<host>:<port>/<database>?sslmode=require"

# Execute each file
\i 01_recipes_module.sql
\i 02_stock_transfers.sql
\i 03_item_enhancements.sql
\i 04_stock_transfer_triggers.sql
```

### Verification

After running all migrations, verify the tables were created:

```sql
-- Check recipes table
SELECT * FROM recipes LIMIT 1;

-- Check stock_transfers table
SELECT * FROM stock_transfers LIMIT 1;

-- Check items table for new column
SELECT item_code, is_inventory_item, is_sales_item, is_purchase_item
FROM items LIMIT 5;

-- Verify trigger exists
SELECT tgname FROM pg_trigger WHERE tgname = 'trigger_stock_transfer_complete';
```

### Required RPC Functions

The migrations use a `generate_doc_number()` RPC function. If this doesn't exist in your database, create it:

```sql
CREATE OR REPLACE FUNCTION generate_doc_number(p_doc_type VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
  v_prefix VARCHAR;
  v_count INT;
  v_doc_number VARCHAR;
BEGIN
  -- Set prefix based on document type
  CASE p_doc_type
    WHEN 'RCP' THEN v_prefix := 'RCP';
    WHEN 'STR' THEN v_prefix := 'STR';
    ELSE v_prefix := 'DOC';
  END CASE;

  -- Get count for this type (this is a simple incrementor, customize as needed)
  SELECT COUNT(*) + 1 INTO v_count
  FROM (
    SELECT 1 FROM recipes WHERE recipe_code LIKE v_prefix || '%'
    UNION ALL
    SELECT 1 FROM stock_transfers WHERE doc_number LIKE v_prefix || '%'
  ) t;

  -- Generate document number
  v_doc_number := v_prefix || '-' || LPAD(v_count::TEXT, 6, '0');

  RETURN v_doc_number;
END;
$$ LANGUAGE plpgsql;
```

### Rollback (if needed)

If you need to rollback the migrations:

```sql
-- Drop triggers
DROP TRIGGER IF EXISTS trigger_stock_transfer_complete ON stock_transfers;
DROP FUNCTION IF EXISTS handle_stock_transfer_complete();

-- Drop tables (careful - this will delete data!)
DROP TABLE IF EXISTS recipe_lines CASCADE;
DROP TABLE IF EXISTS recipes CASCADE;
DROP TABLE IF EXISTS stock_transfer_lines CASCADE;
DROP TABLE IF EXISTS stock_transfers CASCADE;

-- Remove column from items
ALTER TABLE items DROP COLUMN IF EXISTS is_inventory_item;
```

### Troubleshooting

**Error: relation "warehouses" does not exist**

- Ensure your existing ERP tables are set up first
- Check that `items`, `warehouses`, `units_of_measure`, and `auth.users` tables exist

**Error: column "is_inventory_item" is duplicated**

- The column may already exist, you can skip `03_item_enhancements.sql`

**Permission denied error**

- Make sure your database user has CREATE and TRIGGER privileges

### Next Steps

After successful migration:

1. Update your route configuration to include the new pages
2. Test the new functionality in the UI
3. Create test data for recipes and stock transfers

For support, refer to the implementation_plan.md document.
