/*
    Northwind Sales Performance Analysis 2014
    Step 8: Customer analysis and RFM segmentation.

    RFM population: customers with at least one order in 2014.
    Reference date: 2015-01-01, the day after the reporting period.
*/

USE NorthwindAnalytics;
GO

SET NOCOUNT ON;

IF OBJECT_ID(N'analytics.vw_sales_2014', N'V') IS NULL
    THROW 51160, 'Run create_sales_analytics_views.sql first.', 1;
GO

CREATE OR ALTER VIEW analytics.vw_customer_rfm_2014
AS
WITH customer_base AS
(
    SELECT
        customer_id,
        customer_name,
        customer_city,
        customer_country,
        MAX(order_date) AS last_order_date,
        DATEDIFF(DAY, MAX(order_date), CAST('20150101' AS DATE)) AS recency_days,
        COUNT(DISTINCT order_id) AS frequency_orders,
        SUM(quantity) AS units_purchased,
        SUM(net_sales) AS monetary_value
    FROM analytics.vw_sales_2014
    GROUP BY
        customer_id,
        customer_name,
        customer_city,
        customer_country
),
percentiles AS
(
    SELECT
        *,
        PERCENT_RANK() OVER (ORDER BY recency_days DESC) AS recency_percentile,
        PERCENT_RANK() OVER (ORDER BY frequency_orders) AS frequency_percentile,
        PERCENT_RANK() OVER (ORDER BY monetary_value) AS monetary_percentile
    FROM customer_base
),
scored AS
(
    SELECT
        *,
        CASE
            WHEN recency_percentile >= 0.80 THEN 5
            WHEN recency_percentile >= 0.60 THEN 4
            WHEN recency_percentile >= 0.40 THEN 3
            WHEN recency_percentile >= 0.20 THEN 2
            ELSE 1
        END AS recency_score,
        CASE
            WHEN frequency_percentile >= 0.80 THEN 5
            WHEN frequency_percentile >= 0.60 THEN 4
            WHEN frequency_percentile >= 0.40 THEN 3
            WHEN frequency_percentile >= 0.20 THEN 2
            ELSE 1
        END AS frequency_score,
        CASE
            WHEN monetary_percentile >= 0.80 THEN 5
            WHEN monetary_percentile >= 0.60 THEN 4
            WHEN monetary_percentile >= 0.40 THEN 3
            WHEN monetary_percentile >= 0.20 THEN 2
            ELSE 1
        END AS monetary_score
    FROM percentiles
),
segmented AS
(
    SELECT
        *,
        CASE
            WHEN recency_score >= 4
             AND frequency_score >= 4
             AND monetary_score >= 4 THEN N'Champions'
            WHEN frequency_score >= 4
             AND monetary_score >= 3 THEN N'Loyal'
            WHEN recency_score >= 4
             AND frequency_score BETWEEN 2 AND 3 THEN N'Potential Loyalists'
            WHEN recency_score <= 2
             AND (frequency_score >= 3 OR monetary_score >= 3) THEN N'At Risk'
            WHEN recency_score <= 2
             AND frequency_score <= 2 THEN N'Hibernating'
            ELSE N'Others'
        END AS rfm_segment
    FROM scored
),
ranked AS
(
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY monetary_value DESC, customer_id) AS net_sales_rank,
        SUM(monetary_value) OVER () AS total_customer_net_sales,
        SUM(monetary_value) OVER
        (
            ORDER BY monetary_value DESC, customer_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_net_sales
    FROM segmented
)
SELECT
    customer_id,
    customer_name,
    customer_city,
    customer_country,
    CAST('20150101' AS DATE) AS rfm_reference_date,
    last_order_date,
    recency_days,
    frequency_orders,
    units_purchased,
    CAST(monetary_value AS DECIMAL(19,4)) AS monetary_value,
    CAST(monetary_value / NULLIF(frequency_orders, 0) AS DECIMAL(19,4)) AS average_order_value,
    recency_score,
    frequency_score,
    monetary_score,
    CONCAT(recency_score, frequency_score, monetary_score) AS rfm_score,
    rfm_segment,
    net_sales_rank,
    CAST(
        monetary_value * 100.0 / NULLIF(total_customer_net_sales, 0)
        AS DECIMAL(7,2)
    ) AS net_sales_share_percent,
    CAST(
        cumulative_net_sales * 100.0 / NULLIF(total_customer_net_sales, 0)
        AS DECIMAL(7,2)
    ) AS cumulative_net_sales_percent
FROM ranked;
GO

/* 1. Customer KPIs for 2014. */
SELECT N'1. 2014 customer KPIs' AS result_set;

SELECT
    COUNT(*) AS active_customers,
    COUNT(DISTINCT customer_country) AS active_customer_countries,
    SUM(CASE WHEN net_sales_rank <= 10 THEN 1 ELSE 0 END) AS top_10_customers,
    CAST(
        SUM(CASE WHEN net_sales_rank <= 10 THEN monetary_value ELSE 0 END) * 100.0
        / NULLIF(SUM(monetary_value), 0)
        AS DECIMAL(7,2)
    ) AS top_10_net_sales_share_percent,
    SUM(CASE WHEN rfm_segment = N'At Risk' THEN 1 ELSE 0 END) AS at_risk_customers,
    SUM(CASE WHEN recency_score <= 2 AND monetary_score >= 4 THEN 1 ELSE 0 END)
        AS high_value_customers_needing_attention
FROM analytics.vw_customer_rfm_2014;

/* 2. RFM segment summary. */
SELECT N'2. RFM segment summary' AS result_set;

SELECT
    rfm_segment,
    COUNT(*) AS total_customers,
    CAST(AVG(CAST(recency_days AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS avg_recency_days,
    CAST(AVG(CAST(frequency_orders AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS avg_orders,
    CAST(SUM(monetary_value) AS DECIMAL(18,2)) AS net_sales,
    CAST(
        SUM(monetary_value) * 100.0
        / NULLIF((SELECT SUM(monetary_value) FROM analytics.vw_customer_rfm_2014), 0)
        AS DECIMAL(7,2)
    ) AS net_sales_share_percent
FROM analytics.vw_customer_rfm_2014
GROUP BY rfm_segment
ORDER BY net_sales DESC;

/* 3. Ten highest-value customers and revenue concentration. */
SELECT N'3. Top 10 customers by Net Sales' AS result_set;

SELECT TOP (10)
    net_sales_rank,
    customer_id,
    customer_name,
    customer_country,
    frequency_orders,
    recency_days,
    CAST(monetary_value AS DECIMAL(18,2)) AS net_sales,
    net_sales_share_percent,
    cumulative_net_sales_percent,
    rfm_segment
FROM analytics.vw_customer_rfm_2014
ORDER BY net_sales_rank;

/* 4. High-value customers with weak recency. */
SELECT N'4. High-value customers needing attention' AS result_set;

SELECT
    customer_id,
    customer_name,
    customer_country,
    last_order_date,
    recency_days,
    frequency_orders,
    CAST(monetary_value AS DECIMAL(18,2)) AS net_sales,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_segment
FROM analytics.vw_customer_rfm_2014
WHERE recency_score <= 2
  AND monetary_score >= 4
ORDER BY monetary_value DESC, customer_id;

/* 5. Full RFM customer list. */
SELECT N'5. Full RFM customer list' AS result_set;

SELECT
    net_sales_rank,
    customer_id,
    customer_name,
    customer_country,
    last_order_date,
    recency_days,
    frequency_orders,
    CAST(monetary_value AS DECIMAL(18,2)) AS net_sales,
    average_order_value,
    rfm_score,
    rfm_segment,
    cumulative_net_sales_percent
FROM analytics.vw_customer_rfm_2014
ORDER BY net_sales_rank;

/* 6. Validate customer grain, scores, and totals. */
SELECT N'6. RFM validation' AS result_set;

SELECT
    check_name,
    issue_count,
    CASE WHEN issue_count = 0 THEN N'PASS' ELSE N'FAIL' END AS result
FROM
(
    SELECT
        N'RFM row count differs from active customers' AS check_name,
        ABS(
            (SELECT COUNT(*) FROM analytics.vw_customer_rfm_2014)
            - (SELECT COUNT(DISTINCT customer_id) FROM analytics.vw_sales_2014)
        ) AS issue_count

    UNION ALL

    SELECT
        N'Duplicate customer_id in RFM view',
        COUNT(*)
    FROM
    (
        SELECT customer_id
        FROM analytics.vw_customer_rfm_2014
        GROUP BY customer_id
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT
        N'Customer Net Sales differs from 2014 sales view',
        CASE
            WHEN ABS(
                (SELECT SUM(monetary_value) FROM analytics.vw_customer_rfm_2014)
                - (SELECT SUM(net_sales) FROM analytics.vw_sales_2014)
            ) <= 0.01 THEN 0 ELSE 1
        END

    UNION ALL

    SELECT
        N'RFM score outside 1 to 5',
        COUNT(*)
    FROM analytics.vw_customer_rfm_2014
    WHERE recency_score NOT BETWEEN 1 AND 5
       OR frequency_score NOT BETWEEN 1 AND 5
       OR monetary_score NOT BETWEEN 1 AND 5

    UNION ALL

    SELECT
        N'Negative recency',
        COUNT(*)
    FROM analytics.vw_customer_rfm_2014
    WHERE recency_days < 0

    UNION ALL

    SELECT
        N'Customer without RFM segment',
        COUNT(*)
    FROM analytics.vw_customer_rfm_2014
    WHERE rfm_segment IS NULL
) AS checks;
GO
