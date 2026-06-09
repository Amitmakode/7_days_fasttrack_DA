-- =============================================
-- MOLAP Analytical Queries (MySQL Native)
-- Cube-based queries for fast aggregation
-- =============================================

USE retail_molap;

-- Query 1: Sales by Category and Month (Cube 2)
SELECT '1. SALES BY CATEGORY AND MONTH (Cube 2)' AS Query;

SELECT 
    product_category,
    `year_month`,
    total_sales,
    total_quantity,
    transaction_count,
    ROUND(growth_pct, 2) AS growth_percent
FROM cube_sales_category_month
WHERE `year_month` >= 202401
ORDER BY product_category, `year_month`;

-- Query 2: Product Hierarchy Drill-Down (Cube 5)
SELECT '2. PRODUCT HIERARCHY DRILL-DOWN' AS Query;

SELECT 
    level_type,
    level_name,
    parent_value,
    ROUND(total_sales, 2) AS total_sales,
    total_quantity,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(sales_share_pct, 2) AS sales_share_percent
FROM cube_product_hierarchy
WHERE level_type IN ('CATEGORY', 'PRODUCT')
ORDER BY FIELD(level_type, 'CATEGORY', 'PRODUCT'), total_sales DESC;

-- Query 3: Store Geography Rollup (Cube 6)
SELECT '3. STORE GEOGRAPHY ROLLUP' AS Query;

SELECT 
    level_type,
    level_name,
    parent_value,
    ROUND(total_sales, 2) AS total_sales,
    transaction_count,
    unique_customers,
    ROUND(avg_ticket_size, 2) AS avg_ticket_size
FROM cube_store_hierarchy
ORDER BY FIELD(level_type, 'ALL', 'CLUSTER', 'STATE', 'CITY', 'STORE'), total_sales DESC;

-- Query 4: Time Series with Moving Averages (Cube 4)
SELECT '4. TIME SERIES WITH MOVING AVERAGES' AS Query;

SELECT 
    time_label,
    ROUND(total_sales, 2) AS total_sales,
    transaction_count,
    unique_customers,
    ROUND(moving_avg_7d, 2) AS moving_avg_7d,
    ROUND(moving_avg_30d, 2) AS moving_avg_30d
FROM cube_time_series
WHERE time_level = 'DAY'
  AND start_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
ORDER BY start_date DESC;

-- Query 5: Customer Segment vs Store Type (Cube 3)
SELECT '5. CUSTOMER SEGMENT VS STORE TYPE' AS Query;

SELECT 
    customer_segment,
    store_type,
    year_val,
    ROUND(total_sales, 2) AS total_sales,
    transaction_count,
    unique_customers,
    ROUND(avg_order_value, 2) AS avg_order_value
FROM cube_sales_segment_storetype
WHERE year_val = YEAR(CURDATE())
ORDER BY customer_segment, total_sales DESC;

-- Query 6: Customer Segmentation Cube (Cube 7)
SELECT '6. CUSTOMER SEGMENTATION DETAILS' AS Query;

SELECT 
    customer_segment,
    age_group,
    city_tier,
    loyalty_member,
    customer_count,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(avg_order_value, 2) AS avg_order_value,
    ROUND(avg_transactions_per_customer, 2) AS avg_transactions
FROM cube_customer_segmentation
WHERE total_sales > 0
ORDER BY customer_segment, total_sales DESC;

-- Query 7: Pivot/Slice Query - Monthly Sales by Category
SELECT '7. PIVOT: MONTHLY SALES BY CATEGORY' AS Query;

SELECT 
    product_category,
    MAX(CASE WHEN month_val = 1 THEN total_sales ELSE 0 END) AS Jan,
    MAX(CASE WHEN month_val = 2 THEN total_sales ELSE 0 END) AS Feb,
    MAX(CASE WHEN month_val = 3 THEN total_sales ELSE 0 END) AS Mar,
    MAX(CASE WHEN month_val = 4 THEN total_sales ELSE 0 END) AS Apr,
    MAX(CASE WHEN month_val = 5 THEN total_sales ELSE 0 END) AS May,
    MAX(CASE WHEN month_val = 6 THEN total_sales ELSE 0 END) AS Jun,
    MAX(CASE WHEN month_val = 7 THEN total_sales ELSE 0 END) AS Jul,
    MAX(CASE WHEN month_val = 8 THEN total_sales ELSE 0 END) AS Aug,
    MAX(CASE WHEN month_val = 9 THEN total_sales ELSE 0 END) AS Sep,
    MAX(CASE WHEN month_val = 10 THEN total_sales ELSE 0 END) AS Oct,
    MAX(CASE WHEN month_val = 11 THEN total_sales ELSE 0 END) AS Nov,
    MAX(CASE WHEN month_val = 12 THEN total_sales ELSE 0 END) AS `Dec`,
    SUM(total_sales) AS Total
FROM cube_sales_category_month
WHERE year_val = 2024
GROUP BY product_category WITH ROLLUP;

-- Query 8: Year-over-Year Comparison
SELECT '8. YEAR-OVER-YEAR COMPARISON' AS Query;

SELECT 
    c1.product_category,
    c1.year_month,
    c1.total_sales AS current_year_sales,
    c2.total_sales AS previous_year_sales,
    ROUND(((c1.total_sales - c2.total_sales) / NULLIF(c2.total_sales, 0)) * 100, 2) AS yoy_growth_pct
FROM cube_sales_category_month c1
LEFT JOIN cube_sales_category_month c2 
    ON c1.product_category = c2.product_category 
    AND c1.year_month = c2.year_month + 100
WHERE c1.year_val = 2024
ORDER BY c1.product_category, c1.year_month;