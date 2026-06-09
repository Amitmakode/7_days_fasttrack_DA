-- =============================================
-- ETL: Load ROLAP from OLTP (MySQL Native)
-- CORRECTED VERSION - Fixed window function syntax
-- =============================================

USE retail_rolap;

DELIMITER $$

-- =============================================
-- Populate Date Dimension (FIXED)
-- =============================================

CREATE PROCEDURE sp_populate_date_dimension(IN start_year INT, IN end_year INT)
BEGIN
    DECLARE v_current_date DATE;
    DECLARE v_end_date DATE;
    DECLARE v_fiscal_year INT;
    DECLARE v_fiscal_month INT;
    DECLARE v_fiscal_quarter INT;
    
    SET v_current_date = DATE(CONCAT(start_year, '-01-01'));
    SET v_end_date = DATE(CONCAT(end_year, '-12-31'));
    
    WHILE v_current_date <= v_end_date DO
        -- Calculate fiscal year (April-March)
        IF MONTH(v_current_date) >= 4 THEN
            SET v_fiscal_year = YEAR(v_current_date);
            SET v_fiscal_month = MONTH(v_current_date) - 3;
        ELSE
            SET v_fiscal_year = YEAR(v_current_date) - 1;
            SET v_fiscal_month = MONTH(v_current_date) + 9;
        END IF;
        SET v_fiscal_quarter = CEIL(v_fiscal_month / 3);
        
        INSERT INTO dim_date (
            date_id,
            full_date,
            year_val,
            quarter_val,
            quarter_label,
            month_val,
            month_name,
            month_short,
            day_val,
            day_of_week,
            weekday_name,
            weekday_short,
            week_of_year,
            is_weekend,
            fiscal_year,
            fiscal_quarter,
            fiscal_month
        ) VALUES (
            YEAR(v_current_date) * 10000 + MONTH(v_current_date) * 100 + DAY(v_current_date),
            v_current_date,
            YEAR(v_current_date),
            QUARTER(v_current_date),
            CONCAT('Q', QUARTER(v_current_date)),
            MONTH(v_current_date),
            MONTHNAME(v_current_date),
            LEFT(MONTHNAME(v_current_date), 3),
            DAY(v_current_date),
            DAYOFWEEK(v_current_date),
            DAYNAME(v_current_date),
            LEFT(DAYNAME(v_current_date), 3),
            WEEKOFYEAR(v_current_date),
            IF(DAYOFWEEK(v_current_date) IN (1,7), TRUE, FALSE),
            v_fiscal_year,
            v_fiscal_quarter,
            v_fiscal_month
        )
        ON DUPLICATE KEY UPDATE
            full_date = VALUES(full_date),
            is_weekend = VALUES(is_weekend);
        
        SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
    END WHILE;
    
    SELECT CONCAT('Date dimension populated: ', COUNT(*), ' rows') AS Status
    FROM dim_date;
END$$

-- =============================================
-- Load Dimensions from OLTP
-- =============================================

CREATE PROCEDURE sp_load_rolap_dimensions()
BEGIN
    -- Load Product Dimension
    INSERT INTO dim_product (
        product_id, product_name, brand, category, sub_category,
        mrp, cost_price, gross_margin_pct, is_perishable, veg_nonveg
    )
    SELECT 
        p.product_code,
        p.product_name,
        IFNULL(b.brand_name, 'Unknown'),
        IFNULL(c1.category_name, 'Unknown'),
        IFNULL(c2.category_name, 'Unknown'),
        p.mrp,
        p.cost_price,
        p.gross_margin_pct,
        p.is_perishable,
        p.veg_nonveg
    FROM retail_oltp.products p
    LEFT JOIN retail_oltp.brands b ON p.brand_id = b.brand_id
    LEFT JOIN retail_oltp.categories c1 ON p.category_id = c1.category_id
    LEFT JOIN retail_oltp.categories c2 ON p.sub_category_id = c2.category_id
    ON DUPLICATE KEY UPDATE
        product_name = VALUES(product_name),
        brand = VALUES(brand),
        category = VALUES(category),
        mrp = VALUES(mrp),
        cost_price = VALUES(cost_price);
    
    -- Load Store Dimension
    INSERT INTO dim_store (
        store_id, store_name, city, state, city_tier,
        cluster_zone, store_type, store_size_sqft, opening_date
    )
    SELECT 
        store_code, store_name, city, state, city_tier,
        cluster_zone, store_type, store_size_sqft, opening_date
    FROM retail_oltp.stores
    ON DUPLICATE KEY UPDATE
        store_name = VALUES(store_name),
        city = VALUES(city);
    
    -- Load Customer Dimension
    INSERT INTO dim_customer (
        customer_id, customer_name, gender, age_group, city, state,
        city_tier, is_registered, loyalty_member, customer_segment
    )
    SELECT 
        customer_code,
        customer_name,
        IFNULL(lg.gender_name, 'Unknown'),
        IFNULL(age_group, 'Unknown'),
        IFNULL(city, 'Unknown'),
        IFNULL(state, 'Unknown'),
        city_tier,
        is_registered,
        loyalty_member,
        CASE 
            WHEN avg_monthly_spend_inr > 25000 THEN 'VIP'
            WHEN avg_monthly_spend_inr > 10000 THEN 'Premium'
            WHEN avg_monthly_spend_inr > 5000 THEN 'Regular'
            WHEN avg_monthly_spend_inr > 0 THEN 'Occasional'
            ELSE 'Inactive'
        END
    FROM retail_oltp.customers c
    LEFT JOIN retail_oltp.lookup_gender lg ON c.gender = lg.gender_code
    ON DUPLICATE KEY UPDATE
        customer_name = VALUES(customer_name),
        customer_segment = VALUES(customer_segment);
    
    -- Load Supplier Dimension
    INSERT INTO dim_supplier (
        supplier_id, supplier_name, supplier_type, city, state,
        payment_days, lead_time_days, is_preferred_vendor
    )
    SELECT 
        supplier_code, supplier_name, supplier_type, city, state,
        payment_days, lead_time_days, is_preferred_vendor
    FROM retail_oltp.suppliers
    ON DUPLICATE KEY UPDATE
        supplier_name = VALUES(supplier_name);
    
    SELECT 'ROLAP dimensions loaded successfully' AS Status;
END$$

-- =============================================
-- Load Fact Sales
-- =============================================

CREATE PROCEDURE sp_load_fact_sales()
BEGIN
    INSERT INTO fact_sales (
        transaction_id, date_id, product_key, store_key, customer_key, supplier_key,
        quantity, unit_price, discount_amount, sale_amount, cost_amount, profit, margin_pct, payment_mode, is_return
    )
    SELECT 
        so.order_number,
        DATE_FORMAT(so.order_date, '%Y%m%d'),
        dp.product_key,
        ds.store_key,
        dc.customer_key,
        dsup.supplier_key,
        soi.quantity,
        soi.unit_price,
        soi.discount_amount,
        soi.net_price,
        (soi.quantity * dp.cost_price),
        (soi.net_price - (soi.quantity * dp.cost_price)),
        CASE 
            WHEN soi.net_price > 0 
            THEN ((soi.net_price - (soi.quantity * dp.cost_price)) / soi.net_price) * 100
            ELSE 0
        END,
        pm.payment_mode_name,
        so.is_return
    FROM retail_oltp.sales_orders so
    JOIN retail_oltp.sales_order_items soi ON so.order_id = soi.order_id
    JOIN retail_oltp.products p ON soi.product_id = p.product_id
    JOIN dim_product dp ON p.product_code = dp.product_id
    JOIN retail_oltp.stores s ON so.store_id = s.store_id
    JOIN dim_store ds ON s.store_code = ds.store_id
    LEFT JOIN retail_oltp.customers c ON so.customer_id = c.customer_id
    LEFT JOIN dim_customer dc ON c.customer_code = dc.customer_id
    LEFT JOIN retail_oltp.suppliers sup ON soi.product_id = sup.supplier_id
    LEFT JOIN dim_supplier dsup ON sup.supplier_code = dsup.supplier_id
    JOIN retail_oltp.lookup_payment_mode pm ON so.payment_mode_id = pm.payment_mode_id
    WHERE so.status_id = 3
    ON DUPLICATE KEY UPDATE
        quantity = VALUES(quantity),
        sale_amount = VALUES(sale_amount);
    
    SELECT CONCAT('Fact sales loaded: ', ROW_COUNT(), ' rows') AS Status;
END$$

-- =============================================
-- Refresh Aggregate Tables (FIXED - Added backticks)
-- =============================================

CREATE PROCEDURE sp_refresh_aggregates()
BEGIN
    -- Daily Store Sales
    DELETE FROM agg_daily_store_sales;
    INSERT INTO agg_daily_store_sales (date_id, store_key, total_sales, total_quantity, transaction_count, unique_customers, avg_ticket_size)
    SELECT 
        fs.date_id,
        fs.store_key,
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key),
        AVG(fs.sale_amount)
    FROM fact_sales fs
    GROUP BY fs.date_id, fs.store_key;
    
    -- Daily Product Sales
    DELETE FROM agg_daily_product_sales;
    INSERT INTO agg_daily_product_sales (date_id, product_key, total_sales, total_quantity, transaction_count)
    SELECT 
        fs.date_id,
        fs.product_key,
        SUM(fs.sale_amount),
        SUM(fs.quantity),
        COUNT(DISTINCT fs.transaction_id)
    FROM fact_sales fs
    GROUP BY fs.date_id, fs.product_key;
    
    -- Monthly Category Sales
    DELETE FROM agg_monthly_category_sales;
    INSERT INTO agg_monthly_category_sales (`year_month`, `category`, total_sales, total_profit, total_quantity, transaction_count)
    SELECT 
        d.year_val * 100 + d.month_val,
        dp.category,
        SUM(fs.sale_amount),
        SUM(fs.profit),
        SUM(fs.quantity),
        COUNT(DISTINCT fs.transaction_id)
    FROM fact_sales fs
    JOIN dim_date d ON fs.date_id = d.date_id
    JOIN dim_product dp ON fs.product_key = dp.product_key
    GROUP BY d.year_val, d.month_val, dp.category;
    
    -- Update ranks using MySQL 8.0 window function (FIXED: added backticks)
    UPDATE agg_monthly_category_sales amc
    JOIN (
        SELECT 
            `year_month`,
            `category`,
            ROW_NUMBER() OVER (PARTITION BY `year_month` ORDER BY total_sales DESC) AS new_rank
        FROM agg_monthly_category_sales
    ) ranked ON amc.`year_month` = ranked.`year_month` AND amc.`category` = ranked.`category`
    SET amc.sales_rank = ranked.new_rank;
    
    -- Monthly Store Performance
    DELETE FROM agg_monthly_store_performance;
    INSERT INTO agg_monthly_store_performance (`year_month`, store_key, total_sales, total_profit, transaction_count, unique_customers, avg_ticket_size)
    SELECT 
        d.year_val * 100 + d.month_val,
        fs.store_key,
        SUM(fs.sale_amount),
        SUM(fs.profit),
        COUNT(DISTINCT fs.transaction_id),
        COUNT(DISTINCT fs.customer_key),
        AVG(fs.sale_amount)
    FROM fact_sales fs
    JOIN dim_date d ON fs.date_id = d.date_id
    GROUP BY d.year_val, d.month_val, fs.store_key;
    
    -- Customer Lifetime Value
    DELETE FROM agg_customer_lifetime;
    INSERT INTO agg_customer_lifetime (
        customer_key, first_purchase_date, last_purchase_date,
        total_spend, total_transactions, avg_order_value,
        days_since_last_purchase, lifetime_segment
    )
    SELECT 
        fs.customer_key,
        MIN(d.full_date),
        MAX(d.full_date),
        SUM(fs.sale_amount),
        COUNT(DISTINCT fs.transaction_id),
        AVG(fs.sale_amount),
        DATEDIFF(CURDATE(), MAX(d.full_date)),
        CASE 
            WHEN SUM(fs.sale_amount) > 100000 THEN 'Platinum'
            WHEN SUM(fs.sale_amount) > 50000 THEN 'Gold'
            WHEN SUM(fs.sale_amount) > 10000 THEN 'Silver'
            ELSE 'Bronze'
        END
    FROM fact_sales fs
    JOIN dim_date d ON fs.date_id = d.date_id
    WHERE fs.customer_key IS NOT NULL
    GROUP BY fs.customer_key;
    
    SELECT 'Aggregates refreshed successfully' AS Status;
END$$

-- =============================================
-- Complete ROLAP ETL
-- =============================================

CREATE PROCEDURE sp_run_rolap_etl()
BEGIN
    DECLARE v_start DATETIME;
    SET v_start = NOW();
    
    SELECT 'Starting ROLAP ETL...' AS Status;
    
    START TRANSACTION;
    
    CALL sp_populate_date_dimension(2020, 2026);
    CALL sp_load_rolap_dimensions();
    CALL sp_load_fact_sales();
    CALL sp_refresh_aggregates();
    
    COMMIT;
    
    SELECT CONCAT('ROLAP ETL completed in ', TIMESTAMPDIFF(SECOND, v_start, NOW()), ' seconds') AS Status;
END$$

DELIMITER ;

-- Execute ROLAP ETL
CALL sp_run_rolap_etl();