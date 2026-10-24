-- 02: business KPIs.
USE retail_analytics;

-- 1. EXECUTIVE SUMMARY
SELECT
    COUNT(*) AS records,
    COUNT(DISTINCT product_id) AS distinct_products,
    SUM(units_sold) AS units_sold,
    ROUND(SUM(revenue_usd), 2) AS revenue_usd,
    ROUND(SUM(profit_usd), 2) AS profit_usd,
    ROUND(
        100.0 * SUM(profit_usd) / NULLIF(SUM(revenue_usd), 0),
        2
    ) AS weighted_profit_margin_pct,
    ROUND(AVG(lead_time_days), 2) AS avg_supplier_lead_days,
    ROUND(AVG(on_time_delivery_rate), 2) AS avg_on_time_delivery_pct
FROM supply_chain;

-- 2. BELOW REORDER THRESHOLD BY WAREHOUSE (NOT historical stockout rate)
SELECT
    warehouse_id,
    COUNT(*) AS records,
    SUM(
        CASE
            WHEN current_stock < reorder_level THEN 1
            ELSE 0
        END
    ) AS below_reorder_records,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN current_stock < reorder_level THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS below_reorder_pct,
    SUM(
        CASE
            WHEN current_stock = 0 THEN 1
            ELSE 0
        END
    ) AS zero_stock_records
FROM supply_chain
GROUP BY
    warehouse_id
ORDER BY below_reorder_pct DESC;

-- 3. CRITICAL PRODUCT RECORDS
SELECT
    product_id,
    sku,
    product_category,
    warehouse_id,
    current_stock,
    safety_stock,
    reorder_level,
    predicted_reorder_quantity,
    stockout_risk
FROM supply_chain
WHERE
    current_stock < safety_stock
ORDER BY stockout_risk DESC, (safety_stock - current_stock) DESC
LIMIT 10;

-- 4. SUPPLIER RANKING (on-time delivery rate is not automatically OTIF)
WITH
    summary AS (
        SELECT
            supplier_id,
            COUNT(*) AS records,
            ROUND(AVG(supplier_rating), 2) AS avg_rating,
            ROUND(AVG(lead_time_days), 2) AS avg_lead_days,
            ROUND(AVG(on_time_delivery_rate), 2) AS avg_on_time_pct,
            ROUND(
                AVG(supplier_performance_score),
                2
            ) AS avg_performance_score
        FROM supply_chain
        GROUP BY
            supplier_id
    )
SELECT *, DENSE_RANK() OVER (
        ORDER BY avg_performance_score DESC
    ) AS performance_rank
FROM summary
ORDER BY performance_rank, supplier_id
LIMIT 20;

-- 5. CATEGORY FINANCIAL PERFORMANCE: margin from sums, not mean row margins
SELECT
    product_category,
    SUM(units_sold) AS units_sold,
    ROUND(SUM(revenue_usd), 2) AS revenue_usd,
    ROUND(SUM(profit_usd), 2) AS profit_usd,
    ROUND(
        100.0 * SUM(profit_usd) / NULLIF(SUM(revenue_usd), 0),
        2
    ) AS weighted_margin_pct
FROM supply_chain
GROUP BY
    product_category
ORDER BY revenue_usd DESC;

-- 6. TRANSPORT MODE COMPARISON
SELECT
    transportation_mode,
    COUNT(*) AS records,
    ROUND(AVG(lead_time_days), 2) AS avg_supplier_lead_days,
    ROUND(AVG(delivery_time_days), 2) AS avg_delivery_days,
    ROUND(AVG(shipping_cost_usd), 2) AS avg_shipping_cost_usd,
    ROUND(AVG(on_time_delivery_rate), 2) AS avg_on_time_delivery_pct
FROM supply_chain
GROUP BY
    transportation_mode
ORDER BY avg_delivery_days;

-- 7. MONTHLY REVENUE, PROFIT, AND DEMAND
SELECT
    DATE_SUB(
        transaction_date,
        INTERVAL DAYOFMONTH(transaction_date) -1 DAY
    ) AS month_start,
    ROUND(SUM(revenue_usd), 2) AS revenue_usd,
    ROUND(SUM(profit_usd), 2) AS profit_usd,
    SUM(units_sold) AS units_sold
FROM supply_chain
GROUP BY
    month_start
ORDER BY month_start;

-- 8. WAREHOUSE UTILIZATION: locations/capacity may vary for same warehouse_id
SELECT
    warehouse_id,
    COUNT(*) AS records,
    COUNT(DISTINCT warehouse_location) AS location_variants,
    ROUND(AVG(utilization_rate), 2) AS avg_utilization_pct,
    ROUND(AVG(inventory_turnover), 2) AS avg_inventory_turnover,
    SUM(
        CASE
            WHEN utilization_rate > 90 THEN 1
            ELSE 0
        END
    ) AS high_utilization_records,
    CASE
        WHEN AVG(utilization_rate) > 90 THEN 'High utilization'
        WHEN AVG(utilization_rate) < 30 THEN 'Low utilization'
        ELSE 'Mid-range utilization'
    END AS utilization_band
FROM supply_chain
GROUP BY
    warehouse_id
ORDER BY avg_utilization_pct DESC;

-- 9. RISK BY CATEGORY (scores are supplied, not calibrated probabilities)
SELECT
    product_category,
    COUNT(*) AS records,
    ROUND(AVG(stockout_risk), 2) AS avg_stockout_risk_score,
    ROUND(AVG(overstock_risk), 2) AS avg_overstock_risk_score,
    ROUND(
        AVG(supply_disruption_risk),
        2
    ) AS avg_disruption_risk_score,
    ROUND(
        AVG(operational_risk_score),
        2
    ) AS avg_operational_risk_score,
    ROUND(AVG(sustainability_score), 2) AS avg_sustainability_score
FROM supply_chain
GROUP BY
    product_category
ORDER BY avg_operational_risk_score DESC;

-- 10. SUPPLIER TIER: assign exactly once per supplier using mean rating
WITH
    suppliers AS (
        SELECT
            supplier_id,
            AVG(supplier_rating) AS avg_rating,
            AVG(lead_time_days) AS avg_lead_days,
            AVG(on_time_delivery_rate) AS avg_on_time_pct,
            SUM(revenue_usd) AS revenue_usd
        FROM supply_chain
        GROUP BY
            supplier_id
    ),
    tiers AS (
        SELECT
            *,
            CASE
                WHEN avg_rating >= 3.5 THEN 'Premium'
                WHEN avg_rating >= 2 THEN 'Standard'
                ELSE 'Low performer'
            END AS supplier_tier
        FROM suppliers
    )
SELECT
    supplier_tier,
    COUNT(*) AS suppliers,
    ROUND(AVG(avg_lead_days), 2) AS avg_lead_days,
    ROUND(AVG(avg_on_time_pct), 2) AS avg_supplier_on_time_pct,
    ROUND(SUM(revenue_usd), 2) AS associated_revenue_usd
FROM tiers
GROUP BY
    supplier_tier
ORDER BY associated_revenue_usd DESC;