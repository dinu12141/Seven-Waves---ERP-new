-- =================================================================
-- MIGRATION: CREATE POS INVOICE TABLES
-- =================================================================

-- 1. Invoices Table
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    status VARCHAR(50) DEFAULT 'draft', -- 'draft', 'paid', 'void'
    payment_method VARCHAR(50), -- 'cash', 'card', 'transfer'
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- 2. Invoice Lines Table
CREATE TABLE IF NOT EXISTS public.invoice_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE CASCADE,
    item_id UUID REFERENCES public.items(id),
    quantity DECIMAL(10, 2) NOT NULL DEFAULT 1,
    unit_price DECIMAL(15, 2) NOT NULL DEFAULT 0,
    line_total DECIMAL(15, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

-- 3. Enable RLS (Optional, but good practice)
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_lines ENABLE ROW LEVEL SECURITY;

-- 4. Policies (Allow all for simplified POS MVP)
CREATE POLICY "Allow all access to invoices" ON public.invoices FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to invoice_lines" ON public.invoice_lines FOR ALL USING (true) WITH CHECK (true);
