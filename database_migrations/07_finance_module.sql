-- =====================================================
-- SAP Finance & GRPO Module
-- Implements Moving Average Costing & Journal Entries
-- =====================================================

-- 1. Financial Schema (Chart of Accounts & Journal Entries)

CREATE TABLE IF NOT EXISTS chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) CHECK (account_type IN ('Asset', 'Liability', 'Equity', 'Revenue', 'Expense')),
    balance DECIMAL(15, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Default Accounts
INSERT INTO chart_of_accounts (code, name, account_type) VALUES
('10000', 'Inventory Account', 'Asset'),
('20000', 'Accounts Payable (Creditors)', 'Liability'),
('21000', 'Goods Received Not Invoiced (GRNI)', 'Liability'),
('50000', 'Cost of Goods Sold', 'Expense'),
('40000', 'Sales Revenue', 'Revenue')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS journal_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_date DATE NOT NULL,
    memo TEXT,
    ref_1 VARCHAR(50), -- External Ref
    ref_2 VARCHAR(50), -- Document Ref (e.g., GRN-1001)
    transaction_type VARCHAR(50), -- 'GRN', 'Invoice', etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS journal_entry_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    je_id UUID REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_id UUID REFERENCES chart_of_accounts(id),
    debit DECIMAL(15, 2) DEFAULT 0,
    credit DECIMAL(15, 2) DEFAULT 0,
    short_info TEXT, -- Remarks per line
    line_id INT
);

-- Note: We need a way to link Items/Warehouses to GL Accounts.
-- For simplicity in this MVP, we assume global default accounts.
-- In full SAP, this is done via "GL Account Determination" (OACT).

-- 2. Enhanced GRPO Processing Function (The Core Deliverable)

CREATE OR REPLACE FUNCTION process_goods_receipt_po(
    p_grn_header JSONB,
    p_grn_lines JSONB,
    p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_grn_id UUID;
    v_grn_doc_number VARCHAR;
    v_line RECORD;
    v_item RECORD;
    v_old_stock DECIMAL;
    v_old_cost DECIMAL;
    v_new_cost DECIMAL;
    v_total_stock DECIMAL;
    v_line_total DECIMAL;
    v_je_id UUID;
    v_inventory_acct UUID;
    v_grni_acct UUID;
    v_total_value DECIMAL := 0;
    v_doc_number_result JSONB;
BEGIN
    -- A. Generate Doc Number
    -- Currently calling rpc inside function is tricky if it modifies state, but safe here logic-wise if independent.
    -- Or we generate it before. Let's assume passed or generate internal?
    -- Better: Generate here.
    SELECT doc_number INTO v_grn_doc_number FROM goods_receipt_notes ORDER BY created_at DESC LIMIT 1;
    -- Simple increment for MVP (Production should use sequence)
    v_grn_doc_number := 'GRN-' || floor(random() * 100000)::text; 

    -- B. Insert Header
    INSERT INTO goods_receipt_notes (
        doc_number,
        supplier_id,
        warehouse_id,
        doc_date,
        due_date,
        ref_number,
        remarks,
        subtotal,
        total_amount,
        status,
        created_by,
        purchase_order_id
    ) VALUES (
        v_grn_doc_number,
        (p_grn_header->>'supplier_id')::UUID,
        (p_grn_header->>'warehouse_id')::UUID,
        (p_grn_header->>'doc_date')::DATE,
        (p_grn_header->>'due_date')::DATE,
        p_grn_header->>'ref_number',
        p_grn_header->>'remarks',
        (p_grn_header->>'subtotal')::DECIMAL,
        (p_grn_header->>'total_amount')::DECIMAL,
        'completed', -- GRN creates stock immediately in SAP
        p_user_id,
        (p_grn_header->>'purchase_order_id')::UUID
    ) RETURNING id INTO v_grn_id;

    -- C. Get Default Accounts
    SELECT id INTO v_inventory_acct FROM chart_of_accounts WHERE code = '10000';
    SELECT id INTO v_grni_acct FROM chart_of_accounts WHERE code = '21000';

    -- D. Process Lines & Calc Moving Average
    FOR v_line IN SELECT * FROM jsonb_to_recordset(p_grn_lines) AS x(
        item_id UUID,
        quantity DECIMAL,
        unit_cost DECIMAL,
        warehouse_id UUID,
        po_line_id UUID
    )
    LOOP
        v_line_total := v_line.quantity * v_line.unit_cost;
        v_total_value := v_total_value + v_line_total;

        -- 1. Fetch Current Item Data
        SELECT * INTO v_item FROM items WHERE id = v_line.item_id;
        
        -- Get current global stock for Moving Avg calc (SAP Standard uses Warehouse or Global depending on setting)
        -- Assuming Global for Item Master Cost
        SELECT COALESCE(SUM(quantity_on_hand), 0) INTO v_old_stock 
        FROM warehouse_stock WHERE item_id = v_line.item_id;
        
        v_old_cost := COALESCE(v_item.purchase_price, 0); -- Using purchase_price as avg cost proxy if avg_cost null
        
        -- 2. Calculate New Moving Average Cost
        -- Formula: ((OldQty * OldCost) + (NewQty * NewCost)) / (OldQty + NewQty)
        v_total_stock := v_old_stock + v_line.quantity;
        
        IF v_total_stock > 0 THEN
            v_new_cost := ((v_old_stock * v_old_cost) + (v_line.quantity * v_line.unit_cost)) / v_total_stock;
        ELSE
            v_new_cost := v_line.unit_cost;
        END IF;

        -- 3. Update Item Master (Cost)
        UPDATE items 
        SET purchase_price = v_new_cost -- Updating valuation price
        WHERE id = v_line.item_id;

        -- 4. Update Warehouse Stock (Qty)
        -- Check if record exists
        IF EXISTS (SELECT 1 FROM warehouse_stock WHERE item_id = v_line.item_id AND warehouse_id = v_line.warehouse_id) THEN
            UPDATE warehouse_stock
            SET quantity_on_hand = quantity_on_hand + v_line.quantity,
                average_cost = v_new_cost,
                quantity_ordered = GREATEST(0, quantity_ordered - v_line.quantity) -- Reduce ordered
            WHERE item_id = v_line.item_id AND warehouse_id = v_line.warehouse_id;
        ELSE
            INSERT INTO warehouse_stock (item_id, warehouse_id, quantity_on_hand, average_cost, quantity_ordered)
            VALUES (v_line.item_id, v_line.warehouse_id, v_line.quantity, v_new_cost, 0);
        END IF;

        -- 5. Insert GRN Line
        INSERT INTO grn_lines (grn_id, item_id, quantity, unit_cost, line_total, warehouse_id, po_line_id)
        VALUES (v_grn_id, v_line.item_id, v_line.quantity, v_line.unit_cost, v_line_total, v_line.warehouse_id, v_line.po_line_id);

        -- 6. Update PO Line Validation
        IF v_line.po_line_id IS NOT NULL THEN
             UPDATE po_lines 
             SET received_quantity = COALESCE(received_quantity, 0) + v_line.quantity,
                 open_quantity = GREATEST(0, quantity - (COALESCE(received_quantity, 0) + v_line.quantity))
             WHERE id = v_line.po_line_id;
        END IF;

    END LOOP;

    -- E. Create Journal Entry (Financial Integration)
    INSERT INTO journal_entries (doc_date, memo, ref_2, transaction_type, created_by)
    VALUES ((p_grn_header->>'doc_date')::DATE, 'GRPO - ' || (p_grn_header->>'remarks'), v_grn_doc_number, 'GRN', p_user_id)
    RETURNING id INTO v_je_id;

    -- Debit Inventory
    INSERT INTO journal_entry_lines (je_id, account_id, debit, credit)
    VALUES (v_je_id, v_inventory_acct, v_total_value, 0);

    -- Credit Allocation (GRNI)
    INSERT INTO journal_entry_lines (je_id, account_id, debit, credit)
    VALUES (v_je_id, v_grni_acct, 0, v_total_value);
    
    -- F. Close PO Logic
    -- Check if all lines in the referenced PO are closed (open_qty = 0)
    -- Logic: If NO lines exist with open_quantity > 0 for this PO, then close it.
    IF (p_grn_header->>'purchase_order_id') IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM po_lines 
            WHERE po_id = (p_grn_header->>'purchase_order_id')::UUID 
            AND open_quantity > 0
        ) THEN
            UPDATE purchase_orders SET status = 'closed' WHERE id = (p_grn_header->>'purchase_order_id')::UUID;
        ELSE
             -- Partial check?
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'grn_id', v_grn_id, 'doc_number', v_grn_doc_number);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;
