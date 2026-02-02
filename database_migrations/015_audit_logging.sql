-- =================================================================
-- SEVEN WAVES ERP - AUDIT LOGGING (SAP CDHDR/CDPOS Style)
-- Migration: 015_audit_logging.sql
-- =================================================================

-- =====================================================
-- 1. CHANGE LOG TABLE (SAP CDHDR - Change Header)
-- =====================================================

CREATE TABLE IF NOT EXISTS change_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Document Reference
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    doc_number VARCHAR(100),
    
    -- Change Type
    change_type VARCHAR(20) NOT NULL CHECK (change_type IN ('INSERT', 'UPDATE', 'DELETE')),
    
    -- Change Details (JSON for flexibility)
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[], -- Array of field names that changed
    
    -- Who & When
    changed_by UUID REFERENCES auth.users(id),
    changed_by_name TEXT,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Context
    transaction_id TEXT,
    client_ip INET,
    user_agent TEXT,
    
    -- Indexed search
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. INDEXES FOR CHANGE LOG
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_change_log_table ON change_log(table_name);
CREATE INDEX IF NOT EXISTS idx_change_log_record ON change_log(record_id);
CREATE INDEX IF NOT EXISTS idx_change_log_doc ON change_log(doc_number);
CREATE INDEX IF NOT EXISTS idx_change_log_changed_by ON change_log(changed_by);
CREATE INDEX IF NOT EXISTS idx_change_log_changed_at ON change_log(changed_at);
CREATE INDEX IF NOT EXISTS idx_change_log_table_record ON change_log(table_name, record_id);

-- =====================================================
-- 3. AUDIT TRIGGER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    changed_fields_arr TEXT[];
    old_json JSONB;
    new_json JSONB;
    user_name TEXT;
    doc_num TEXT;
    key_field TEXT;
BEGIN
    -- Get user name
    SELECT COALESCE(full_name, email) INTO user_name
    FROM profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    WHERE p.id = auth.uid();
    
    IF user_name IS NULL THEN
        user_name := 'System';
    END IF;
    
    -- Determine doc_number field based on table
    CASE TG_TABLE_NAME
        WHEN 'items' THEN key_field := 'item_code';
        WHEN 'purchase_orders' THEN key_field := 'doc_number';
        WHEN 'goods_receipt_notes' THEN key_field := 'doc_number';
        WHEN 'goods_issue_notes' THEN key_field := 'doc_number';
        WHEN 'employees' THEN key_field := 'employee_code';
        WHEN 'suppliers' THEN key_field := 'code';
        WHEN 'warehouses' THEN key_field := 'code';
        ELSE key_field := NULL;
    END CASE;
    
    IF TG_OP = 'INSERT' THEN
        new_json := to_jsonb(NEW);
        
        -- Get doc_number from new record
        IF key_field IS NOT NULL THEN
            doc_num := new_json->>key_field;
        END IF;
        
        INSERT INTO change_log (
            table_name, record_id, doc_number, change_type,
            old_values, new_values, changed_fields,
            changed_by, changed_by_name
        ) VALUES (
            TG_TABLE_NAME, NEW.id, doc_num, 'INSERT',
            NULL, new_json, NULL,
            auth.uid(), user_name
        );
        RETURN NEW;
        
    ELSIF TG_OP = 'UPDATE' THEN
        old_json := to_jsonb(OLD);
        new_json := to_jsonb(NEW);
        
        -- Get doc_number from new record
        IF key_field IS NOT NULL THEN
            doc_num := new_json->>key_field;
        END IF;
        
        -- Find changed fields
        SELECT array_agg(key) INTO changed_fields_arr
        FROM (
            SELECT key
            FROM jsonb_each(old_json) old_kv
            FULL OUTER JOIN jsonb_each(new_json) new_kv USING (key)
            WHERE old_kv.value IS DISTINCT FROM new_kv.value
            AND key NOT IN ('updated_at', 'created_at')
        ) changes;
        
        -- Only log if something actually changed
        IF changed_fields_arr IS NOT NULL AND array_length(changed_fields_arr, 1) > 0 THEN
            INSERT INTO change_log (
                table_name, record_id, doc_number, change_type,
                old_values, new_values, changed_fields,
                changed_by, changed_by_name
            ) VALUES (
                TG_TABLE_NAME, NEW.id, doc_num, 'UPDATE',
                old_json, new_json, changed_fields_arr,
                auth.uid(), user_name
            );
        END IF;
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        old_json := to_jsonb(OLD);
        
        -- Get doc_number from old record
        IF key_field IS NOT NULL THEN
            doc_num := old_json->>key_field;
        END IF;
        
        INSERT INTO change_log (
            table_name, record_id, doc_number, change_type,
            old_values, new_values, changed_fields,
            changed_by, changed_by_name
        ) VALUES (
            TG_TABLE_NAME, OLD.id, doc_num, 'DELETE',
            old_json, NULL, NULL,
            auth.uid(), user_name
        );
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. ATTACH AUDIT TRIGGERS TO KEY TABLES
-- =====================================================

-- Items table
DROP TRIGGER IF EXISTS audit_items ON items;
CREATE TRIGGER audit_items
    AFTER INSERT OR UPDATE OR DELETE ON items
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Purchase Orders
DROP TRIGGER IF EXISTS audit_purchase_orders ON purchase_orders;
CREATE TRIGGER audit_purchase_orders
    AFTER INSERT OR UPDATE OR DELETE ON purchase_orders
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Goods Receipt Notes
DROP TRIGGER IF EXISTS audit_goods_receipt_notes ON goods_receipt_notes;
CREATE TRIGGER audit_goods_receipt_notes
    AFTER INSERT OR UPDATE OR DELETE ON goods_receipt_notes
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Employees
DROP TRIGGER IF EXISTS audit_employees ON employees;
CREATE TRIGGER audit_employees
    AFTER INSERT OR UPDATE OR DELETE ON employees
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Suppliers
DROP TRIGGER IF EXISTS audit_suppliers ON suppliers;
CREATE TRIGGER audit_suppliers
    AFTER INSERT OR UPDATE OR DELETE ON suppliers
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Warehouses
DROP TRIGGER IF EXISTS audit_warehouses ON warehouses;
CREATE TRIGGER audit_warehouses
    AFTER INSERT OR UPDATE OR DELETE ON warehouses
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- =====================================================
-- 5. RPC FUNCTION TO QUERY CHANGE HISTORY
-- =====================================================

CREATE OR REPLACE FUNCTION get_change_history(
    p_table_name VARCHAR DEFAULT NULL,
    p_record_id UUID DEFAULT NULL,
    p_doc_number VARCHAR DEFAULT NULL,
    p_from_date TIMESTAMP DEFAULT NULL,
    p_to_date TIMESTAMP DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID,
    table_name VARCHAR,
    record_id UUID,
    doc_number VARCHAR,
    change_type VARCHAR,
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    changed_by UUID,
    changed_by_name TEXT,
    changed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cl.id,
        cl.table_name,
        cl.record_id,
        cl.doc_number,
        cl.change_type,
        cl.old_values,
        cl.new_values,
        cl.changed_fields,
        cl.changed_by,
        cl.changed_by_name,
        cl.changed_at
    FROM change_log cl
    WHERE 
        (p_table_name IS NULL OR cl.table_name = p_table_name)
        AND (p_record_id IS NULL OR cl.record_id = p_record_id)
        AND (p_doc_number IS NULL OR cl.doc_number = p_doc_number)
        AND (p_from_date IS NULL OR cl.changed_at >= p_from_date)
        AND (p_to_date IS NULL OR cl.changed_at <= p_to_date)
    ORDER BY cl.changed_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get specific field change history (e.g., price changes)
CREATE OR REPLACE FUNCTION get_field_change_history(
    p_table_name VARCHAR,
    p_field_name VARCHAR,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    record_id UUID,
    doc_number VARCHAR,
    old_value JSONB,
    new_value JSONB,
    changed_by_name TEXT,
    changed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cl.record_id,
        cl.doc_number,
        cl.old_values->p_field_name AS old_value,
        cl.new_values->p_field_name AS new_value,
        cl.changed_by_name,
        cl.changed_at
    FROM change_log cl
    WHERE cl.table_name = p_table_name
    AND cl.change_type = 'UPDATE'
    AND p_field_name = ANY(cl.changed_fields)
    ORDER BY cl.changed_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. RLS FOR CHANGE LOG
-- =====================================================

ALTER TABLE change_log ENABLE ROW LEVEL SECURITY;

-- Only admins and managers can view audit logs
DROP POLICY IF EXISTS change_log_policy ON change_log;
CREATE POLICY change_log_policy ON change_log
    FOR SELECT TO authenticated
    USING (
        has_permission(auth.uid(), 'reports', 'inventory')
        OR has_permission(auth.uid(), 'settings', 'manage')
    );

-- No one can modify change logs (append-only)
DROP POLICY IF EXISTS change_log_insert_policy ON change_log;
CREATE POLICY change_log_insert_policy ON change_log
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- =====================================================
-- 7. GRANT PERMISSIONS
-- =====================================================

GRANT SELECT, INSERT ON change_log TO authenticated;
GRANT EXECUTE ON FUNCTION get_change_history TO authenticated;
GRANT EXECUTE ON FUNCTION get_field_change_history TO authenticated;

-- Success Message
DO $$
BEGIN
    RAISE NOTICE '✅ Audit Logging System installed successfully!';
    RAISE NOTICE '📊 Table created: change_log';
    RAISE NOTICE '🔍 Triggers attached: items, purchase_orders, goods_receipt_notes, employees, suppliers, warehouses';
    RAISE NOTICE '📋 RPC functions: get_change_history, get_field_change_history';
END $$;
