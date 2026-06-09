-- =============================================
-- QUICK REFERENCE QUERIES
-- For validating OLTP after migration
-- =============================================

USE retail_oltp;

-- Quick Counts
SELECT '=== OLTP QUICK STATS ===' AS '';
SELECT 'Customers' AS Metric, COUNT(*) AS Value FROM customers
UNION ALL SELECT 'Products', COUNT(*) FROM products
UNION ALL SELECT 'Stores', COUNT(*) FROM stores
UNION ALL SELECT 'Suppliers', COUNT(*) FROM suppliers
UNION ALL SELECT 'Categories', COUNT(*) FROM categories
UNION ALL SELECT 'Brands', COUNT(*) FROM brands
UNION ALL SELECT 'Sales Orders', COUNT(*) FROM sales_orders
UNION ALL SELECT 'Order Items', COUNT(*) FROM sales_order_items
UNION ALL SELECT 'Inventory Records', COUNT(*) FROM inventory;

-- Date Range of Data
SELECT '=== DATA DATE RANGE ===' AS '';
SELECT 
    MIN(order_date) AS earliest_order,
    MAX(order_date) AS latest_order,
    DATEDIFF(MAX(order_date), MIN(order_date)) AS date_span_days
FROM sales_orders;

-- Top 5 Customers by Spend
SELECT '=== TOP 5 CUSTOMERS ===' AS '';
SELECT 
    c.customer_name,
    c.city,
    COUNT(so.order_id) AS order_count,
    SUM(so.net_amount) AS total_spent
FROM customers c
JOIN sales_orders so ON c.customer_id = so.customer_id
GROUP BY c.customer_id, c.customer_name, c.city
ORDER BY total_spent DESC
LIMIT 5;

-- Top 5 Products by Sales
SELECT '=== TOP 5 PRODUCTS ===' AS '';
SELECT 
    p.product_name,
    b.brand_name,
    SUM(soi.quantity) AS units_sold,
    SUM(soi.net_price) AS revenue
FROM products p
JOIN brands b ON p.brand_id = b.brand_id
JOIN sales_order_items soi ON p.product_id = soi.product_id
GROUP BY p.product_id, p.product_name, b.brand_name
ORDER BY revenue DESC
LIMIT 5;

SELECT '=== OLTP IS READY FOR USE ===' AS '';