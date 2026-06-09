-- =============================================
-- MOLAP DATABASE: retail_molap
-- Multi-dimensional Cube Structures (MySQL Native)
-- =============================================

DROP DATABASE IF EXISTS retail_molap;
CREATE DATABASE retail_molap;
USE retail_molap;

-- =============================================
-- CUBE METADATA TABLES
-- =============================================

-- Cube Definitions
CREATE TABLE cube_metadata (
    cube_id INT PRIMARY KEY AUTO_INCREMENT,
    cube_name VARCHAR(100) NOT NULL,
    cube_description TEXT,
    source_fact_table VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dimension Definitions
CREATE TABLE dimension_metadata (
    dim_id INT PRIMARY KEY AUTO_INCREMENT,
    cube_id INT NOT NULL,
    dim_name VARCHAR(100) NOT NULL,
    dim_type VARCHAR(20) DEFAULT 'STANDARD',
    hierarchy_levels TEXT,
    INDEX idx_cube (cube_id)
);

-- Measure Definitions
CREATE TABLE measure_metadata (
    measure_id INT PRIMARY KEY AUTO_INCREMENT,
    cube_id INT NOT NULL,
    measure_name VARCHAR(100) NOT NULL,
    aggregation_type VARCHAR(20) DEFAULT 'SUM',
    format_string VARCHAR(50),
    INDEX idx_cube (cube_id)
);

-- =============================================
-- CUBE 1: Sales by Store x Product x Date
-- =============================================

CREATE TABLE cube_sales_store_product_date (
    cube_key BIGINT PRIMARY KEY AUTO_INCREMENT,
    store_id VARCHAR(20),
    product_id VARCHAR(20),
    date_id INT,
    year_val INT,
    quarter_val INT,
    month_val INT,
    store_city VARCHAR(100),
    store_state VARCHAR(100),
    product_category VARCHAR(100),
    product_brand VARCHAR(100),
    total_sales DECIMAL(14,2),
    total_quantity INT,
    transaction_count INT,
    unique_customers INT,
    total_profit DECIMAL(14,2),
    avg_margin_pct DECIMAL(8,4),
    INDEX idx_store (store_id),
    INDEX idx_product (product_id),
    INDEX idx_date (date_id),
    INDEX idx_year (year_val),
    INDEX idx_category (product_category),
    INDEX idx_city (store_city)
);

-- =============================================
-- CUBE 2: Sales by Category x Month
-- =============================================

CREATE TABLE cube_sales_category_month (
    cube_key BIGINT PRIMARY KEY AUTO_INCREMENT,
    product_category VARCHAR(100),
    `year_month` INT,
    year_val INT,
    month_val INT,
    total_sales DECIMAL(14,2),
    total_quantity INT,
    transaction_count INT,
    total_profit DECIMAL(14,2),
    prev_month_sales DECIMAL(14,2),
    growth_pct DECIMAL(8,4),
    INDEX idx_category (product_category),
    INDEX idx_month (`year_month`)
);

-- =============================================
-- CUBE 3: Sales by Customer Segment x Store Type
-- =============================================

CREATE TABLE cube_sales_segment_storetype (
    cube_key BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_segment VARCHAR(20),
    store_type VARCHAR(50),
    year_val INT,
    total_sales DECIMAL(14,2),
    transaction_count INT,
    unique_customers INT,
    avg_order_value DECIMAL(10,2),
    INDEX idx_segment (customer_segment),
    INDEX idx_store_type (store_type),
    INDEX idx_year (year_val)
);

-- =============================================
-- CUBE 4: Time Series Analysis
-- =============================================

CREATE TABLE cube_time_series (
    cube_key BIGINT PRIMARY KEY AUTO_INCREMENT,
    time_level VARCHAR(20),
    time_value VARCHAR(50),
    time_label VARCHAR(100),
    start_date DATE,
    end_date DATE,
    total_sales DECIMAL(14,2),
    total_quantity INT,
    transaction_count INT,
    unique_customers INT,
    moving_avg_7d DECIMAL(14,2),
    moving_avg_30d DECIMAL(14,2),
    INDEX idx_level (time_level),
    INDEX idx_date_range (start_date, end_date)
);

-- =============================================
-- CUBE 5: Product Hierarchy Rollups
-- =============================================

CREATE TABLE cube_product_hierarchy (
    hierarchy_key BIGINT PRIMARY KEY AUTO_INCREMENT,
    level_type VARCHAR(20),
    level_value VARCHAR(100),
    level_name VARCHAR(255),
    parent_value VARCHAR(100),
    total_sales DECIMAL(14,2),
    total_quantity INT,
    total_profit DECIMAL(14,2),
    sales_share_pct DECIMAL(8,4),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_level (level_type, level_value)
);

-- =============================================
-- CUBE 6: Store Geography Hierarchy
-- =============================================

CREATE TABLE cube_store_hierarchy (
    hierarchy_key BIGINT PRIMARY KEY AUTO_INCREMENT,
    level_type VARCHAR(20),
    level_value VARCHAR(100),
    level_name VARCHAR(255),
    parent_value VARCHAR(100),
    total_sales DECIMAL(14,2),
    transaction_count INT,
    unique_customers INT,
    avg_ticket_size DECIMAL(10,2),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_level (level_type, level_value)
);

-- =============================================
-- CUBE 7: Customer Segmentation Cube
-- =============================================

CREATE TABLE cube_customer_segmentation (
    cube_key BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_segment VARCHAR(20),
    age_group VARCHAR(50),
    city_tier TINYINT,
    loyalty_member BOOLEAN,
    customer_count INT,
    total_sales DECIMAL(14,2),
    avg_order_value DECIMAL(10,2),
    avg_transactions_per_customer DECIMAL(8,2),
    INDEX idx_segment (customer_segment),
    INDEX idx_age (age_group),
    INDEX idx_tier (city_tier)
);

-- =============================================
-- INSERT METADATA
-- =============================================

INSERT INTO cube_metadata (cube_name, cube_description, source_fact_table) VALUES
('Sales_Store_Product_Date', 'Detailed sales by store, product, date', 'fact_sales'),
('Sales_Category_Month', 'Monthly category sales with growth', 'fact_sales'),
('Sales_Segment_StoreType', 'Customer segment vs store type', 'fact_sales'),
('Time_Series', 'Time trend with moving averages', 'fact_sales'),
('Product_Hierarchy', 'Product category rollups', 'fact_sales'),
('Store_Hierarchy', 'Store geography rollups', 'fact_sales'),
('Customer_Segmentation', 'Customer segment analysis', 'fact_sales');

SELECT 'MOLAP Database Schema Created Successfully' AS Status;