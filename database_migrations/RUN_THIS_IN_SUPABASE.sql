-- ⚡ COPY ALL OF THIS AND RUN IN SUPABASE SQL EDITOR ⚡
-- Link: https://supabase.com/dashboard/project/mvvuegptxjykhzpatsmn/sql/new

-- 1. Generate Document Numbers
CREATE OR REPLACE FUNCTION public.generate_doc_number(p_doc_type text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE result text;
BEGIN
    result := p_doc_type || '-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random()*1000)::text, 3, '0');
    RETURN result;
END;
$$;

-- 2. Generate Item Codes
CREATE OR REPLACE FUNCTION public.generate_next_item_code(p_prefix text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE result text;
BEGIN
    result := p_prefix || '-' || lpad(floor(random()*10000)::text, 4, '0');
    RETURN result;
END;
$$;

-- 3. Process GRN (Main Function)
CREATE OR REPLACE FUNCTION public.process_goods_receipt_po(
    p_grn_header json,
    p_grn_lines  json,
    p_user_id    uuid
) 
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    new_grn_id uuid;
    doc_number text;
    line_data json;
    po_line_uuid uuid;
    qty_received numeric;
    result json;
BEGIN
    doc_number := 'GRN-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random()*1000)::text, 3, '0');
    
    INSERT INTO goods_receipt_notes (
        doc_number, supplier_id, warehouse_id, purchase_order_id,
        doc_date, remarks, created_by, status
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

    FOR line_data IN SELECT * FROM json_array_elements(p_grn_lines)
    LOOP
        qty_received := (line_data->>'quantity')::numeric;
        po_line_uuid := NULLIF(line_data->>'po_line_id', '')::uuid;
        
        INSERT INTO grn_lines (
            grn_id, item_id, quantity, unit_cost, line_total, po_line_id, warehouse_id
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
        
        IF po_line_uuid IS NOT NULL THEN
            UPDATE po_lines
            SET received_quantity = COALESCE(received_quantity, 0) + qty_received,
                open_quantity = quantity - (COALESCE(received_quantity, 0) + qty_received)
            WHERE id = po_line_uuid;
        END IF;
    END LOOP;

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

    result := json_build_object('success', true, 'grn_id', new_grn_id, 'doc_number', doc_number);
    RETURN result;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error: %', SQLERRM;
    result := json_build_object('success', false, 'error', SQLERRM);
    RETURN result;
END;
$$;

-- 4. Grant Permissions
GRANT EXECUTE ON FUNCTION public.process_goods_receipt_po(json, json, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.generate_doc_number(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.generate_next_item_code(text) TO authenticated, anon;
