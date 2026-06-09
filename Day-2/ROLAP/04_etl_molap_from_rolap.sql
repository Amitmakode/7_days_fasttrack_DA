-- =============================================
-- ETL: Load MOLAP from ROLAP (MySQL Native)
-- FIXED: Resolved Error 1093 (can't specify target table in FROM clause)
-- =============================================

USE retail_molap;

DELIMITER $$

-- =============================================
-- Cube 1: Sales by Store x Product x Date
-- =============================================

CREATE PROCEDURE sp_refresh_cube_sales_store_product_date()
BEGIN
    DELETE FROM cube_sales_store_product_date;
    
    INSERT INTO cube_sales_store_product_date (
        store_id, product_id, date_id, year_val, quarter_val, month_val,
        store_city, store_state, product_category, product_brand,
        total_sales, total_quantity, transaction_count, unique_customers, total_profit, avg_margin_pct
    )
    SELECT 
        ds.store_id,
        dp.product_id,
        fs.date_id,
        d.year_val,
        d.quarter_val,
        d.month_val,
        ds.city,
        ds.state,
        dp.category,
        dp.brand,
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key),
        SUM(fs.profit),
        AVG(fs.margin_pct)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_store ds ON fs.store_key = ds.store_key
    JOIN retail_rolap.dim_product dp ON fs.product_key = dp.product_key
    JOIN retail_rolap.dim_date d ON fs.date_id = d.date_id
    GROUP BY ds.store_id, dp.product_id, fs.date_id, d.year_val, d.quarter_val, d.month_val,
             ds.city, ds.state, dp.category, dp.brand;
    
    SELECT CONCAT('Cube 1 refreshed: ', ROW_COUNT(), ' rows') AS Status;
END$$

-- =============================================
-- Cube 2: Sales by Category x Month (FIXED - Error 1093)
-- =============================================

CREATE PROCEDURE sp_refresh_cube_sales_category_month()
BEGIN
    DELETE FROM cube_sales_category_month;
    
    INSERT INTO cube_sales_category_month (
        product_category, `year_month`, year_val, month_val,
        total_sales, total_quantity, transaction_count, total_profit
    )
    SELECT 
        category,
        `year_month`,
        `year_month` DIV 100,
        `year_month` MOD 100,
        SUM(total_sales),
        SUM(total_quantity),
        SUM(transaction_count),
        SUM(total_profit)
    FROM retail_rolap.agg_monthly_category_sales
    GROUP BY category, `year_month`;
    
    -- Update previous month sales using a temporary table (FIX for Error 1093)
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_prev_month_sales AS
    SELECT 
        product_category,
        `year_month`,
        total_sales AS prev_sales
    FROM cube_sales_category_month;
    
    UPDATE cube_sales_category_month c
    JOIN temp_prev_month_sales p ON p.product_category = c.product_category 
        AND p.`year_month` = c.`year_month` - 1
    SET c.prev_month_sales = p.prev_sales;
    
    DROP TEMPORARY TABLE temp_prev_month_sales;
    
    -- Update growth percentage
    UPDATE cube_sales_category_month
    SET growth_pct = CASE 
        WHEN prev_month_sales IS NOT NULL AND prev_month_sales > 0 
        THEN ((total_sales - prev_month_sales) / prev_month_sales) * 100
        ELSE NULL
    END;
    
    SELECT CONCAT('Cube 2 refreshed: ', ROW_COUNT(), ' rows') AS Status;
END$$

-- =============================================
-- Cube 3: Sales by Customer Segment x Store Type
-- =============================================

CREATE PROCEDURE sp_refresh_cube_sales_segment_storetype()
BEGIN
    DELETE FROM cube_sales_segment_storetype;
    
    INSERT INTO cube_sales_segment_storetype (
        customer_segment, store_type, year_val,
        total_sales, transaction_count, unique_customers, avg_order_value
    )
    SELECT 
        dc.customer_segment,
        ds.store_type,
        d.year_val,
        SUM(fs.sale_amount),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key),
        AVG(fs.sale_amount)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_customer dc ON fs.customer_key = dc.customer_key
    JOIN retail_rolap.dim_store ds ON fs.store_key = ds.store_key
    JOIN retail_rolap.dim_date d ON fs.date_id = d.date_id
    WHERE dc.customer_segment IS NOT NULL
    GROUP BY dc.customer_segment, ds.store_type, d.year_val;
    
    SELECT CONCAT('Cube 3 refreshed: ', ROW_COUNT(), ' rows') AS Status;
END$$

-- =============================================
-- Cube 4: Time Series with Moving Averages (FIXED - Error 1093)
-- =============================================

CREATE PROCEDURE sp_refresh_cube_time_series()
BEGIN
    DELETE FROM cube_time_series;
    
    -- Daily level
    INSERT INTO cube_time_series (time_level, time_value, time_label, start_date, end_date, total_sales, total_quantity, transaction_count, unique_customers)
    SELECT 
        'DAY',
        CAST(d.date_id AS CHAR),
        d.full_date,
        d.full_date,
        d.full_date,
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_date d ON fs.date_id = d.date_id
    GROUP BY d.date_id, d.full_date;
    
    -- Weekly level
    INSERT INTO cube_time_series (time_level, time_value, time_label, start_date, end_date, total_sales, total_quantity, transaction_count, unique_customers)
    SELECT 
        'WEEK',
        CONCAT(d.year_val, '-W', d.week_of_year),
        CONCAT('Week ', d.week_of_year, ', ', d.year_val),
        MIN(d.full_date),
        MAX(d.full_date),
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_date d ON fs.date_id = d.date_id
    GROUP BY d.year_val, d.week_of_year;
    
    -- Monthly level
    INSERT INTO cube_time_series (time_level, time_value, time_label, start_date, end_date, total_sales, total_quantity, transaction_count, unique_customers)
    SELECT 
        'MONTH',
        CONCAT(d.year_val, '-', LPAD(d.month_val, 2, '0')),
        CONCAT(d.month_name, ' ', d.year_val),
        MIN(d.full_date),
        MAX(d.full_date),
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_date d ON fs.date_id = d.date_id
    GROUP BY d.year_val, d.month_val, d.month_name;
    
    -- Quarterly level
    INSERT INTO cube_time_series (time_level, time_value, time_label, start_date, end_date, total_sales, total_quantity, transaction_count, unique_customers)
    SELECT 
        'QUARTER',
        CONCAT(d.year_val, '-Q', d.quarter_val),
        CONCAT('Q', d.quarter_val, ' ', d.year_val),
        MIN(d.full_date),
        MAX(d.full_date),
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_date d ON fs.date_id = d.date_id
    GROUP BY d.year_val, d.quarter_val;
    
    -- Yearly level
    INSERT INTO cube_time_series (time_level, time_value, time_label, start_date, end_date, total_sales, total_quantity, transaction_count, unique_customers)
    SELECT 
        'YEAR',
        CAST(d.year_val AS CHAR),
        CAST(d.year_val AS CHAR),
        MIN(d.full_date),
        MAX(d.full_date),
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_date d ON fs.date_id = d.date_id
    GROUP BY d.year_val;
    
    -- Calculate moving averages using temporary table (FIX for Error 1093)
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_daily_sales AS
    SELECT 
        start_date,
        total_sales
    FROM cube_time_series
    WHERE time_level = 'DAY';
    
    UPDATE cube_time_series t
    SET moving_avg_7d = (
        SELECT AVG(t2.total_sales)
        FROM temp_daily_sales t2
        WHERE t2.start_date BETWEEN DATE_SUB(t.start_date, INTERVAL 6 DAY) AND t.start_date
    )
    WHERE t.time_level = 'DAY';
    
    UPDATE cube_time_series t
    SET moving_avg_30d = (
        SELECT AVG(t2.total_sales)
        FROM temp_daily_sales t2
        WHERE t2.start_date BETWEEN DATE_SUB(t.start_date, INTERVAL 29 DAY) AND t.start_date
    )
    WHERE t.time_level = 'DAY';
    
    DROP TEMPORARY TABLE temp_daily_sales;
    
    SELECT CONCAT('Cube 4 refreshed: ', ROW_COUNT(), ' rows') AS Status;
END$$

-- =============================================
-- Cube 5: Product Hierarchy Rollups
-- =============================================

CREATE PROCEDURE sp_refresh_cube_product_hierarchy()
BEGIN
    DECLARE v_total_sales DECIMAL(14,2);
    
    DELETE FROM cube_product_hierarchy;
    
    -- Product level
    INSERT INTO cube_product_hierarchy (level_type, level_value, level_name, parent_value, total_sales, total_quantity, total_profit)
    SELECT 
        'PRODUCT',
        dp.product_id,
        dp.product_name,
        dp.category,
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        SUM(fs.profit)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_product dp ON fs.product_key = dp.product_key
    GROUP BY dp.product_id, dp.product_name, dp.category;
    
    -- Category level
    INSERT INTO cube_product_hierarchy (level_type, level_value, level_name, parent_value, total_sales, total_quantity, total_profit)
    SELECT 
        'CATEGORY',
        dp.category,
        dp.category,
        'ALL',
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        SUM(fs.profit)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_product dp ON fs.product_key = dp.product_key
    GROUP BY dp.category;
    
    -- All Products level
    INSERT INTO cube_product_hierarchy (level_type, level_value, level_name, parent_value, total_sales, total_quantity, total_profit)
    SELECT 
        'ALL',
        'ALL',
        'All Products',
        NULL,
        SUM(sale_amount),
        SUM(quantity),
        SUM(profit)
    FROM retail_rolap.fact_sales;
    
    -- Get total sales for ALL level
    SELECT total_sales INTO v_total_sales 
    FROM cube_product_hierarchy 
    WHERE level_type = 'ALL' 
    LIMIT 1;
    
    -- Calculate sales share percentage
    UPDATE cube_product_hierarchy ph
    SET sales_share_pct = (ph.total_sales / v_total_sales) * 100
    WHERE ph.level_type != 'ALL';
    
    SELECT CONCAT('Cube 5 refreshed: ', ROW_COUNT(), ' rows') AS Status;
END$$

-- =============================================
-- Cube 6: Store Geography Hierarchy
-- =============================================

CREATE PROCEDURE sp_refresh_cube_store_hierarchy()
BEGIN
    DELETE FROM cube_store_hierarchy;
    
    -- Store level
    INSERT INTO cube_store_hierarchy (level_type, level_value, level_name, parent_value, total_sales, transaction_count, unique_customers, avg_ticket_size)
    SELECT 
        'STORE',
        ds.store_id,
        ds.store_name,
        ds.city,
        SUM(fs.sale_amount),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key),
        AVG(fs.sale_amount)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_store ds ON fs.store_key = ds.store_key
    GROUP BY ds.store_id, ds.store_name, ds.city;
    
    -- City level
    INSERT INTO cube_store_hierarchy (level_type, level_value, level_name, parent_value, total_sales, transaction_count, unique_customers, avg_ticket_size)
    SELECT 
        'CITY',
        ds.city,
        ds.city,
        IFNULL(ds.state, 'ALL'),
        SUM(fs.sale_amount),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key),
        AVG(fs.sale_amount)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_store ds ON fs.store_key = ds.store_key
    WHERE ds.city IS NOT NULL
    GROUP BY ds.city, ds.state;
    
    -- State level
    INSERT INTO cube_store_hierarchy (level_type, level_value, level_name, parent_value, total_sales, transaction_count, unique_customers, avg_ticket_size)
    SELECT 
        'STATE',
        ds.state,
        ds.state,
        IFNULL(ds.cluster_zone, 'ALL'),
        SUM(fs.sale_amount),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key),
        AVG(fs.sale_amount)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_store ds ON fs.store_key = ds.store_key
    WHERE ds.state IS NOT NULL
    GROUP BY ds.state, ds.cluster_zone;
    
    -- Cluster level
    INSERT INTO cube_store_hierarchy (level_type, level_value, level_name, parent_value, total_sales, transaction_count, unique_customers, avg_ticket_size)
    SELECT 
        'CLUSTER',
        ds.cluster_zone,
        ds.cluster_zone,
        'ALL',
        SUM(fs.sale_amount),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key),
        AVG(fs.sale_amount)
    FROM retail_rolap.fact_sales fs
    JOIN retail_rolap.dim_store ds ON fs.store_key = ds.store_key
    WHERE ds.cluster_zone IS NOT NULL
    GROUP BY ds.cluster_zone;
    
    -- All Stores level
    INSERT INTO cube_store_hierarchy (level_type, level_value, level_name, parent_value, total_sales, transaction_count, unique_customers, avg_ticket_size)
    SELECT 
        'ALL',
        'ALL',
        'All Stores',
        NULL,
        SUM(sale_amount),
        COUNT(DISTINCT transaction_id),
        COUNT(DISTINCT customer_key),
        AVG(sale_amount)
    FROM retail_rolap.fact_sales;
    
    SELECT CONCAT('Cube 6 refreshed: ', ROW_COUNT(), ' rows') AS Status;
END$$

-- =============================================
-- Cube 7: Customer Segmentation
-- =============================================

CREATE PROCEDURE sp_refresh_cube_customer_segmentation()
BEGIN
    DELETE FROM cube_customer_segmentation;
    
    INSERT INTO cube_customer_segmentation (
        customer_segment, age_group, city_tier, loyalty_member,
        customer_count, total_sales, avg_order_value, avg_transactions_per_customer
    )
    SELECT 
        dc.customer_segment,
        dc.age_group,
        dc.city_tier,
        dc.loyalty_member,
        COUNT(DISTINCT dc.customer_key),
        COALESCE(SUM(fs.sale_amount), 0),
        COALESCE(AVG(fs.sale_amount), 0),
        COALESCE(COUNT(DISTINCT fs.transaction_id) / NULLIF(COUNT(DISTINCT dc.customer_key), 0), 0)
    FROM retail_rolap.dim_customer dc
    LEFT JOIN retail_rolap.fact_sales fs ON dc.customer_key = fs.customer_key
    GROUP BY dc.customer_segment, dc.age_group, dc.city_tier, dc.loyalty_member;
    
    SELECT CONCAT('Cube 7 refreshed: ', ROW_COUNT(), ' rows') AS Status;
END$$

-- =============================================
-- Refresh All MOLAP Cubes
-- =============================================

CREATE PROCEDURE sp_refresh_all_molap_cubes()
BEGIN
    DECLARE v_start DATETIME;
    SET v_start = NOW();
    
    SELECT 'Refreshing all MOLAP cubes...' AS Status;
    
    CALL sp_refresh_cube_sales_store_product_date();
    CALL sp_refresh_cube_sales_category_month();
    CALL sp_refresh_cube_sales_segment_storetype();
    CALL sp_refresh_cube_time_series();
    CALL sp_refresh_cube_product_hierarchy();
    CALL sp_refresh_cube_store_hierarchy();
    CALL sp_refresh_cube_customer_segmentation();
    
    SELECT CONCAT('All MOLAP cubes refreshed in ', TIMESTAMPDIFF(SECOND, v_start, NOW()), ' seconds') AS Status;
    
    -- Summary
    SELECT 'MOLAP Cube Record Counts:' AS Summary;
    SELECT 'cube_sales_store_product_date' AS Cube_Name, COUNT(*) AS Records FROM cube_sales_store_product_date
    UNION ALL SELECT 'cube_sales_category_month', COUNT(*) FROM cube_sales_category_month
    UNION ALL SELECT 'cube_sales_segment_storetype', COUNT(*) FROM cube_sales_segment_storetype
    UNION ALL SELECT 'cube_time_series', COUNT(*) FROM cube_time_series
    UNION ALL SELECT 'cube_product_hierarchy', COUNT(*) FROM cube_product_hierarchy
    UNION ALL SELECT 'cube_store_hierarchy', COUNT(*) FROM cube_store_hierarchy
    UNION ALL SELECT 'cube_customer_segmentation', COUNT(*) FROM cube_customer_segmentation;
END$$

DELIMITER ;

-- Execute MOLAP refresh
CALL sp_refresh_all_molap_cubes();