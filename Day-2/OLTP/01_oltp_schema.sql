-- =============================================
-- STEP 1: Create OLTP Database Structure
-- =============================================

DROP DATABASE IF EXISTS retail_oltp;
CREATE DATABASE retail_oltp;
USE retail_oltp;

-- Lookup Tables
CREATE TABLE lookup_gender (
    gender_code CHAR(1) PRIMARY KEY,
    gender_name VARCHAR(20)
);

CREATE TABLE lookup_payment_mode (
    payment_mode_id TINYINT PRIMARY KEY AUTO_INCREMENT,
    payment_mode_name VARCHAR(50) UNIQUE
);

CREATE TABLE lookup_order_status (
    status_id TINYINT PRIMARY KEY AUTO_INCREMENT,
    status_name VARCHAR(30) UNIQUE
);

CREATE TABLE lookup_channel (
    channel_id TINYINT PRIMARY KEY AUTO_INCREMENT,
    channel_name VARCHAR(50) UNIQUE
);

-- Categories Hierarchy
CREATE TABLE categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(100) NOT NULL,
    parent_category_id INT,
    level TINYINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_parent (parent_category_id)
);

-- Brands
CREATE TABLE brands (
    brand_id INT PRIMARY KEY AUTO_INCREMENT,
    brand_name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Suppliers
CREATE TABLE suppliers (
    supplier_id INT PRIMARY KEY AUTO_INCREMENT,
    supplier_code VARCHAR(20) NOT NULL UNIQUE,
    supplier_name VARCHAR(255) NOT NULL,
    supplier_type VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(100),
    payment_days INT DEFAULT 30,
    lead_time_days INT DEFAULT 7,
    annual_contract_value_lakh DECIMAL(12,2),
    is_preferred_vendor BOOLEAN DEFAULT FALSE,
    years_associated INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_code (supplier_code)
);

-- Stores
CREATE TABLE stores (
    store_id INT PRIMARY KEY AUTO_INCREMENT,
    store_code VARCHAR(20) NOT NULL UNIQUE,
    store_name VARCHAR(255) NOT NULL,
    city VARCHAR(100),
    state VARCHAR(100),
    city_tier TINYINT,
    cluster_zone VARCHAR(50),
    store_type VARCHAR(50),
    store_size_sqft INT,
    opening_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_code (store_code)
);

-- Customers
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_code VARCHAR(20) NOT NULL UNIQUE,
    customer_name VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    gender CHAR(1),
    age_group VARCHAR(50),
    city VARCHAR(100),
    state VARCHAR(100),
    city_tier INT,
    is_registered BOOLEAN DEFAULT FALSE,
    loyalty_member BOOLEAN DEFAULT FALSE,
    avg_monthly_spend_inr DECIMAL(12,2),
    visit_frequency_per_month INT,
    registration_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_code (customer_code)
);

-- Products
CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_code VARCHAR(20) NOT NULL UNIQUE,
    product_name VARCHAR(255) NOT NULL,
    brand_id INT,
    category_id INT,
    sub_category_id INT,
    mrp DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2) NOT NULL,
    gross_margin_pct DECIMAL(10,4) GENERATED ALWAYS AS (
        ((mrp - cost_price) / NULLIF(mrp, 0)) * 100
    ) STORED,
    is_perishable BOOLEAN DEFAULT FALSE,
    veg_nonveg VARCHAR(20),
    max_qty_per_transaction INT DEFAULT 10,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_code (product_code),
    INDEX idx_brand (brand_id),
    INDEX idx_category (category_id)
);

-- Product-Supplier Relationship
CREATE TABLE product_suppliers (
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    cost_price DECIMAL(10,2),
    PRIMARY KEY (product_id, supplier_id),
    INDEX idx_product (product_id),
    INDEX idx_supplier (supplier_id)
);

-- Sales Orders
CREATE TABLE sales_orders (
    order_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_number VARCHAR(30) NOT NULL UNIQUE,
    customer_id INT,
    store_id INT NOT NULL,
    order_date DATETIME NOT NULL,
    status_id TINYINT DEFAULT 1,
    payment_mode_id TINYINT,
    channel_id TINYINT DEFAULT 1,
    total_amount DECIMAL(12,2),
    discount_amount DECIMAL(12,2) DEFAULT 0,
    net_amount DECIMAL(12,2),
    is_return BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_customer (customer_id),
    INDEX idx_store (store_id),
    INDEX idx_date (order_date),
    INDEX idx_status (status_id)
);

-- Sales Order Items
CREATE TABLE sales_order_items (
    order_item_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount_percent DECIMAL(8,4) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    net_price DECIMAL(10,2) NOT NULL,
    INDEX idx_order (order_id),
    INDEX idx_product (product_id)
);

-- Inventory
CREATE TABLE inventory (
    inventory_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL,
    store_id INT NOT NULL,
    quantity_on_hand INT DEFAULT 0,
    quantity_reserved INT DEFAULT 0,
    reorder_point INT DEFAULT 10,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_product_store (product_id, store_id),
    INDEX idx_product (product_id),
    INDEX idx_store (store_id)
);