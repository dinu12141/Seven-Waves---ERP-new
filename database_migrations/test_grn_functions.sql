-- Test Script: Verify GRN Functions
-- Run this in Supabase SQL Editor to verify everything is set up correctly

-- 1. Check if all functions exist
SELECT 
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type,
    proacl as permissions
FROM pg_proc 
WHERE proname IN ('process_goods_receipt_po', 'generate_doc_number', 'generate_next_item_code')
ORDER BY proname;

-- 2. Test document number generation
SELECT generate_doc_number('GRN') as grn_doc_number;
SELECT generate_doc_number('PO') as po_doc_number;

-- 3. Test item code generation
SELECT generate_next_item_code('ITEM') as item_code;

-- 4. Check existing GRNs
SELECT 
    grn.id,
    grn.doc_number,
    grn.status,
    grn.doc_date,
    s.name as supplier_name,
    po.doc_number as po_reference,
    COUNT(gl.id) as line_count
FROM goods_receipt_notes grn
LEFT JOIN suppliers s ON s.id = grn.supplier_id
LEFT JOIN purchase_orders po ON po.id = grn.po_id
LEFT JOIN grn_lines gl ON gl.grn_id = grn.id
GROUP BY grn.id, grn.doc_number, grn.status, grn.doc_date, s.name, po.doc_number
ORDER BY grn.created_at DESC
LIMIT 10;

-- 5. Check POs with received quantities
SELECT 
    po.doc_number,
    po.status,
    pol.line_num,
    i.item_name,
    pol.quantity as ordered_qty,
    pol.received_quantity,
    (pol.quantity - COALESCE(pol.received_quantity, 0)) as remaining_qty
FROM purchase_orders po
JOIN po_lines pol ON pol.po_id = po.id
JOIN items i ON i.id = pol.item_id
WHERE po.status = 'approved'
ORDER BY po.created_at DESC, pol.line_num;
