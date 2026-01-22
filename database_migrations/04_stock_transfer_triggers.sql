-- =====================================================
-- Stock Transfer Triggers
-- Automatically update warehouse_stock when transfer is completed
-- =====================================================

-- Function to handle stock transfer completion
CREATE OR REPLACE FUNCTION handle_stock_transfer_complete()
RETURNS TRIGGER AS $$
DECLARE
  line_record RECORD;
  from_stock_record RECORD;
  to_stock_record RECORD;
BEGIN
  -- Only process if status changed to 'completed'
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    
    -- Loop through all transfer lines
    FOR line_record IN 
      SELECT * FROM stock_transfer_lines WHERE transfer_id = NEW.id
    LOOP
      
      -- 1. Deduct from source warehouse
      SELECT * INTO from_stock_record 
      FROM warehouse_stock 
      WHERE item_id = line_record.item_id 
        AND warehouse_id = NEW.from_warehouse_id;
      
      IF FOUND THEN
        -- Update existing stock
        UPDATE warehouse_stock 
        SET 
          quantity_on_hand = quantity_on_hand - line_record.quantity,
          updated_at = NOW()
        WHERE item_id = line_record.item_id 
          AND warehouse_id = NEW.from_warehouse_id;
      ELSE
        RAISE EXCEPTION 'Insufficient stock for item % in warehouse %', 
          line_record.item_id, NEW.from_warehouse_id;
      END IF;
      
      -- 2. Add to destination warehouse
      SELECT * INTO to_stock_record 
      FROM warehouse_stock 
      WHERE item_id = line_record.item_id 
        AND warehouse_id = NEW.to_warehouse_id;
      
      IF FOUND THEN
        -- Update existing stock
        UPDATE warehouse_stock 
        SET 
          quantity_on_hand = quantity_on_hand + line_record.quantity,
          updated_at = NOW()
        WHERE item_id = line_record.item_id 
          AND warehouse_id = NEW.to_warehouse_id;
      ELSE
        -- Create new stock record
        INSERT INTO warehouse_stock (
          item_id, 
          warehouse_id, 
          quantity_on_hand, 
          average_cost
        ) VALUES (
          line_record.item_id,
          NEW.to_warehouse_id,
          line_record.quantity,
          line_record.unit_cost
        );
      END IF;
      
      -- 3. Create stock transaction records
      -- Deduction from source
      INSERT INTO stock_transactions (
        item_id,
        warehouse_id,
        transaction_type,
        transaction_date,
        quantity,
        doc_type,
        doc_number,
        notes,
        created_by
      ) VALUES (
        line_record.item_id,
        NEW.from_warehouse_id,
        'transfer_out',
        NEW.transfer_date,
        -line_record.quantity,
        'TRANSFER',
        NEW.doc_number,
        'Stock transfer to ' || (SELECT name FROM warehouses WHERE id = NEW.to_warehouse_id),
        NEW.approved_by
      );
      
      -- Addition to destination
      INSERT INTO stock_transactions (
        item_id,
        warehouse_id,
        transaction_type,
        transaction_date,
        quantity,
        doc_type,
        doc_number,
        notes,
        created_by
      ) VALUES (
        line_record.item_id,
        NEW.to_warehouse_id,
        'transfer_in',
        NEW.transfer_date,
        line_record.quantity,
        'TRANSFER',
        NEW.doc_number,
        'Stock transfer from ' || (SELECT name FROM warehouses WHERE id = NEW.from_warehouse_id),
        NEW.approved_by
      );
      
    END LOOP;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_stock_transfer_complete ON stock_transfers;
CREATE TRIGGER trigger_stock_transfer_complete
  AFTER UPDATE ON stock_transfers
  FOR EACH ROW
  EXECUTE FUNCTION handle_stock_transfer_complete();

COMMENT ON FUNCTION handle_stock_transfer_complete() IS 'Automatically updates warehouse stock when a stock transfer is completed';
