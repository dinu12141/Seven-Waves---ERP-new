-- =================================================================
-- SEED DATA - SALES HIERARCHY
-- Structure: Zone -> Region -> District -> Branch -> Team
-- =================================================================

DO $$
DECLARE
    v_zone_id UUID;
    v_region_west_id UUID;
    v_region_south_id UUID;
    v_dist_colombo_id UUID;
    v_dist_galle_id UUID;
    v_branch_col_1 UUID;
    v_branch_galle_1 UUID;
BEGIN
    -- 1. Create ZONE
    INSERT INTO sales_hierarchy (name, type) 
    VALUES ('National Zone', 'Zone') 
    RETURNING id INTO v_zone_id;

    -- 2. Create REGIONS
    INSERT INTO sales_hierarchy (name, type, parent_id) 
    VALUES ('Western Region', 'Region', v_zone_id) 
    RETURNING id INTO v_region_west_id;
    
    INSERT INTO sales_hierarchy (name, type, parent_id) 
    VALUES ('Southern Region', 'Region', v_zone_id) 
    RETURNING id INTO v_region_south_id;

    -- 3. Create DISTRICTS
    INSERT INTO sales_hierarchy (name, type, parent_id) 
    VALUES ('Colombo District', 'District', v_region_west_id) 
    RETURNING id INTO v_dist_colombo_id;
    
    INSERT INTO sales_hierarchy (name, type, parent_id) 
    VALUES ('Galle District', 'District', v_region_south_id) 
    RETURNING id INTO v_dist_galle_id;

    -- 4. Create BRANCHES
    INSERT INTO sales_hierarchy (name, type, parent_id) 
    VALUES ('Colombo Central Branch', 'Branch', v_dist_colombo_id) 
    RETURNING id INTO v_branch_col_1;
    
    INSERT INTO sales_hierarchy (name, type, parent_id) 
    VALUES ('Galle City Branch', 'Branch', v_dist_galle_id) 
    RETURNING id INTO v_branch_galle_1;

    -- 5. Create TEAMS
    INSERT INTO sales_hierarchy (name, type, parent_id)
    VALUES ('Team Alpha', 'Team', v_branch_col_1);
    
    INSERT INTO sales_hierarchy (name, type, parent_id)
    VALUES ('Team Beta', 'Team', v_branch_col_1);

    INSERT INTO sales_hierarchy (name, type, parent_id)
    VALUES ('Team Coastal', 'Team', v_branch_galle_1);

    RAISE NOTICE '✅ Sales Hierarchy Seeded Successfully!';
END $$;
