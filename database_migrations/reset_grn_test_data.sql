-- Reset Script: Clear GRN data and reset PO received quantities
-- Use this to test the GRN flow from scratch

-- 1. Delete all GRNs (this will cascade delete grn_lines)
DELETE FROM goods_receipt_notes;

-- 2. Reset all PO lines to zero received
UPDATE po_lines 
SET received_quantity = 0, 
    open_quantity = quantity;

-- 3. Reset PO status back to approved
UPDATE purchase_orders 
SET status = 'approved' 
WHERE status = 'completed';

-- 4. Verify the reset
SELECT 
    po.doc_number,
    po.status,
    COUNT(pol.id) as total_lines,
    SUM(CASE WHEN COALESCE(pol.received_quantity, 0) < pol.quantity THEN 1 ELSE 0 END) as open_lines
FROM purchase_orders po
LEFT JOIN po_lines pol ON pol.po_id = po.id
WHERE po.status = 'approved'
GROUP BY po.id, po.doc_number, po.status
ORDER BY po.doc_number;
