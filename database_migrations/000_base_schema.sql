-- 000_base_schema.sql
-- Base Schema for Seven Waves ERP
-- Implements core tables required by other migrations

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Common Tables
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    avatar_url TEXT,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS units_of_measure (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS item_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE,
    name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS warehouses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE,
    name VARCHAR(100) NOT NULL,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    manager_id UUID REFERENCES profiles(id)
);

CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE,
    name VARCHAR(100) NOT NULL,
    contact_email VARCHAR(100),
    is_active BOOLEAN DEFAULT true
);

-- 2. Items & Stock
CREATE TABLE IF NOT EXISTS items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_code VARCHAR(50) UNIQUE NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    category_id UUID REFERENCES item_categories(id),
    base_uom_id UUID REFERENCES units_of_measure(id),
    purchase_price DECIMAL(15, 2) DEFAULT 0,
    selling_price DECIMAL(15, 2) DEFAULT 0,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    is_inventory_item BOOLEAN DEFAULT true,
    is_sales_item BOOLEAN DEFAULT true,
    is_purchase_item BOOLEAN DEFAULT true,
    min_stock_level DECIMAL(10, 2) DEFAULT 0,
    max_stock_level DECIMAL(10, 2),
    reorder_point DECIMAL(10, 2),
    reorder_quantity DECIMAL(10, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS item_uom (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    uom_id UUID REFERENCES units_of_measure(id),
    conversion_factor DECIMAL(10, 4) DEFAULT 1,
    is_default_sales BOOLEAN DEFAULT false,
    is_default_purchase BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS warehouse_stock (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID REFERENCES items(id) ON DELETE CASCADE,
    warehouse_id UUID REFERENCES warehouses(id) ON DELETE CASCADE,
    quantity_on_hand DECIMAL(15, 4) DEFAULT 0,
    quantity_committed DECIMAL(15, 4) DEFAULT 0,
    quantity_ordered DECIMAL(15, 4) DEFAULT 0,
    average_cost DECIMAL(15, 2) DEFAULT 0,
    item_code TEXT, -- Added by 001
    UNIQUE(item_id, warehouse_id)
);

CREATE TABLE IF NOT EXISTS stock_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID REFERENCES items(id),
    warehouse_id UUID REFERENCES warehouses(id),
    transaction_type VARCHAR(50),
    quantity DECIMAL(15, 4),
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    doc_number VARCHAR(50),
    notes TEXT,
    item_code TEXT
);

-- 3. Purchase Orders
CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    supplier_id UUID REFERENCES suppliers(id),
    warehouse_id UUID REFERENCES warehouses(id),
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'approved', 'completed', 'closed', 'cancelled')),
    doc_date DATE DEFAULT CURRENT_DATE,
    delivery_date DATE,
    subtotal DECIMAL(15, 2) DEFAULT 0,
    tax_amount DECIMAL(15, 2) DEFAULT 0,
    discount_amount DECIMAL(15, 2) DEFAULT 0,
    total_amount DECIMAL(15, 2) DEFAULT 0,
    remarks TEXT,
    created_by UUID REFERENCES profiles(id), -- or auth.users
    approved_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS po_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    po_id UUID REFERENCES purchase_orders(id) ON DELETE CASCADE,
    line_num INTEGER,
    item_id UUID REFERENCES items(id),
    item_code TEXT, -- Added by 001
    item_description TEXT,
    quantity DECIMAL(15, 4) NOT NULL,
    uom_id UUID REFERENCES units_of_measure(id),
    unit_price DECIMAL(15, 2) DEFAULT 0,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    tax_percent DECIMAL(5, 2) DEFAULT 0,
    line_total DECIMAL(15, 2) DEFAULT 0,
    received_quantity DECIMAL(15, 4) DEFAULT 0,
    open_quantity DECIMAL(15, 4),
    warehouse_id UUID REFERENCES warehouses(id)
);

-- 4. Goods Receipt Notes (GRN) -- Schema for 07_finance to build on
CREATE TABLE IF NOT EXISTS goods_receipt_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doc_number VARCHAR(50) UNIQUE NOT NULL,
    supplier_id UUID REFERENCES suppliers(id),
    warehouse_id UUID REFERENCES warehouses(id),
    purchase_order_id UUID REFERENCES purchase_orders(id),
    doc_date DATE DEFAULT CURRENT_DATE,
    due_date DATE,
    ref_number VARCHAR(50),
    status VARCHAR(20) DEFAULT 'draft',
    subtotal DECIMAL(15, 2),
    total_amount DECIMAL(15, 2),
    remarks TEXT,
    created_by UUID REFERENCES profiles(id),
    approved_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS grn_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grn_id UUID REFERENCES goods_receipt_notes(id) ON DELETE CASCADE,
    po_line_id UUID REFERENCES po_lines(id),
    item_id UUID REFERENCES items(id),
    item_code TEXT,
    quantity DECIMAL(15, 4),
    unit_cost DECIMAL(15, 2),
    line_total DECIMAL(15, 2),
    warehouse_id UUID REFERENCES warehouses(id)
);

-- 5. RPC Helpers
CREATE OR REPLACE FUNCTION generate_doc_number(p_doc_type TEXT) RETURNS TEXT AS $$
DECLARE
    new_doc_num TEXT;
BEGIN
    new_doc_num := p_doc_type || '-' || extract(epoch from now())::bigint;
    RETURN new_doc_num;
END;
$$ LANGUAGE plpgsql;
