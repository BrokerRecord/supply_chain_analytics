-- 03: supplier analysis.
USE retail_analytics;

WITH
    supplier_delays AS (
        SELECT
            supplier_id,
            COUNT(*) AS records,
            ROUND(
                AVG(
                    delivery_time_days - lead_time_days
                ),
                2
            ) AS avg_delay_days,
            ROUND(AVG(on_time_delivery_rate), 2) AS avg_on_time_pct
        FROM supply_chain
        GROUP BY
            supplier_id
    ),
    ranked AS (
        SELECT *, ROW_NUMBER() OVER (
                ORDER BY avg_delay_days DESC, supplier_id
            ) AS worst_rank, ROW_NUMBER() OVER (
                ORDER BY avg_delay_days ASC, supplier_id
            ) AS best_rank
        FROM supplier_delays
    )
SELECT
    CASE
        WHEN worst_rank <= 5 THEN 'WORST'
        ELSE 'BEST'
    END AS performance_group,
    supplier_id,
    records,
    avg_delay_days,
    avg_on_time_pct
FROM ranked
WHERE
    worst_rank <= 5
    OR best_rank <= 5
ORDER BY
    performance_group DESC,
    avg_delay_days DESC;

-- 2. FULL PARETO CURVE, including 80% threshold (not just top 20)
WITH
    supplier_revenue AS (
        SELECT supplier_id, SUM(revenue_usd) AS revenue_usd
        FROM supply_chain
        GROUP BY
            supplier_id
    ),
    ranked AS (
        SELECT
            supplier_id,
            revenue_usd,
            ROW_NUMBER() OVER (
                ORDER BY revenue_usd DESC, supplier_id
            ) AS supplier_rank,
            SUM(revenue_usd) OVER (
                ORDER BY
                    revenue_usd DESC,
                    supplier_id ROWS UNBOUNDED PRECEDING
            ) AS cumulative_revenue,
            SUM(revenue_usd) OVER () AS total_revenue,
            COUNT(*) OVER () AS total_suppliers
        FROM supplier_revenue
    ),
    percentages AS (
        SELECT
            *,
            100.0 * cumulative_revenue / NULLIF(total_revenue, 0) AS cumulative_pct
        FROM ranked
    )
SELECT
    supplier_id,
    supplier_rank,
    ROUND(revenue_usd, 2) AS revenue_usd,
    ROUND(cumulative_pct, 2) AS cumulative_revenue_pct,
    ROUND(
        100.0 * supplier_rank / NULLIF(total_suppliers, 0),
        2
    ) AS cumulative_supplier_pct,
    CASE
        WHEN cumulative_pct < 80 THEN 'Before 80%'
        WHEN LAG(cumulative_pct, 1, 0) OVER (
            ORDER BY supplier_rank
        ) < 80 THEN 'Crosses 80%'
        ELSE 'After 80%'
    END AS pareto_band
FROM percentages
ORDER BY supplier_rank;

-- 3. HIGH DISRUPTION RISK AND HIGH ASSOCIATED REVENUE
-- Revenue associated with flagged suppliers is NOT expected financial loss.
WITH
    supplier_summary AS (
        SELECT
            supplier_id,
            COUNT(*) AS records,
            ROUND(AVG(supplier_rating), 2) AS avg_rating,
            ROUND(
                AVG(supply_disruption_risk),
                2
            ) AS avg_disruption_risk_score,
            ROUND(SUM(revenue_usd), 2) AS associated_revenue_usd
        FROM supply_chain
        GROUP BY
            supplier_id
    )
SELECT
    *,
    CASE
        WHEN avg_disruption_risk_score > 70
        AND associated_revenue_usd > 1000000 THEN 'URGENT REVIEW'
        WHEN avg_disruption_risk_score > 50 THEN 'MONITOR'
        ELSE 'NORMAL'
    END AS action_flag
FROM supplier_summary
WHERE
    associated_revenue_usd > 500000
ORDER BY
    avg_disruption_risk_score DESC,
    associated_revenue_usd DESC;
-- Thresholds above are illustrative business rules; calibrate with stakeholders.

-- 4. MONTH-OVER-MONTH REVENUE GROWTH
WITH
    monthly AS (
        SELECT DATE_SUB(
                transaction_date, INTERVAL DAYOFMONTH(transaction_date) -1 DAY
            ) AS month_start, SUM(revenue_usd) AS revenue_usd
        FROM supply_chain
        GROUP BY
            month_start
    ),
    previous AS (
        SELECT
            month_start,
            revenue_usd,
            LAG(revenue_usd) OVER (
                ORDER BY month_start
            ) AS previous_month_revenue
        FROM monthly
    )
SELECT
    month_start,
    ROUND(revenue_usd, 2) AS revenue_usd,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue_usd,
    ROUND(
        100.0 * (
            revenue_usd - previous_month_revenue
        ) / NULLIF(previous_month_revenue, 0),
        2
    ) AS mom_growth_pct
FROM previous
ORDER BY month_start;