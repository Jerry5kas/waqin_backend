-- Fix Orders Table Structure
-- Run this script on your tenant database to fix the auto-increment issue

-- First, check if the table exists and has the correct structure
-- Replace 'your_tenant_schema' with your actual tenant schema name

USE your_tenant_schema;

-- Check if orders table exists
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'your_tenant_schema' 
AND TABLE_NAME = 'orders';

-- Check the current structure of the orders table
DESCRIBE orders;

-- If the id column is not auto-incrementing, fix it
ALTER TABLE orders MODIFY id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY;

-- Verify the fix
DESCRIBE orders;

-- If the table doesn't exist, create it with proper structure
-- Uncomment the following if the table doesn't exist:

/*
CREATE TABLE orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_no VARCHAR(255) UNIQUE NULL,
    order_type VARCHAR(255) NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    delivery_time DATETIME NOT NULL,
    employee_id BIGINT UNSIGNED NULL,
    function_date DATETIME NULL,
    trial_date DATETIME NULL,
    urgent_status VARCHAR(255) NULL,
    quantity INT NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    discount DECIMAL(10,2) DEFAULT 0,
    final_total DECIMAL(10,2) NOT NULL,
    stage VARCHAR(255) NULL,
    status VARCHAR(255) DEFAULT 'Pending',
    created_by BIGINT UNSIGNED NULL,
    updated_by BIGINT UNSIGNED NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
*/
