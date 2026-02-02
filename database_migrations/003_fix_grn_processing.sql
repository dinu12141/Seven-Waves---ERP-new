-- Migration: Fix GRN Processing and PO Tracking
-- Run this in Supabase SQL Editor

-- ============================================
-- 1. RPC: Generate Document Numbers
-- ============================================
CREATE OR REPLACE FUNCTION public.generate_doc_number(p_doc_type text)
RETURNS text 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
DECLARE
    result text;
BEGIN
    result := p_doc_type || '-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random()*1000)::text, 3, '0');
    RETURN result;
END;
$$;

-- ============================================
-- 2. RPC: Generate Item Codes
-- ============================================
CREATE OR REPLACE FUNCTION public.generate_next_item_code(p_prefix text)
RETURNS text 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
DECLARE
    result text;
BEGIN
    result := p_prefix || '-' || lpad(floor(random()*10000)::text, 4, '0');
    RETURN result;
END;
$$;

-- ============================================
-- 3. RPC: Process Goods Receipt PO
-- ============================================
CREATE OR REPLACE FUNCTION public.process_goods_receipt_po(
    p_grn_header json,
    p_grn_lines  json,
    p_user_id    uuid
) 
RETURNS json 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_grn_id uuid;
    doc_number text;
    line_data json;
    po_line_uuid uuid;
    qty_received numeric;
    result json;
BEGIN
    -- Generate document number first
    doc_number := 'GRN-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random()*1000)::text, 3, '0');
    
    -- Insert GRN header (note: field is purchase_order_id, not po_id!)
    INSERT INTO goods_receipt_notes (
        doc_number,
        supplier_id, 
        warehouse_id, 
        purchase_order_id,
        doc_date, 
        remarks, 
        created_by,
        status
    )
    VALUES (
        doc_number,
        (p_grn_header->>'supplier_id')::uuid,
        (p_grn_header->>'warehouse_id')::uuid,
        NULLIF(p_grn_header->>'po_id', '')::uuid,
        (p_grn_header->>'doc_date')::date,
        p_grn_header->>'remarks',
        p_user_id,
        'pending'
    )
    RETURNING id INTO new_grn_id;

    -- Insert GRN lines and update PO received quantities
    FOR line_data IN SELECT * FROM json_array_elements(p_grn_lines)
    LOOP
        -- Get quantity being received
        qty_received := (line_data->>'quantity')::numeric;
        po_line_uuid := NULLIF(line_data->>'po_line_id', '')::uuid;
        
        -- Insert GRN line
        INSERT INTO grn_lines (
            grn_id, 
            item_id, 
            quantity, 
            unit_cost, 
            line_total,
            po_line_id,
            warehouse_id
        )
        VALUES (
            new_grn_id,
            (line_data->>'item_id')::uuid,
            qty_received,
            (line_data->>'unit_cost')::numeric,
            (line_data->>'line_total')::numeric,
            po_line_uuid,
            (p_grn_header->>'warehouse_id')::uuid
        );
        
        -- Update PO line received_quantity
        IF po_line_uuid IS NOT NULL THEN
            UPDATE po_lines
            SET received_quantity = COALESCE(received_quantity, 0) + qty_received,
                open_quantity = quantity - (COALESCE(received_quantity, 0) + qty_received)
            WHERE id = po_line_uuid;
        END IF;
    END LOOP;

    -- Check if PO is fully received and update status
    IF (p_grn_header->>'po_id') IS NOT NULL AND (p_grn_header->>'po_id') != '' THEN
        UPDATE purchase_orders
        SET status = CASE
            WHEN NOT EXISTS (
                SELECT 1 FROM po_lines 
                WHERE po_id = (p_grn_header->>'po_id')::uuid 
                AND COALESCE(received_quantity, 0) < quantity
            ) THEN 'completed'
            ELSE status
        END
        WHERE id = (p_grn_header->>'po_id')::uuid;
    END IF;

    result := json_build_object(
        'success', true,
        'grn_id',  new_grn_id,
        'doc_number', doc_number
    );
    RETURN result;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in process_goods_receipt_po: %', SQLERRM;
    result := json_build_object(
        'success', false,
        'error',   SQLERRM
    );
    RETURN result;
END;
$$;

-- ============================================
-- 4. Grant Permissions
-- ============================================
GRANT EXECUTE ON FUNCTION public.process_goods_receipt_po(json, json, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_goods_receipt_po(json, json, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.generate_doc_number(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_doc_number(text) TO anon;
GRANT EXECUTE ON FUNCTION public.generate_next_item_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_next_item_code(text) TO anon;

-- ============================================
-- 5. Fix: Reset received quantities for testing
-- ============================================
-- Uncomment this if you want to reset all PO received quantities to zero for testing:
-- UPDATE po_lines SET received_quantity = 0, open_quantity = quantity;
-- UPDATE purchase_orders SET status = 'approved' WHERE status = 'completed';
