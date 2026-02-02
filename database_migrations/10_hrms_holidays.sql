-- =================================================================
-- SEVEN WAVES ERP - HRMS: HOLIDAY MANAGEMENT
-- =================================================================

-- 1. Create Holidays Table
CREATE TABLE IF NOT EXISTS holidays (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    holiday_date DATE NOT NULL,
    holiday_type VARCHAR(20) DEFAULT 'Public' CHECK (holiday_type IN ('Public', 'Bank', 'Mercantile', 'Company')),
    is_recurring BOOLEAN DEFAULT false,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES profiles(id),
    UNIQUE(holiday_date)
);

-- 2. Grant Permissions
GRANT ALL ON holidays TO authenticated;

-- 3. Seed Data (Example 2026 Sri Lankan Holidays)
INSERT INTO holidays (name, holiday_date, holiday_type, is_recurring)
VALUES 
('Duruthu Full Moon Poya Day', '2026-01-03', 'Public', false),
('Tamil Thai Pongal Day', '2026-01-14', 'Public', true),
('National Day', '2026-02-04', 'Public', true),
('Mahasivarathri Day', '2026-02-16', 'Public', false),
('Good Friday', '2026-04-03', 'Public', false),
('Sinhala & Tamil New Year Day', '2026-04-14', 'Public', true)
ON CONFLICT (holiday_date) DO NOTHING;

-- 4. RPC to Check if a date is a holiday
CREATE OR REPLACE FUNCTION is_holiday(check_date DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM holidays 
        WHERE holiday_date = check_date 
        OR (is_recurring = true AND 
            EXTRACT(MONTH FROM holiday_date) = EXTRACT(MONTH FROM check_date) AND 
            EXTRACT(DAY FROM holiday_date) = EXTRACT(DAY FROM check_date))
    );
END;
$$;

GRANT EXECUTE ON FUNCTION is_holiday(DATE) TO authenticated;
