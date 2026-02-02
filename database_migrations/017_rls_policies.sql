-- =================================================================
-- SEVEN WAVES ERP - ENHANCED RLS POLICIES
-- Migration: 017_rls_policies.sql
-- =================================================================

-- =====================================================
-- 1. ITEMS TABLE - Role-Based Access
-- =====================================================

ALTER TABLE items ENABLE ROW LEVEL SECURITY;

-- Read: Anyone with items.read permission
DROP POLICY IF EXISTS items_read_policy ON items;
CREATE POLICY items_read_policy ON items
    FOR SELECT TO authenticated
    USING (
        has_permission(auth.uid(), 'items', 'read')
    );

-- Create: Only Z_INV_CLERK, Z_STOCK_MGR, Z_ALL
DROP POLICY IF EXISTS items_create_policy ON items;
CREATE POLICY items_create_policy ON items
    FOR INSERT TO authenticated
    WITH CHECK (
        has_permission(auth.uid(), 'items', 'create')
    );

-- Update: Only those with items.update permission
DROP POLICY IF EXISTS items_update_policy ON items;
CREATE POLICY items_update_policy ON items
    FOR UPDATE TO authenticated
    USING (
        has_permission(auth.uid(), 'items', 'update')
    );

-- Delete: Only admins
DROP POLICY IF EXISTS items_delete_policy ON items;
CREATE POLICY items_delete_policy ON items
    FOR DELETE TO authenticated
    USING (
        has_permission(auth.uid(), 'items', 'delete')
    );

-- =====================================================
-- 2. GOODS RECEIPT NOTES (GRN) - Role-Based Access
-- =====================================================

ALTER TABLE goods_receipt_notes ENABLE ROW LEVEL SECURITY;

-- Read: All stock-related roles
DROP POLICY IF EXISTS grn_read_policy ON goods_receipt_notes;
CREATE POLICY grn_read_policy ON goods_receipt_notes
    FOR SELECT TO authenticated
    USING (
        has_permission(auth.uid(), 'grn', 'read')
    );

-- Create: Inventory clerks and above
DROP POLICY IF EXISTS grn_create_policy ON goods_receipt_notes;
CREATE POLICY grn_create_policy ON goods_receipt_notes
    FOR INSERT TO authenticated
    WITH CHECK (
        has_permission(auth.uid(), 'grn', 'create')
    );

-- Update: Owner + managers (for approval workflow)
DROP POLICY IF EXISTS grn_update_policy ON goods_receipt_notes;
CREATE POLICY grn_update_policy ON goods_receipt_notes
    FOR UPDATE TO authenticated
    USING (
        created_by = auth.uid()
        OR has_permission(auth.uid(), 'grn', 'approve')
    );

-- =====================================================
-- 3. GRN LINES - Follow parent GRN access
-- =====================================================

ALTER TABLE grn_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS grn_lines_policy ON grn_lines;
CREATE POLICY grn_lines_policy ON grn_lines
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM goods_receipt_notes grn
            WHERE grn.id = grn_lines.grn_id
            AND (
                has_permission(auth.uid(), 'grn', 'read')
                OR grn.created_by = auth.uid()
            )
        )
    );

-- =====================================================
-- 4. PURCHASE ORDERS - Approval Workflow
-- =====================================================

ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;

-- Read: All stock-related roles
DROP POLICY IF EXISTS po_read_policy ON purchase_orders;
CREATE POLICY po_read_policy ON purchase_orders
    FOR SELECT TO authenticated
    USING (
        has_permission(auth.uid(), 'purchase_orders', 'read')
    );

-- Create: Inventory clerks and above
DROP POLICY IF EXISTS po_create_policy ON purchase_orders;
CREATE POLICY po_create_policy ON purchase_orders
    FOR INSERT TO authenticated
    WITH CHECK (
        has_permission(auth.uid(), 'purchase_orders', 'create')
    );

-- Update: Owner can update draft, managers can approve
DROP POLICY IF EXISTS po_update_policy ON purchase_orders;
CREATE POLICY po_update_policy ON purchase_orders
    FOR UPDATE TO authenticated
    USING (
        (created_by = auth.uid() AND status = 'draft')
        OR has_permission(auth.uid(), 'purchase_orders', 'approve')
    );

-- =====================================================
-- 5. PO LINES - Follow parent PO access
-- =====================================================

ALTER TABLE po_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS po_lines_policy ON po_lines;
CREATE POLICY po_lines_policy ON po_lines
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM purchase_orders po
            WHERE po.id = po_lines.po_id
            AND (
                has_permission(auth.uid(), 'purchase_orders', 'read')
                OR po.created_by = auth.uid()
            )
        )
    );

-- =====================================================
-- 6. WAREHOUSE STOCK - Warehouse Isolation
-- =====================================================

ALTER TABLE warehouse_stock ENABLE ROW LEVEL SECURITY;

-- Users can only see stock from their assigned warehouses
DROP POLICY IF EXISTS warehouse_stock_isolation_policy ON warehouse_stock;
CREATE POLICY warehouse_stock_isolation_policy ON warehouse_stock
    FOR SELECT TO authenticated
    USING (
        -- Admins see all
        EXISTS (
            SELECT 1 FROM user_roles ur
            INNER JOIN roles r ON r.id = ur.role_id
            WHERE ur.user_id = auth.uid() 
            AND r.code = 'Z_ALL' 
            AND ur.is_active = true
        )
        OR
        -- Others see only assigned warehouses
        EXISTS (
            SELECT 1 FROM user_warehouse_access uwa
            WHERE uwa.user_id = auth.uid()
            AND uwa.warehouse_id = warehouse_stock.warehouse_id
        )
        OR
        -- Stock managers see all (for reports)
        has_permission(auth.uid(), 'reports', 'inventory')
    );

-- Write access based on warehouse assignment
DROP POLICY IF EXISTS warehouse_stock_write_policy ON warehouse_stock;
CREATE POLICY warehouse_stock_write_policy ON warehouse_stock
    FOR ALL TO authenticated
    USING (
        has_permission(auth.uid(), 'stock', 'adjust')
        AND (
            -- Admins can adjust all
            EXISTS (
                SELECT 1 FROM user_roles ur
                INNER JOIN roles r ON r.id = ur.role_id
                WHERE ur.user_id = auth.uid() 
                AND r.code = 'Z_ALL' 
                AND ur.is_active = true
            )
            OR
            -- Others only assigned warehouses with write access
            EXISTS (
                SELECT 1 FROM user_warehouse_access uwa
                WHERE uwa.user_id = auth.uid()
                AND uwa.warehouse_id = warehouse_stock.warehouse_id
                AND uwa.access_level IN ('write', 'full')
            )
        )
    );

-- =====================================================
-- 7. STOCK TRANSACTIONS - Warehouse Isolation
-- =====================================================

ALTER TABLE stock_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stock_transactions_policy ON stock_transactions;
CREATE POLICY stock_transactions_policy ON stock_transactions
    FOR SELECT TO authenticated
    USING (
        -- Admins see all
        EXISTS (
            SELECT 1 FROM user_roles ur
            INNER JOIN roles r ON r.id = ur.role_id
            WHERE ur.user_id = auth.uid() 
            AND r.code = 'Z_ALL' 
            AND ur.is_active = true
        )
        OR
        -- Others see only assigned warehouses
        EXISTS (
            SELECT 1 FROM user_warehouse_access uwa
            WHERE uwa.user_id = auth.uid()
            AND uwa.warehouse_id = stock_transactions.warehouse_id
        )
        OR
        has_permission(auth.uid(), 'reports', 'inventory')
    );

-- =====================================================
-- 8. SUPPLIERS - Standard Access
-- =====================================================

ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS suppliers_read_policy ON suppliers;
CREATE POLICY suppliers_read_policy ON suppliers
    FOR SELECT TO authenticated
    USING (
        has_permission(auth.uid(), 'purchase_orders', 'read')
        OR has_permission(auth.uid(), 'grn', 'read')
    );

DROP POLICY IF EXISTS suppliers_write_policy ON suppliers;
CREATE POLICY suppliers_write_policy ON suppliers
    FOR ALL TO authenticated
    USING (
        has_permission(auth.uid(), 'items', 'create')
    );

-- =====================================================
-- 9. WAREHOUSES - Standard Access
-- =====================================================

ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS warehouses_read_policy ON warehouses;
CREATE POLICY warehouses_read_policy ON warehouses
    FOR SELECT TO authenticated
    USING (
        has_permission(auth.uid(), 'warehouses', 'read')
        OR has_permission(auth.uid(), 'stock', 'view')
    );

DROP POLICY IF EXISTS warehouses_write_policy ON warehouses;
CREATE POLICY warehouses_write_policy ON warehouses
    FOR ALL TO authenticated
    USING (
        has_permission(auth.uid(), 'warehouses', 'create')
        OR has_permission(auth.uid(), 'warehouses', 'update')
    );

-- =====================================================
-- 10. PROFILES - Self + Admin Access
-- =====================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_read_policy ON profiles;
CREATE POLICY profiles_read_policy ON profiles
    FOR SELECT TO authenticated
    USING (true); -- Everyone can read profiles

DROP POLICY IF EXISTS profiles_write_policy ON profiles;
CREATE POLICY profiles_write_policy ON profiles
    FOR UPDATE TO authenticated
    USING (
        id = auth.uid()
        OR has_permission(auth.uid(), 'users', 'manage')
    );

DROP POLICY IF EXISTS profiles_insert_policy ON profiles;
CREATE POLICY profiles_insert_policy ON profiles
    FOR INSERT TO authenticated
    WITH CHECK (
        id = auth.uid()
        OR has_permission(auth.uid(), 'users', 'manage')
    );

-- =====================================================
-- 11. UNITS OF MEASURE - Standard Access
-- =====================================================

ALTER TABLE units_of_measure ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS uom_read_policy ON units_of_measure;
CREATE POLICY uom_read_policy ON units_of_measure
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS uom_write_policy ON units_of_measure;
CREATE POLICY uom_write_policy ON units_of_measure
    FOR ALL TO authenticated
    USING (
        has_permission(auth.uid(), 'items', 'create')
    );

-- =====================================================
-- 12. ITEM CATEGORIES - Standard Access
-- =====================================================

ALTER TABLE item_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS categories_read_policy ON item_categories;
CREATE POLICY categories_read_policy ON item_categories
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS categories_write_policy ON item_categories;
CREATE POLICY categories_write_policy ON item_categories
    FOR ALL TO authenticated
    USING (
        has_permission(auth.uid(), 'items', 'create')
    );

-- =====================================================
-- 13. PENDING APPROVALS VIEW
-- =====================================================

CREATE OR REPLACE VIEW pending_approvals AS
SELECT 
    'purchase_order' AS doc_type,
    po.id,
    po.doc_number,
    'Purchase Order' AS description,
    po.total_amount AS amount,
    p.full_name AS requested_by,
    po.created_at AS requested_at,
    po.status
FROM purchase_orders po
LEFT JOIN profiles p ON p.id = po.created_by
WHERE po.status = 'pending'

UNION ALL

SELECT 
    'grn' AS doc_type,
    grn.id,
    grn.doc_number,
    'Goods Receipt Note' AS description,
    grn.total_amount AS amount,
    p.full_name AS requested_by,
    grn.created_at AS requested_at,
    grn.status
FROM goods_receipt_notes grn
LEFT JOIN profiles p ON p.id = grn.created_by
WHERE grn.status = 'draft'

UNION ALL

SELECT 
    'leave_application' AS doc_type,
    la.id,
    la.doc_number,
    'Leave Application - ' || lt.name AS description,
    la.total_leave_days::DECIMAL AS amount,
    e.full_name AS requested_by,
    la.created_at AS requested_at,
    la.status
FROM leave_applications la
LEFT JOIN employees e ON e.id = la.employee_id
LEFT JOIN leave_types lt ON lt.id = la.leave_type_id
WHERE la.status IN ('Pending HR Officer', 'Pending HR Manager')

ORDER BY requested_at DESC;

-- Grant access to the view
GRANT SELECT ON pending_approvals TO authenticated;

-- =====================================================
-- 14. APPROVE DOCUMENT RPC
-- =====================================================

CREATE OR REPLACE FUNCTION approve_document(
    p_doc_type VARCHAR,
    p_doc_id UUID,
    p_action VARCHAR DEFAULT 'approve'
)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    -- Check if user has approval permission
    IF p_doc_type = 'purchase_order' THEN
        IF NOT has_permission(auth.uid(), 'purchase_orders', 'approve') THEN
            RETURN jsonb_build_object('success', false, 'error', 'No approval permission');
        END IF;
        
        IF p_action = 'approve' THEN
            UPDATE purchase_orders 
            SET status = 'approved', 
                approved_by = auth.uid(), 
                approved_at = NOW(),
                updated_at = NOW()
            WHERE id = p_doc_id AND status = 'pending';
        ELSE
            UPDATE purchase_orders 
            SET status = 'cancelled', 
                updated_at = NOW()
            WHERE id = p_doc_id AND status = 'pending';
        END IF;
        
    ELSIF p_doc_type = 'grn' THEN
        IF NOT has_permission(auth.uid(), 'grn', 'approve') THEN
            RETURN jsonb_build_object('success', false, 'error', 'No approval permission');
        END IF;
        
        IF p_action = 'approve' THEN
            UPDATE goods_receipt_notes 
            SET status = 'approved', 
                approved_by = auth.uid(), 
                approved_at = NOW(),
                updated_at = NOW()
            WHERE id = p_doc_id AND status = 'draft';
        ELSE
            UPDATE goods_receipt_notes 
            SET status = 'cancelled', 
                updated_at = NOW()
            WHERE id = p_doc_id AND status = 'draft';
        END IF;
        
    ELSIF p_doc_type = 'leave_application' THEN
        IF NOT has_permission(auth.uid(), 'leaves', 'approve') THEN
            RETURN jsonb_build_object('success', false, 'error', 'No approval permission');
        END IF;
        
        IF p_action = 'approve' THEN
            -- Check current status for 2-tier approval
            UPDATE leave_applications 
            SET status = CASE 
                    WHEN status = 'Pending HR Officer' THEN 'Pending HR Manager'
                    WHEN status = 'Pending HR Manager' THEN 'Approved'
                    ELSE status
                END,
                hr_officer_id = CASE WHEN status = 'Pending HR Officer' THEN auth.uid() ELSE hr_officer_id END,
                hr_officer_approved_at = CASE WHEN status = 'Pending HR Officer' THEN NOW() ELSE hr_officer_approved_at END,
                hr_manager_id = CASE WHEN status = 'Pending HR Manager' THEN auth.uid() ELSE hr_manager_id END,
                hr_manager_approved_at = CASE WHEN status = 'Pending HR Manager' THEN NOW() ELSE hr_manager_approved_at END
            WHERE id = p_doc_id;
        ELSE
            UPDATE leave_applications 
            SET status = 'Rejected'
            WHERE id = p_doc_id;
        END IF;
    END IF;
    
    RETURN jsonb_build_object('success', true, 'doc_type', p_doc_type, 'doc_id', p_doc_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION approve_document TO authenticated;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ Enhanced RLS Policies installed successfully!';
    RAISE NOTICE '🔒 Tables secured: items, grn, purchase_orders, warehouse_stock, suppliers, warehouses, profiles';
    RAISE NOTICE '🏭 Warehouse isolation enabled for stock tables';
    RAISE NOTICE '📋 pending_approvals view created for managers';
    RAISE NOTICE '✔️ approve_document RPC function created';
END $$;
