-- =============================================
-- ROLAP DATABASE: retail_rolap
-- Star Schema for Analytical Processing
-- MySQL Native (No external dependencies)
-- =============================================

DROP DATABASE IF EXISTS retail_rolap;
CREATE DATABASE retail_rolap;
USE retail_rolap;

-- =============================================
-- DATE DIMENSION (Conformed Dimension)
-- =============================================

CREATE TABLE dim_date (
    date_id INT PRIMARY KEY,
    full_date DATE NOT NULL,
    year_val SMALLINT,
    quarter_val TINYINT,
    quarter_label VARCHAR(20),
    month_val TINYINT,
    month_name VARCHAR(20),
    month_short VARCHAR(3),
    day_val TINYINT,
    day_of_week TINYINT,
    weekday_name VARCHAR(20),
    weekday_short VARCHAR(3),
    week_of_year TINYINT,
    is_weekend BOOLEAN,
    is_holiday BOOLEAN DEFAULT FALSE,
    holiday_name VARCHAR(100),
    fiscal_year SMALLINT,
    fiscal_quarter TINYINT,
    fiscal_month TINYINT,
    INDEX idx_year (year_val),
    INDEX idx_month (month_val),
    INDEX idx_week (week_of_year),
    INDEX idx_date_range (full_date)
);

-- =============================================
-- PRODUCT DIMENSION (Denormalized)
-- =============================================

CREATE TABLE dim_product (
    product_key INT PRIMARY KEY AUTO_INCREMENT,
    product_id VARCHAR(20) NOT NULL UNIQUE,
    product_name VARCHAR(255),
    brand VARCHAR(100),
    category VARCHAR(100),
    sub_category VARCHAR(100),
    mrp DECIMAL(10,2),
    cost_price DECIMAL(10,2),
    gross_margin_pct DECIMAL(10,4),
    is_perishable BOOLEAN,
    veg_nonveg VARCHAR(20),
    INDEX idx_brand (brand),
    INDEX idx_category (category),
    INDEX idx_sub_category (sub_category)
);

-- =============================================
-- STORE DIMENSION (Denormalized)
-- =============================================

CREATE TABLE dim_store (
    store_key INT PRIMARY KEY AUTO_INCREMENT,
    store_id VARCHAR(20) NOT NULL UNIQUE,
    store_name VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    city_tier TINYINT,
    cluster_zone VARCHAR(50),
    store_type VARCHAR(50),
    store_size_sqft INT,
    opening_date DATE,
    INDEX idx_city (city),
    INDEX idx_state (state),
    INDEX idx_cluster (cluster_zone),
    INDEX idx_type (store_type)
);

-- =============================================
-- CUSTOMER DIMENSION (Denormalized)
-- =============================================

CREATE TABLE dim_customer (
    customer_key INT PRIMARY KEY AUTO_INCREMENT,
    customer_id VARCHAR(20) NOT NULL UNIQUE,
    customer_name VARCHAR(255),
    gender VARCHAR(20),
    age_group VARCHAR(50),
    city VARCHAR(100),
    state VARCHAR(100),
    city_tier TINYINT,
    is_registered BOOLEAN,
    loyalty_member BOOLEAN,
    customer_segment VARCHAR(20),
    INDEX idx_city (city),
    INDEX idx_segment (customer_segment),
    INDEX idx_loyalty (loyalty_member)
);

-- =============================================
-- SUPPLIER DIMENSION
-- =============================================

CREATE TABLE dim_supplier (
    supplier_key INT PRIMARY KEY AUTO_INCREMENT,
    supplier_id VARCHAR(20) NOT NULL UNIQUE,
    supplier_name VARCHAR(255),
    supplier_type VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(100),
    payment_days INT,
    lead_time_days INT,
    is_preferred_vendor BOOLEAN,
    INDEX idx_type (supplier_type),
    INDEX idx_state (state)
);

-- =============================================
-- SALES FACT TABLE (Grain: Transaction Line Item)
-- =============================================

CREATE TABLE fact_sales (
    sale_key BIGINT PRIMARY KEY AUTO_INCREMENT,
    transaction_id VARCHAR(30),
    date_id INT NOT NULL,
    product_key INT NOT NULL,
    store_key INT NOT NULL,
    customer_key INT,
    supplier_key INT,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    sale_amount DECIMAL(12,2) NOT NULL,
    cost_amount DECIMAL(12,2),
    profit DECIMAL(12,2),
    margin_pct DECIMAL(8,4),
    payment_mode VARCHAR(50),
    is_return BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_date (date_id),
    INDEX idx_product (product_key),
    INDEX idx_store (store_key),
    INDEX idx_customer (customer_key),
    INDEX idx_supplier (supplier_key),
    INDEX idx_date_product (date_id, product_key),
    INDEX idx_date_store (date_id, store_key),
    INDEX idx_date_customer (date_id, customer_key),
    INDEX idx_transaction (transaction_id)
);

-- =============================================
-- AGGREGATE TABLES (Pre-computed for Performance)
-- =============================================

-- Daily Sales by Store
CREATE TABLE agg_daily_store_sales (
    date_id INT NOT NULL,
    store_key INT NOT NULL,
    total_sales DECIMAL(14,2) DEFAULT 0,
    total_quantity INT DEFAULT 0,
    transaction_count INT DEFAULT 0,
    unique_customers INT DEFAULT 0,
    avg_ticket_size DECIMAL(10,2) DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (date_id, store_key),
    INDEX idx_date (date_id),
    INDEX idx_store (store_key),
    INDEX idx_sales (total_sales)
);

-- Daily Sales by Product
CREATE TABLE agg_daily_product_sales (
    date_id INT NOT NULL,
    product_key INT NOT NULL,
    total_sales DECIMAL(14,2) DEFAULT 0,
    total_quantity INT DEFAULT 0,
    transaction_count INT DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (date_id, product_key),
    INDEX idx_date (date_id),
    INDEX idx_product (product_key),
    INDEX idx_sales (total_sales)
);

-- Monthly Category Sales
CREATE TABLE agg_monthly_category_sales (
    `year_month` INT NOT NULL,
    category VARCHAR(100) NOT NULL,
    total_sales DECIMAL(14,2) DEFAULT 0,
    total_profit DECIMAL(14,2) DEFAULT 0,
    total_quantity INT DEFAULT 0,
    transaction_count INT DEFAULT 0,
    sales_rank INT DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`year_month`, category),
    INDEX idx_year_month (`year_month`),
    INDEX idx_category (category),
    INDEX idx_rank (sales_rank)
);

-- Monthly Store Performance
CREATE TABLE agg_monthly_store_performance (
    `year_month` INT NOT NULL,
    store_key INT NOT NULL,
    total_sales DECIMAL(14,2) DEFAULT 0,
    total_profit DECIMAL(14,2) DEFAULT 0,
    transaction_count INT DEFAULT 0,
    unique_customers INT DEFAULT 0,
    avg_ticket_size DECIMAL(10,2) DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`year_month`, store_key),
    INDEX idx_year_month (`year_month`),
    INDEX idx_store (store_key),
    INDEX idx_sales (total_sales)
);

-- Customer Lifetime Value Aggregates
CREATE TABLE agg_customer_lifetime (
    customer_key INT PRIMARY KEY,
    first_purchase_date DATE,
    last_purchase_date DATE,
    total_spend DECIMAL(14,2) DEFAULT 0,
    total_transactions INT DEFAULT 0,
    avg_order_value DECIMAL(10,2) DEFAULT 0,
    days_since_last_purchase INT DEFAULT 0,
    lifetime_segment VARCHAR(20),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_segment (lifetime_segment),
    INDEX idx_last_purchase (last_purchase_date),
    INDEX idx_total_spend (total_spend)
);

SELECT 'ROLAP Database Schema Created Successfully' AS Status;