-- =============================================
-- ROLAP Analytical Queries (MySQL Native)
-- =============================================

USE retail_rolap;

-- Query 1: Daily Sales Trend (Last 30 days)
SELECT '1. DAILY SALES TREND (Last 30 days)' AS Query;

SELECT 
    d.full_date,
    d.weekday_name,
    COALESCE(SUM(fs.sale_amount), 0) AS daily_sales,
    COUNT(DISTINCT fs.transaction_id) AS orders,
    COUNT(DISTINCT fs.customer_key) AS unique_customers,
    ROUND(COALESCE(SUM(fs.sale_amount), 0) / NULLIF(COUNT(DISTINCT fs.transaction_id), 0), 2) AS avg_order_value
FROM dim_date d
LEFT JOIN fact_sales fs ON d.date_id = fs.date_id
WHERE d.full_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
AND d.full_date <= CURDATE()
GROUP BY d.date_id, d.full_date, d.weekday_name
ORDER BY d.full_date DESC;

-- Query 2: Top Categories by Sales
SELECT '2. TOP CATEGORIES BY SALES' AS Query;

SELECT 
    dp.category,
    SUM(fs.sale_amount) AS total_sales,
    SUM(fs.quantity) AS units_sold,
    COUNT(DISTINCT fs.transaction_id) AS orders,
    ROUND(AVG(fs.margin_pct), 2) AS avg_margin_pct,
    ROUND(SUM(fs.profit), 2) AS total_profit
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
GROUP BY dp.category
ORDER BY total_sales DESC
LIMIT 10;

-- Query 3: Store Performance Dashboard
SELECT '3. STORE PERFORMANCE DASHBOARD' AS Query;

SELECT 
    ds.store_name,
    ds.city,
    ds.store_type,
    SUM(fs.sale_amount) AS total_sales,
    COUNT(DISTINCT fs.transaction_id) AS order_count,
    COUNT(DISTINCT fs.customer_key) AS unique_customers,
    ROUND(AVG(fs.sale_amount), 2) AS avg_ticket_size,
    ROUND(SUM(fs.profit), 2) AS total_profit
FROM fact_sales fs
JOIN dim_store ds ON fs.store_key = ds.store_key
GROUP BY ds.store_key, ds.store_name, ds.city, ds.store_type
ORDER BY total_sales DESC;

-- Query 4: Customer Segmentation Analysis
SELECT '4. CUSTOMER SEGMENTATION ANALYSIS' AS Query;

SELECT 
    dc.customer_segment,
    COUNT(DISTINCT dc.customer_key) AS customer_count,
    SUM(fs.sale_amount) AS total_sales,
    COUNT(DISTINCT fs.transaction_id) AS total_orders,
    ROUND(SUM(fs.sale_amount) / NULLIF(COUNT(DISTINCT dc.customer_key), 0), 2) AS avg_spend_per_customer,
    ROUND(AVG(fs.sale_amount), 2) AS avg_order_value
FROM dim_customer dc
LEFT JOIN fact_sales fs ON dc.customer_key = fs.customer_key
GROUP BY dc.customer_segment
ORDER BY total_sales DESC;

-- Query 5: Monthly Category Performance with Ranking
SELECT '5. MONTHLY CATEGORY PERFORMANCE' AS Query;

SELECT 
    `year_month`,
    category,
    total_sales,
    total_quantity,
    sales_rank,
    ROUND((total_profit / NULLIF(total_sales, 0)) * 100, 2) AS margin_pct
FROM agg_monthly_category_sales
WHERE `year_month` >= YEAR(CURDATE()) * 100 + 1
ORDER BY `year_month` DESC, sales_rank;

-- Query 6: Customer Lifetime Value Analysis
SELECT '6. CUSTOMER LIFETIME VALUE ANALYSIS' AS Query;

SELECT 
    lifetime_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_spend), 2) AS avg_lifetime_value,
    ROUND(AVG(total_transactions), 1) AS avg_transactions,
    ROUND(AVG(avg_order_value), 2) AS avg_order_value,
    ROUND(AVG(days_since_last_purchase), 1) AS avg_days_inactive
FROM agg_customer_lifetime
GROUP BY lifetime_segment
ORDER BY avg_lifetime_value DESC;

-- Query 7: Best Selling Products
SELECT '7. BEST SELLING PRODUCTS (Last 90 days)' AS Query;

SELECT 
    dp.product_name,
    dp.brand,
    dp.category,
    SUM(fs.sale_amount) AS revenue,
    SUM(fs.quantity) AS units_sold,
    COUNT(DISTINCT fs.transaction_id) AS order_count,
    ROUND(AVG(fs.margin_pct), 2) AS avg_margin
FROM fact_sales fs
JOIN dim_product dp ON fs.product_key = dp.product_key
WHERE fs.date_id >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 90 DAY), '%Y%m%d')
GROUP BY dp.product_key, dp.product_name, dp.brand, dp.category
ORDER BY revenue DESC
LIMIT 20;

-- Query 8: Hourly Sales Pattern
SELECT '8. HOURLY SALES PATTERN' AS Query;

SELECT 
    HOUR(so.order_date) AS hour_of_day,
    COUNT(*) AS order_count,
    ROUND(AVG(so.net_amount), 2) AS avg_order_value,
    SUM(so.net_amount) AS total_sales
FROM retail_oltp.sales_orders so
WHERE so.order_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
    AND so.status_id = 3
GROUP BY HOUR(so.order_date)
ORDER BY hour_of_day;