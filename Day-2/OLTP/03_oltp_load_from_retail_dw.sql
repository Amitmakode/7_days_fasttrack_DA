-- =============================================
-- STEP 2: One-Time Load from retail_dw to OLTP
-- This is the ONLY load from retail_dw
-- After this, retail_dw will be deprecated
-- =============================================

USE retail_oltp;

DELIMITER $$

CREATE PROCEDURE sp_one_time_load_from_retail_dw()
BEGIN
    DECLARE v_start_time DATETIME;
    DECLARE v_records INT DEFAULT 0;
    
    SET v_start_time = NOW();
    
    SELECT '=========================================' AS '';
    SELECT 'ONE-TIME LOAD FROM retail_dw TO OLTP' AS '';
    SELECT '=========================================' AS '';
    SELECT 'WARNING: This will be the only load from retail_dw' AS '';
    SELECT 'After this, retail_dw will be deprecated' AS '';
    SELECT '=========================================' AS '';
    
    START TRANSACTION;
    
    -- =============================================
    -- 1. Load Categories
    -- =============================================
    SELECT '1. Loading categories...' AS Step;
    
    INSERT INTO categories (category_name, level)
    SELECT DISTINCT category, 1
    FROM retail_dw.dim_product
    WHERE category IS NOT NULL
    ON DUPLICATE KEY UPDATE 
        category_name = VALUES(category_name);
    
    INSERT INTO categories (category_name, parent_category_id, level)
    SELECT DISTINCT 
        dp.sub_category,
        c.category_id,
        2
    FROM retail_dw.dim_product dp
    INNER JOIN categories c ON dp.category = c.category_name AND c.level = 1
    WHERE dp.sub_category IS NOT NULL
    ON DUPLICATE KEY UPDATE 
        category_name = VALUES(category_name);
    
    INSERT INTO categories (category_name, parent_category_id, level)
    SELECT DISTINCT 
        dp.sub_sub_category,
        c.category_id,
        3
    FROM retail_dw.dim_product dp
    INNER JOIN categories c ON dp.sub_category = c.category_name AND c.level = 2
    WHERE dp.sub_sub_category IS NOT NULL
    ON DUPLICATE KEY UPDATE 
        category_name = VALUES(category_name);
    
    SELECT CONCAT('   Categories loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    -- =============================================
    -- 2. Load Brands
    -- =============================================
    SELECT '2. Loading brands...' AS Step;
    
    INSERT INTO brands (brand_name)
    SELECT DISTINCT brand
    FROM retail_dw.dim_product
    WHERE brand IS NOT NULL
    ON DUPLICATE KEY UPDATE 
        brand_name = VALUES(brand_name);
    
    SELECT CONCAT('   Brands loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    -- =============================================
    -- 3. Load Suppliers
    -- =============================================
    SELECT '3. Loading suppliers...' AS Step;
    
    INSERT INTO suppliers (
        supplier_code, supplier_name, supplier_type, city, state,
        payment_days, lead_time_days, annual_contract_value_lakh,
        is_preferred_vendor, years_associated
    )
    SELECT 
        supplier_id,
        supplier_name,
        supplier_type,
        city,
        state,
        COALESCE(payment_days, 30),
        COALESCE(lead_time_days, 7),
        annual_contract_value_lakh,
        CASE WHEN is_preferred_vendor = 'Yes' OR is_preferred_vendor = 'TRUE' THEN TRUE ELSE FALSE END,
        COALESCE(years_associated, 0)
    FROM retail_dw.dim_supplier
    ON DUPLICATE KEY UPDATE 
        supplier_name = VALUES(supplier_name),
        payment_days = VALUES(payment_days);
    
    SELECT CONCAT('   Suppliers loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    -- =============================================
    -- 4. Load Stores
    -- =============================================
    SELECT '4. Loading stores...' AS Step;
    
    INSERT INTO stores (
        store_code, store_name, city, state, city_tier, 
        cluster_zone, store_type, store_size_sqft, opening_date
    )
    SELECT 
        store_id,
        store_name,
        city,
        state,
        city_tier,
        cluster_zone,
        store_type,
        store_size_sqft,
        opening_date
    FROM retail_dw.dim_store
    ON DUPLICATE KEY UPDATE 
        store_name = VALUES(store_name),
        store_type = VALUES(store_type);
    
    SELECT CONCAT('   Stores loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    -- =============================================
    -- 5. Load Customers
    -- =============================================
    SELECT '5. Loading customers...' AS Step;
    
    INSERT INTO customers (
        customer_code, customer_name, gender, age_group, city, state,
        city_tier, is_registered, loyalty_member, 
        avg_monthly_spend_inr, visit_frequency_per_month, registration_date
    )
    SELECT 
        customer_id,
        customer_name,
        CASE 
            WHEN gender = 'Male' THEN 'M'
            WHEN gender = 'Female' THEN 'F'
            ELSE 'O'
        END,
        age_group,
        city,
        state,
        city_tier,
        CASE WHEN is_registered = 'Yes' OR is_registered = 'TRUE' THEN TRUE ELSE FALSE END,
        CASE WHEN loyalty_member = 'Yes' OR loyalty_member = 'TRUE' THEN TRUE ELSE FALSE END,
        COALESCE(avg_monthly_spend_inr, 0),
        COALESCE(visit_frequency_per_month, 1),
        DATE_SUB(CURDATE(), INTERVAL FLOOR(RAND() * 1000) DAY)
    FROM retail_dw.dim_customer
    ON DUPLICATE KEY UPDATE 
        customer_name = VALUES(customer_name),
        avg_monthly_spend_inr = VALUES(avg_monthly_spend_inr);
    
    SELECT CONCAT('   Customers loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    -- =============================================
    -- 6. Load Products
    -- =============================================
    SELECT '6. Loading products...' AS Step;
    
    INSERT INTO products (
        product_code, product_name, brand_id, category_id, sub_category_id,
        mrp, cost_price, is_perishable, veg_nonveg, max_qty_per_transaction
    )
    SELECT 
        dp.product_id,
        dp.product_name,
        b.brand_id,
        cat.category_id,
        subcat.category_id,
        dp.mrp,
        dp.cost_price,
        CASE WHEN dp.is_perishable = 'Yes' OR dp.is_perishable = 'TRUE' THEN TRUE ELSE FALSE END,
        dp.veg_nonveg,
        COALESCE(dp.max_qty_per_transaction, 10)
    FROM retail_dw.dim_product dp
    LEFT JOIN brands b ON dp.brand = b.brand_name
    LEFT JOIN categories cat ON dp.category = cat.category_name AND cat.level = 1
    LEFT JOIN categories subcat ON dp.sub_category = subcat.category_name AND subcat.level = 2
    ON DUPLICATE KEY UPDATE 
        product_name = VALUES(product_name),
        mrp = VALUES(mrp),
        cost_price = VALUES(cost_price);
    
    SELECT CONCAT('   Products loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    -- =============================================
    -- 7. Load Product-Supplier Relationships
    -- =============================================
    SELECT '7. Loading product-supplier relationships...' AS Step;
    
    INSERT INTO product_suppliers (product_id, supplier_id, is_primary, cost_price)
    SELECT 
        p.product_id,
        s.supplier_id,
        TRUE,
        p.cost_price
    FROM products p
    CROSS JOIN suppliers s
    WHERE s.supplier_code IN (SELECT DISTINCT supplier_id FROM retail_dw.dim_supplier)
    AND NOT EXISTS (
        SELECT 1 FROM product_suppliers ps 
        WHERE ps.product_id = p.product_id AND ps.supplier_id = s.supplier_id
    )
    LIMIT 10000;
    
    SELECT CONCAT('   Product-supplier relationships loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    -- =============================================
    -- 8. Load Sales Orders
    -- =============================================
    SELECT '8. Loading sales orders...' AS Step;
    
    INSERT INTO sales_orders (
        order_number, customer_id, store_id, order_date, 
        status_id, payment_mode_id, total_amount, discount_amount, net_amount
    )
    SELECT 
        ft.transaction_id,
        c.customer_id,
        s.store_id,
        ft.bill_date,
        3,
        pm.payment_mode_id,
        SUM(ft.total_sale_amount),
        SUM(ft.discount_amount),
        SUM(ft.total_sale_amount)
    FROM retail_dw.fact_transaction ft
    JOIN customers c ON ft.customer_id = c.customer_code
    JOIN stores s ON ft.store_id = s.store_code
    JOIN lookup_payment_mode pm ON ft.payment_mode = pm.payment_mode_name
    WHERE ft.transaction_id IS NOT NULL
    GROUP BY ft.transaction_id, c.customer_id, s.store_id, ft.bill_date, pm.payment_mode_id
    ON DUPLICATE KEY UPDATE 
        total_amount = VALUES(total_amount);
    
    SELECT CONCAT('   Sales orders loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    -- =============================================
    -- 9. Load Sales Order Items
    -- =============================================
    SELECT '9. Loading sales order items...' AS Step;
    
    INSERT INTO sales_order_items (
        order_id, product_id, quantity, unit_price, 
        discount_percent, discount_amount, net_price
    )
    SELECT 
        so.order_id,
        p.product_id,
        ft.quantity,
        ft.mrp,
        ft.discount_pct,
        ft.discount_amount,
        ft.total_sale_amount
    FROM retail_dw.fact_transaction ft
    JOIN sales_orders so ON ft.transaction_id = so.order_number
    JOIN products p ON ft.product_id = p.product_code
    ON DUPLICATE KEY UPDATE 
        quantity = VALUES(quantity);
    
    SELECT CONCAT('   Sales order items loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    -- =============================================
    -- 10. Load Inventory
    -- =============================================
    SELECT '10. Loading inventory...' AS Step;
    
    INSERT INTO inventory (product_id, store_id, quantity_on_hand, reorder_point)
    SELECT 
        p.product_id,
        s.store_id,
        COALESCE(fi.closing_stock_units, 0),
        10
    FROM retail_dw.fact_inventory fi
    JOIN products p ON fi.product_id = p.product_code
    JOIN stores s ON fi.store_id = s.store_code
    WHERE fi.week_start_date = (
        SELECT MAX(week_start_date) FROM retail_dw.fact_inventory fi2 
        WHERE fi2.product_id = fi.product_id AND fi2.store_id = fi.store_id
    )
    ON DUPLICATE KEY UPDATE 
        quantity_on_hand = VALUES(quantity_on_hand);
    
    SELECT CONCAT('   Inventory loaded: ', ROW_COUNT(), ' rows') AS Result;
    
    COMMIT;
    
    -- =============================================
    -- Final Summary
    -- =============================================
    SELECT '=========================================' AS '';
    SELECT 'ONE-TIME LOAD COMPLETED SUCCESSFULLY' AS '';
    SELECT '=========================================' AS '';
    SELECT CONCAT('Total records loaded: ', 
        (SELECT COUNT(*) FROM customers) +
        (SELECT COUNT(*) FROM products) +
        (SELECT COUNT(*) FROM stores) +
        (SELECT COUNT(*) FROM sales_orders)
    ) AS Total_Records;
    
    SELECT 'Final Record Counts:' AS Section;
    SELECT 'categories' AS Table_Name, COUNT(*) AS Records FROM categories
    UNION ALL SELECT 'brands', COUNT(*) FROM brands
    UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
    UNION ALL SELECT 'stores', COUNT(*) FROM stores
    UNION ALL SELECT 'customers', COUNT(*) FROM customers
    UNION ALL SELECT 'products', COUNT(*) FROM products
    UNION ALL SELECT 'sales_orders', COUNT(*) FROM sales_orders
    UNION ALL SELECT 'sales_order_items', COUNT(*) FROM sales_order_items
    UNION ALL SELECT 'inventory', COUNT(*) FROM inventory;
    
    SELECT CONCAT('Load completed in ', TIMESTAMPDIFF(SECOND, v_start_time, NOW()), ' seconds') AS Duration;
    
END$$

DELIMITER ;

-- Execute the one-time load
CALL sp_one_time_load_from_retail_dw();