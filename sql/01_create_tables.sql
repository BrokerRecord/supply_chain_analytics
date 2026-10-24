-- 01: source table, import instructions, analytical views

CREATE DATABASE IF NOT EXISTS retail_analytics CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE retail_analytics;

-- Drop conflicting objects cleanly first to avoid "is not a view" errors
DROP VIEW IF EXISTS dim_product;
DROP VIEW IF EXISTS dim_supplier;
DROP VIEW IF EXISTS dim_warehouse;
DROP VIEW IF EXISTS supply_chain;
DROP TABLE IF EXISTS supply_chain_raw;
DROP TABLE IF EXISTS dim_date;


-- 1. Create Raw Source Table
CREATE TABLE supply_chain_raw (
    `Product_ID` VARCHAR(255) NULL,
    `Product_Category` VARCHAR(255) NULL,
    `Brand` VARCHAR(255) NULL,
    `SKU` VARCHAR(255) NULL,
    `Current_Stock` BIGINT NULL,
    `Reorder_Level` BIGINT NULL,
    `Safety_Stock` BIGINT NULL,
    `Inventory_Turnover` DECIMAL(24, 8) NULL,
    `Supplier_ID` VARCHAR(255) NULL,
    `Supplier_Rating` DECIMAL(24, 8) NULL,
    `Lead_Time_Days` BIGINT NULL,
    `Warehouse_ID` VARCHAR(255) NULL,
    `Warehouse_Location` VARCHAR(255) NULL,
    `Storage_Capacity` BIGINT NULL,
    `Utilization_Rate` DECIMAL(24, 8) NULL,
    `Units_Sold` BIGINT NULL,
    `Daily_Demand` BIGINT NULL,
    `Monthly_Demand` BIGINT NULL,
    `Seasonal_Demand_Index` DECIMAL(24, 8) NULL,
    `Shipping_Cost_USD` DECIMAL(24, 8) NULL,
    `Transportation_Mode` VARCHAR(255) NULL,
    `Delivery_Time_Days` BIGINT NULL,
    `On_Time_Delivery_Rate` DECIMAL(24, 8) NULL,
    `Product_Cost_USD` DECIMAL(24, 8) NULL,
    `Selling_Price_USD` DECIMAL(24, 8) NULL,
    `Revenue_USD` DECIMAL(24, 8) NULL,
    `Profit_USD` DECIMAL(24, 8) NULL,
    `Stockout_Risk` DECIMAL(24, 8) NULL,
    `Overstock_Risk` DECIMAL(24, 8) NULL,
    `Supply_Disruption_Risk` DECIMAL(24, 8) NULL,
    `Date` DATE NULL,
    `Month` BIGINT NULL,
    `Quarter` BIGINT NULL,
    `Year` BIGINT NULL,
    `Demand_Forecast` BIGINT NULL,
    `Inventory_Optimization_Score` DECIMAL(24, 8) NULL,
    `Supplier_Performance_Score` DECIMAL(24, 8) NULL,
    `Supply_Chain_Efficiency` DECIMAL(24, 8) NULL,
    `Sustainability_Score` DECIMAL(24, 8) NULL,
    `Predicted_Reorder_Quantity` BIGINT NULL,
    `Operational_Risk_Score` DECIMAL(24, 8) NULL,
    `Stockout_Flag` BIGINT NULL,
    `Inventory_Status` VARCHAR(255) NULL,
    `Profit_Margin_%` DECIMAL(24, 8) NULL,
    `OTIF_Flag` BIGINT NULL,
    `Lead_Time_Category` VARCHAR(255) NULL,
    `Delivery_Delay_Days` BIGINT NULL,
    `Supplier_Tier` VARCHAR(255) NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- 2. Main Clean View
CREATE VIEW supply_chain AS
SELECT
    `Product_ID` AS product_id,
    `Product_Category` AS product_category,
    `Brand` AS brand,
    `SKU` AS sku,
    `Current_Stock` AS current_stock,
    `Reorder_Level` AS reorder_level,
    `Safety_Stock` AS safety_stock,
    `Inventory_Turnover` AS inventory_turnover,
    `Supplier_ID` AS supplier_id,
    `Supplier_Rating` AS supplier_rating,
    `Lead_Time_Days` AS lead_time_days,
    `Warehouse_ID` AS warehouse_id,
    `Warehouse_Location` AS warehouse_location,
    `Storage_Capacity` AS storage_capacity,
    `Utilization_Rate` AS utilization_rate,
    `Units_Sold` AS units_sold,
    `Daily_Demand` AS daily_demand,
    `Monthly_Demand` AS monthly_demand,
    `Seasonal_Demand_Index` AS seasonal_demand_index,
    `Shipping_Cost_USD` AS shipping_cost_usd,
    `Transportation_Mode` AS transportation_mode,
    `Delivery_Time_Days` AS delivery_time_days,
    `On_Time_Delivery_Rate` AS on_time_delivery_rate,
    `Product_Cost_USD` AS product_cost_usd,
    `Selling_Price_USD` AS selling_price_usd,
    `Revenue_USD` AS revenue_usd,
    `Profit_USD` AS profit_usd,
    `Stockout_Risk` AS stockout_risk,
    `Overstock_Risk` AS overstock_risk,
    `Supply_Disruption_Risk` AS supply_disruption_risk,
    `Date` AS transaction_date,
    `Month` AS month,
    `Quarter` AS quarter,
    `Year` AS year,
    `Demand_Forecast` AS demand_forecast,
    `Inventory_Optimization_Score` AS inventory_optimization_score,
    `Supplier_Performance_Score` AS supplier_performance_score,
    `Supply_Chain_Efficiency` AS supply_chain_efficiency,
    `Sustainability_Score` AS sustainability_score,
    `Predicted_Reorder_Quantity` AS predicted_reorder_quantity,
    `Operational_Risk_Score` AS operational_risk_score,
    `Stockout_Flag` AS stockout_flag,
    `Inventory_Status` AS inventory_status,
    `Profit_Margin_%` AS profit_margin,
    `OTIF_Flag` AS otif_flag,
    `Lead_Time_Category` AS lead_time_category,
    `Delivery_Delay_Days` AS delivery_delay_days,
    `Supplier_Tier` AS supplier_tier
FROM supply_chain_raw;

-- 3. Dimensions for Power BI
CREATE VIEW dim_product AS
SELECT DISTINCT
    product_id,
    product_category,
    brand,
    sku
FROM supply_chain
WHERE product_id IS NOT NULL;

CREATE VIEW dim_supplier AS
SELECT
    supplier_id,
    COUNT(*) AS record_count,
    ROUND(AVG(supplier_rating), 2) AS avg_rating,
    ROUND(AVG(lead_time_days), 2) AS avg_lead_time_days
FROM supply_chain
WHERE supplier_id IS NOT NULL
GROUP BY supplier_id;

CREATE VIEW dim_warehouse AS
SELECT DISTINCT
    warehouse_id
FROM supply_chain
WHERE warehouse_id IS NOT NULL;

-- 4. Calendar Table Setup
CREATE TABLE dim_date (
    transaction_date DATE NOT NULL PRIMARY KEY,
    `month_name` VARCHAR(20) NOT NULL,
    `year` INT NOT NULL,
    `quarter` INT NOT NULL,
    `month` INT NOT NULL,
    `year_month` VARCHAR(7),
    `month_short` VARCHAR(5),
    `is_weekend` TINYINT,
    month_start DATE NOT NULL
) ENGINE = InnoDB;

-- Insert Values
LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/retail_supply_chain_clean.csv'
INTO TABLE supply_chain_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
-- Populate Calendar
INSERT IGNORE INTO dim_date (
    transaction_date, 
    `month_name`, 
    `year`, 
    `quarter`, 
    `month`, 
    `year_month`, 
    `month_short`, 
    `is_weekend`, 
    month_start
)
SELECT 
    d, 
    MONTHNAME(d) AS `month_name`, 
    YEAR(d) AS `year`, 
    QUARTER(d) AS `quarter`, 
    MONTH(d) AS `month`, 
    DATE_FORMAT(d, '%Y-%m') AS `year_month`, 
    DATE_FORMAT(d, '%b') AS `month_short`, 
    CASE WHEN DAYOFWEEK(d) IN (1, 7) THEN 1 ELSE 0 END AS `is_weekend`, 
    DATE_SUB(d, INTERVAL DAYOFMONTH(d) - 1 DAY) AS month_start
FROM (
    SELECT DATE_ADD('2023-01-01', INTERVAL (a.n + 10 * b.n + 100 * c.n + 1000 * e.n) DAY) AS d
    FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
    CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
    CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
    CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) e
) days
WHERE d <= '2026-03-31';

-- fact table
DROP TABLE IF EXISTS fact_supply_chain;
CREATE TABLE fact_supply_chain AS
SELECT
    s.*,
    d.transaction_date AS date_key  
FROM supply_chain s
JOIN dim_date d ON s.transaction_date = d.transaction_date;
-- indexes for fact table
ALTER TABLE fact_supply_chain
    ADD PRIMARY KEY (product_id,date_key, supplier_id),
    ADD INDEX idx_date (date_key),
    ADD INDEX idx_product (product_id),
    ADD INDEX idx_supplier (supplier_id),
    ADD INDEX idx_warehouse (warehouse_id);

-- 
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT(product_id, '|', date_key, '|', supplier_id)) AS distinct_combos
FROM fact_supply_chain;
SELECT
    COUNT(*) AS records,
    MIN(date_key) AS min_date,
    MAX(date_key) AS max_date,
    COUNT(DISTINCT product_id) AS products,
    COUNT(DISTINCT supplier_id) AS suppliers,
    COUNT(DISTINCT warehouse_id) AS warehouses
FROM fact_supply_chain;

-- Warehouse integrity check (same as before)
SELECT
    warehouse_id,
    COUNT(DISTINCT warehouse_location) AS location_variants,
    COUNT(DISTINCT storage_capacity) AS capacity_variants
FROM fact_supply_chain
GROUP BY warehouse_id
HAVING
    COUNT(DISTINCT warehouse_location) > 1
    OR COUNT(DISTINCT storage_capacity) > 1
ORDER BY location_variants DESC, capacity_variants DESC
LIMIT 10;