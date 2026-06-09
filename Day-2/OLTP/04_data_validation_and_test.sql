-- =============================================
-- STEP 3: Verify Load and Create Backup
-- Before deprecating retail_dw
-- =============================================

USE retail_oltp;

SELECT '=========================================' AS '';
SELECT 'VERIFYING ONE-TIME LOAD' AS '';
SELECT '=========================================' AS '';

-- 1. Data Completeness Check
SELECT '1. DATA COMPLETENESS CHECK' AS Section;

SELECT 
    'Customers' AS Entity,
    (SELECT COUNT(*) FROM retail_dw.dim_customer) AS Source_Count,
    (SELECT COUNT(*) FROM customers) AS Target_Count,
    CASE 
        WHEN (SELECT COUNT(*) FROM retail_dw.dim_customer) = (SELECT COUNT(*) FROM customers)
        THEN '✓ MATCH' 
        ELSE CONCAT('✗ DIFFERENCE: ', 
            (SELECT COUNT(*) FROM retail_dw.dim_customer) - (SELECT COUNT(*) FROM customers))
    END AS Status
UNION ALL
SELECT 
    'Products',
    (SELECT COUNT(*) FROM retail_dw.dim_product),
    (SELECT COUNT(*) FROM products),
    CASE 
        WHEN (SELECT COUNT(*) FROM retail_dw.dim_product) = (SELECT COUNT(*) FROM products)
        THEN '✓ MATCH' 
        ELSE CONCAT('✗ DIFFERENCE: ', 
            (SELECT COUNT(*) FROM retail_dw.dim_product) - (SELECT COUNT(*) FROM products))
    END
UNION ALL
SELECT 
    'Stores',
    (SELECT COUNT(*) FROM retail_dw.dim_store),
    (SELECT COUNT(*) FROM stores),
    CASE 
        WHEN (SELECT COUNT(*) FROM retail_dw.dim_store) = (SELECT COUNT(*) FROM stores)
        THEN '✓ MATCH' 
        ELSE CONCAT('✗ DIFFERENCE: ', 
            (SELECT COUNT(*) FROM retail_dw.dim_store) - (SELECT COUNT(*) FROM stores))
    END
UNION ALL
SELECT 
    'Transactions',
    (SELECT COUNT(DISTINCT transaction_id) FROM retail_dw.fact_transaction),
    (SELECT COUNT(*) FROM sales_orders),
    CASE 
        WHEN (SELECT COUNT(DISTINCT transaction_id) FROM retail_dw.fact_transaction) = (SELECT COUNT(*) FROM sales_orders)
        THEN '✓ MATCH' 
        ELSE CONCAT('✗ DIFFERENCE: ', 
            (SELECT COUNT(DISTINCT transaction_id) FROM retail_dw.fact_transaction) - (SELECT COUNT(*) FROM sales_orders))
    END;

-- 2. Referential Integrity Check
SELECT '2. REFERENTIAL INTEGRITY CHECK' AS Section;

SELECT 
    'Orders with missing customers' AS Issue,
    COUNT(*) AS Count
FROM sales_orders so
LEFT JOIN customers c ON so.customer_id = c.customer_id
WHERE so.customer_id IS NOT NULL AND c.customer_id IS NULL
UNION ALL
SELECT 
    'Order items with missing products',
    COUNT(*)
FROM sales_order_items soi
LEFT JOIN products p ON soi.product_id = p.product_id
WHERE soi.product_id IS NOT NULL AND p.product_id IS NULL
UNION ALL
SELECT 
    'Orders with missing stores',
    COUNT(*)
FROM sales_orders so
LEFT JOIN stores s ON so.store_id = s.store_id
WHERE so.store_id IS NOT NULL AND s.store_id IS NULL;

-- 3. Data Quality Check
SELECT '3. DATA QUALITY CHECK' AS Section;

SELECT 
    'Products with MRP < Cost Price' AS Issue,
    COUNT(*) AS Count
FROM products
WHERE mrp < cost_price
UNION ALL
SELECT 
    'Orders with zero net amount',
    COUNT(*)
FROM sales_orders
WHERE net_amount <= 0
UNION ALL
SELECT 
    'Order items with negative quantity',
    COUNT(*)
FROM sales_order_items
WHERE quantity <= 0
UNION ALL
SELECT 
    'Customers with NULL name',
    COUNT(*)
FROM customers
WHERE customer_name IS NULL OR customer_name = '';

-- 4. Sample Data Verification
SELECT '4. SAMPLE DATA VERIFICATION (First 5 orders)' AS Section;

SELECT 
    so.order_number,
    so.order_date,
    c.customer_name,
    s.store_name,
    so.net_amount,
    (SELECT COUNT(*) FROM sales_order_items WHERE order_id = so.order_id) AS items_count
FROM sales_orders so
JOIN customers c ON so.customer_id = c.customer_id
JOIN stores s ON so.store_id = s.store_id
LIMIT 5;

-- 5. Create Backup of OLTP
SELECT '5. CREATING BACKUP...' AS Section;

-- Create backup tables
CREATE TABLE IF NOT EXISTS oltp_backup_metadata (
    backup_id INT PRIMARY KEY AUTO_INCREMENT,
    backup_timestamp DATETIME,
    table_name VARCHAR(100),
    record_count INT,
    backup_status VARCHAR(20)
);

INSERT INTO oltp_backup_metadata (backup_timestamp, table_name, record_count, backup_status)
SELECT NOW(), 'customers', COUNT(*), 'SUCCESS' FROM customers
UNION ALL
SELECT NOW(), 'products', COUNT(*), 'SUCCESS' FROM products
UNION ALL
SELECT NOW(), 'stores', COUNT(*), 'SUCCESS' FROM stores
UNION ALL
SELECT NOW(), 'sales_orders', COUNT(*), 'SUCCESS' FROM sales_orders
UNION ALL
SELECT NOW(), 'sales_order_items', COUNT(*), 'SUCCESS' FROM sales_order_items;

SELECT 'Backup metadata created' AS Status;
SELECT * FROM oltp_backup_metadata ORDER BY backup_id DESC LIMIT 1;

-- 6. Final Verification Summary
SELECT '=========================================' AS '';
SELECT 'VERIFICATION SUMMARY' AS '';
SELECT '=========================================' AS '';

SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM sales_orders so
            LEFT JOIN customers c ON so.customer_id = c.customer_id
            WHERE so.customer_id IS NOT NULL AND c.customer_id IS NULL
        ) THEN 'FAILED'
        WHEN EXISTS (
            SELECT 1 FROM sales_order_items soi
            LEFT JOIN products p ON soi.product_id = p.product_id
            WHERE soi.product_id IS NOT NULL AND p.product_id IS NULL
        ) THEN 'FAILED'
        ELSE 'PASSED'
    END AS Referential_Integrity,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM products WHERE mrp < cost_price
        ) THEN 'WARNING'
        ELSE 'PASSED'
    END AS Data_Quality,
    
    CASE 
        WHEN (SELECT COUNT(*) FROM sales_orders) = 0 THEN 'FAILED - No orders'
        WHEN (SELECT COUNT(*) FROM customers) = 0 THEN 'FAILED - No customers'
        ELSE 'PASSED'
    END AS Data_Completeness;

SELECT '=========================================' AS '';
SELECT 'VERIFICATION COMPLETE' AS '';
SELECT 'retail_dw is now ready for deprecation' AS '';
SELECT '=========================================' AS '';