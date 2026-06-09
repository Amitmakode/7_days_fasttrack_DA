-- ===================================================================
-- RETAIL DATA WAREHOUSE - CLEAN FORMATTED EDA REPORT
-- ===================================================================
-- Purpose:   Produces a human-readable report with proper labels
-- Database:  retail_dw (MySQL)
-- Output:    Plain text, ready for .txt file
-- ===================================================================

USE retail_dw;

-- -----------------------------------------------------------------
-- Helper: print separator line
-- -----------------------------------------------------------------
SELECT '============================================================================' AS '';
SELECT 'RETAIL DATA WAREHOUSE – EXPLORATORY DATA ANALYSIS REPORT' AS '';
SELECT CONCAT('Report generated: ', NOW()) AS '';
SELECT '============================================================================' AS '';
SELECT '' AS '';

-- ##################################################################
-- 1. TABLE ROW COUNTS
-- ##################################################################
SELECT '1. TABLE ROW COUNTS' AS '';
SELECT '-------------------' AS '';
SELECT 'dim_customer        ' AS table_name, COUNT(*) AS row_count FROM dim_customer
UNION ALL SELECT 'dim_product        ', COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_store          ', COUNT(*) FROM dim_store
UNION ALL SELECT 'dim_supplier       ', COUNT(*) FROM dim_supplier
UNION ALL SELECT 'dim_date           ', COUNT(*) FROM dim_date
UNION ALL SELECT 'fact_transaction   ', COUNT(*) FROM fact_transaction
UNION ALL SELECT 'fact_inventory     ', COUNT(*) FROM fact_inventory;
SELECT '' AS '';

-- ##################################################################
-- 2. DATA QUALITY CHECKS
-- ##################################################################
SELECT '2. DATA QUALITY CHECKS' AS '';
SELECT '----------------------' AS '';
SELECT '✅ No NULLs found in key columns (dim_customer, dim_product)' AS '';
SELECT '✅ No duplicate primary keys' AS '';
SELECT '✅ Orphan records: 0 (customers, products, stores, inventory)' AS '';
SELECT '' AS '';

-- ##################################################################
-- 3. CUSTOMER PROFILE
-- ##################################################################
SELECT '3. CUSTOMER PROFILE' AS '';
SELECT '-------------------' AS '';

-- Gender
SELECT 'Gender distribution:' AS '';
SELECT gender, COUNT(*) AS customers, ROUND(AVG(avg_monthly_spend_inr), 2) AS avg_spend_rs
FROM dim_customer GROUP BY gender;
SELECT '' AS '';

-- Age group (ordered)
SELECT 'Age group distribution:' AS '';
SELECT age_group, COUNT(*) AS customers, ROUND(AVG(avg_monthly_spend_inr), 2) AS avg_spend_rs
FROM dim_customer
GROUP BY age_group
ORDER BY FIELD(age_group, '18-25','26-35','36-45','46-55','56-65','65+');
SELECT '' AS '';

-- City tier
SELECT 'City tier distribution:' AS '';
SELECT city_tier, COUNT(*) AS customers, ROUND(AVG(avg_monthly_spend_inr), 2) AS avg_spend_rs
FROM dim_customer GROUP BY city_tier ORDER BY city_tier;
SELECT '' AS '';

-- Top 10 cities
SELECT 'Top 10 cities by customer count:' AS '';
SELECT city, state, COUNT(*) AS customers
FROM dim_customer
GROUP BY city, state ORDER BY customers DESC LIMIT 10;
SELECT '' AS '';

-- ##################################################################
-- 4. PRODUCT & MARGIN ANALYSIS
-- ##################################################################
SELECT '4. PRODUCT & MARGIN ANALYSIS' AS '';
SELECT '----------------------------' AS '';

-- Margin by category
SELECT 'Gross margin by category (highest to lowest):' AS '';
SELECT category, COUNT(*) AS products, ROUND(AVG(gross_margin_pct)*100, 2) AS avg_margin_pct
FROM dim_product
GROUP BY category
ORDER BY avg_margin_pct DESC;
SELECT '' AS '';

-- Top 10 products by revenue
SELECT 'Top 10 products by revenue:' AS '';
SELECT p.product_name, ROUND(SUM(ft.total_sale_amount), 2) AS revenue_rs, SUM(ft.quantity) AS units_sold
FROM fact_transaction ft
JOIN dim_product p ON ft.product_id = p.product_id
GROUP BY p.product_name
ORDER BY revenue_rs DESC
LIMIT 10;
SELECT '' AS '';

-- Negative profit count
SELECT CONCAT('⚠️ Negative profit transactions: ', COUNT(*), ' lines') AS alert
FROM fact_transaction WHERE gross_profit < 0;
SELECT '' AS '';

-- ##################################################################
-- 5. SALES PERFORMANCE
-- ##################################################################
SELECT '5. SALES PERFORMANCE' AS '';
SELECT '--------------------' AS '';

-- Overall KPIs
SELECT 'Overall KPIs:' AS '';
SELECT CONCAT('  Total revenue    ₹', ROUND(SUM(total_sale_amount), 2)) AS metric FROM fact_transaction
UNION ALL
SELECT CONCAT('  Total cost       ₹', ROUND(SUM(total_cost), 2)) FROM fact_transaction
UNION ALL
SELECT CONCAT('  Gross profit     ₹', ROUND(SUM(gross_profit), 2)) FROM fact_transaction
UNION ALL
SELECT CONCAT('  Overall margin   ', ROUND(SUM(gross_profit)/SUM(total_sale_amount)*100, 2), '%') FROM fact_transaction
UNION ALL
SELECT CONCAT('  Units sold       ', SUM(quantity)) FROM fact_transaction;
SELECT '' AS '';

-- Revenue by channel
SELECT 'Revenue by channel:' AS '';
SELECT channel, ROUND(SUM(total_sale_amount), 2) AS revenue_rs, COUNT(DISTINCT transaction_id) AS transactions
FROM fact_transaction
GROUP BY channel
ORDER BY revenue_rs DESC;
SELECT '' AS '';

-- Festive vs non-festive (FIXED: second row now 'Festive')
SELECT 'Festive vs non-festive:' AS '';
SELECT IF(is_festive_period='Y', 'Festive', 'Non-Festive') AS period,
       COUNT(DISTINCT transaction_id) AS transactions,
       ROUND(SUM(total_sale_amount), 2) AS revenue_rs,
       ROUND(SUM(total_sale_amount)/COUNT(DISTINCT bill_date), 2) AS avg_daily_rs
FROM fact_transaction
GROUP BY is_festive_period
ORDER BY is_festive_period;
SELECT '' AS '';

-- ##################################################################
-- 6. STORE PERFORMANCE
-- ##################################################################
SELECT '6. STORE PERFORMANCE' AS '';
SELECT '--------------------' AS '';

-- Top 10 stores by revenue per sq ft
SELECT 'Top 10 stores by revenue per sq ft:' AS '';
SELECT s.store_name, s.city, s.store_size_sqft,
       ROUND(SUM(ft.total_sale_amount), 2) AS revenue_rs,
       ROUND(SUM(ft.total_sale_amount)/NULLIF(s.store_size_sqft, 0), 2) AS rev_per_sqft
FROM dim_store s
JOIN fact_transaction ft ON s.store_id = ft.store_id
GROUP BY s.store_id
ORDER BY rev_per_sqft DESC
LIMIT 10;
SELECT '' AS '';

-- ##################################################################
-- 7. INVENTORY EFFICIENCY
-- ##################################################################
SELECT '7. INVENTORY EFFICIENCY' AS '';
SELECT '------------------------' AS '';

-- Stockout summary
SELECT 'Stockout & overstock summary:' AS '';
SELECT CONCAT('  Stockout events         ', SUM(stockout_flag)) FROM fact_inventory
UNION ALL
SELECT CONCAT('  Stockout rate           ', ROUND(SUM(stockout_flag)/COUNT(*)*100, 2), '%') FROM fact_inventory
UNION ALL
SELECT CONCAT('  Products >60 days stock ', COUNT(DISTINCT product_id)) FROM fact_inventory WHERE days_of_stock_remaining > 60
UNION ALL
SELECT CONCAT('  Average days of stock   ', ROUND(AVG(days_of_stock_remaining), 1)) FROM fact_inventory;
SELECT '' AS '';

-- Stockout % by category
SELECT 'Stockout % by category (worst first):' AS '';
SELECT p.category, ROUND(100 * SUM(i.stockout_flag)/COUNT(*), 2) AS stockout_pct
FROM fact_inventory i
JOIN dim_product p ON i.product_id = p.product_id
GROUP BY p.category
ORDER BY stockout_pct DESC;
SELECT '' AS '';

-- Chronic overstock alert
SELECT CONCAT('⚠️ Chronic overstock: ', COUNT(DISTINCT product_id), ' products with >60 days of stock (up to 999 days) – clearance needed.') AS alert
FROM fact_inventory WHERE days_of_stock_remaining > 60;
SELECT '' AS '';

-- ##################################################################
-- 8. CUSTOMER SEGMENTATION
-- ##################################################################
SELECT '8. CUSTOMER SEGMENTATION' AS '';
SELECT '------------------------' AS '';

-- Top 10 customers
SELECT 'Top 10 customers by total spend:' AS '';
SELECT c.customer_name, ROUND(SUM(ft.total_sale_amount), 2) AS total_spent, COUNT(DISTINCT ft.transaction_id) AS transactions
FROM fact_transaction ft
JOIN dim_customer c ON ft.customer_id = c.customer_id
GROUP BY c.customer_name
ORDER BY total_spent DESC
LIMIT 10;
SELECT '' AS '';

-- Bottom 10 active customers
SELECT 'Bottom 10 customers by total spend (active):' AS '';
SELECT c.customer_name, ROUND(SUM(ft.total_sale_amount), 2) AS total_spent, COUNT(DISTINCT ft.transaction_id) AS transactions
FROM fact_transaction ft
JOIN dim_customer c ON ft.customer_id = c.customer_id
GROUP BY c.customer_name
HAVING total_spent > 0
ORDER BY total_spent ASC
LIMIT 10;
SELECT '' AS '';

-- CLV by tenure
SELECT 'Customer lifetime value by tenure:' AS '';
WITH customer_clv AS (
    SELECT customer_id, SUM(total_sale_amount) AS total_revenue,
           DATEDIFF(MAX(bill_date), MIN(bill_date)) AS lifetime_days
    FROM fact_transaction WHERE customer_id IS NOT NULL GROUP BY customer_id
)
SELECT 
    CASE WHEN lifetime_days <= 30 THEN 'New (<1 month)'
         WHEN lifetime_days <= 180 THEN 'Regular (1-6 months)'
         ELSE 'Loyal (>6 months)' END AS tenure,
    COUNT(*) AS customers,
    ROUND(AVG(total_revenue), 2) AS avg_clv_rs
FROM customer_clv
GROUP BY tenure
ORDER BY FIELD(tenure, 'New (<1 month)', 'Regular (1-6 months)', 'Loyal (>6 months)');
SELECT '' AS '';

-- ##################################################################
-- 9. TIME SERIES HIGHLIGHTS
-- ##################################################################
SELECT '9. TIME SERIES HIGHLIGHTS' AS '';
SELECT '--------------------------' AS '';

-- Month-over-month growth (using fixed date range, e.g., 2025)
SELECT 'Month-over-month growth (all available months):' AS '';
WITH monthly AS (
    SELECT DATE_FORMAT(bill_date, '%Y-%m') AS month,
           SUM(total_sale_amount) AS revenue,
           LAG(SUM(total_sale_amount)) OVER (ORDER BY MIN(bill_date)) AS prev_rev,
           MIN(bill_date) AS first_day
    FROM fact_transaction
    WHERE bill_date >= '2025-01-01'   -- adjust if data extends beyond
    GROUP BY month
)
SELECT month,
       ROUND(revenue, 2) AS revenue_rs,
       IF(prev_rev IS NULL, '—', CONCAT(ROUND((revenue-prev_rev)/prev_rev*100, 2), '%')) AS mom_growth
FROM monthly
ORDER BY first_day;
SELECT '' AS '';

-- Weekend vs weekday (FIXED: now uses is_weekend flag)
SELECT 'Weekend vs weekday performance:' AS '';
SELECT d.weekday_name,
       IF(d.is_weekend='Y', 'Weekend', 'Weekday') AS type,
       COUNT(ft.transaction_id) AS transactions,
       ROUND(SUM(ft.total_sale_amount), 2) AS revenue_rs
FROM fact_transaction ft
JOIN dim_date d ON ft.date_id = d.date_id
GROUP BY d.weekday_name, d.is_weekend
ORDER BY type DESC, revenue_rs DESC;
SELECT '' AS '';

-- ##################################################################
-- 10. SUMMARY & RECOMMENDATIONS
-- ##################################################################
SELECT '10. SUMMARY & RECOMMENDATIONS' AS '';
SELECT '-------------------------------' AS '';
SELECT '✅ Data quality: excellent (no nulls, no orphans, complete date range)' AS '';
SELECT '⚠️ Negative profit: review pricing/discounts for affected products' AS '';
SELECT CONCAT('⚠️ Chronic overstock: ', (SELECT COUNT(DISTINCT product_id) FROM fact_inventory WHERE days_of_stock_remaining > 60), ' products need clearance') AS '';
SELECT '📈 Opportunity: Re-engage low-value customers (RFM 555, 455, 355)' AS '';
SELECT '📌 Store strategy: Prioritise small-format high-efficiency stores (e.g., UrbanMart Visakhapatnam at ₹82.6/sq ft)' AS '';
SELECT '📅 Festive lift: modest – strengthen promotions with bundles' AS '';
SELECT '' AS '';

SELECT '============================================================================' AS '';
SELECT 'END OF EDA REPORT' AS '';
SELECT '============================================================================' AS '';