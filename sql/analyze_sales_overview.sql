/*
    Northwind Sales Performance Analysis 2014
    Step 6: Sales overview analysis.

    Reporting period: 2014-01-01 to 2014-12-31.
    Main KPI: Net Sales = unit price * quantity * (1 - discount).
*/

USE NorthwindAnalytics;
GO

SET NOCOUNT ON;

IF OBJECT_ID(N'analytics.vw_sales_2014', N'V') IS NULL
    THROW 51140, 'Run create_sales_analytics_views.sql first.', 1;

/* 1. Main KPIs for the 2014 overview page. */
SELECT N'1. 2014 sales KPIs' AS result_set;

SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS active_customers,
    COUNT(DISTINCT customer_country) AS active_customer_countries,
    COUNT(DISTINCT product_id) AS products_sold,
    SUM(quantity) AS units_sold,
    CAST(SUM(gross_sales) AS DECIMAL(18,2)) AS gross_sales,
    CAST(SUM(discount_amount) AS DECIMAL(18,2)) AS discount_amount,
    CAST(SUM(net_sales) AS DECIMAL(18,2)) AS net_sales,
    CAST(
        SUM(net_sales) / NULLIF(COUNT(DISTINCT order_id), 0)
        AS DECIMAL(18,2)
    ) AS average_order_value,
    CAST(
        SUM(quantity) * 1.0 / NULLIF(COUNT(DISTINCT order_id), 0)
        AS DECIMAL(10,2)
    ) AS average_units_per_order,
    CAST(
        SUM(discount_amount) * 100.0 / NULLIF(SUM(gross_sales), 0)
        AS DECIMAL(7,2)
    ) AS weighted_discount_percent
FROM analytics.vw_sales_2014;

/* 2. Monthly trend. No comparison with another year is used. */
SELECT N'2. Monthly sales trend in 2014' AS result_set;

;WITH monthly_sales AS
(
    SELECT
        month_start,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT customer_id) AS active_customers,
        SUM(quantity) AS units_sold,
        SUM(gross_sales) AS gross_sales,
        SUM(discount_amount) AS discount_amount,
        SUM(net_sales) AS net_sales
    FROM analytics.vw_sales_2014
    GROUP BY month_start
),
year_total AS
(
    SELECT SUM(net_sales) AS yearly_net_sales
    FROM monthly_sales
)
SELECT
    m.month_start,
    DATENAME(MONTH, m.month_start) AS month_name,
    m.total_orders,
    m.active_customers,
    m.units_sold,
    CAST(m.gross_sales AS DECIMAL(18,2)) AS gross_sales,
    CAST(m.discount_amount AS DECIMAL(18,2)) AS discount_amount,
    CAST(m.net_sales AS DECIMAL(18,2)) AS net_sales,
    CAST(m.net_sales / NULLIF(m.total_orders, 0) AS DECIMAL(18,2)) AS average_order_value,
    CAST(m.net_sales * 100.0 / NULLIF(y.yearly_net_sales, 0) AS DECIMAL(7,2)) AS net_sales_share_percent,
    RANK() OVER (ORDER BY m.net_sales DESC) AS net_sales_rank
FROM monthly_sales AS m
CROSS JOIN year_total AS y
ORDER BY m.month_start;

/* 3. Distribution of order value. */
SELECT N'3. Order-value distribution in 2014' AS result_set;

;WITH order_totals AS
(
    SELECT
        order_id,
        SUM(net_sales) AS order_net_sales
    FROM analytics.vw_sales_2014
    GROUP BY order_id
)
SELECT TOP (1)
    COUNT(*) OVER () AS total_orders,
    CAST(MIN(order_net_sales) OVER () AS DECIMAL(18,2)) AS minimum_order_value,
    CAST(AVG(order_net_sales) OVER () AS DECIMAL(18,2)) AS average_order_value,
    CAST(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_net_sales) OVER ()
        AS DECIMAL(18,2)
    ) AS median_order_value,
    CAST(MAX(order_net_sales) OVER () AS DECIMAL(18,2)) AS maximum_order_value
FROM order_totals;

/* 4. Reconcile the analytical view with raw data and monthly totals. */
SELECT N'4. Sales reconciliation' AS result_set;

;WITH monthly_sales AS
(
    SELECT
        month_start,
        SUM(net_sales) AS monthly_net_sales
    FROM analytics.vw_sales_2014
    GROUP BY month_start
),
checks AS
(
    SELECT
        N'View Net Sales matches raw 2014 calculation' AS check_name,
        CAST(
            (
                SELECT SUM(od.unitPrice * od.quantity * (1 - od.discount))
                FROM raw.orders AS o
                INNER JOIN raw.order_details AS od
                    ON od.orderID = o.orderID
                WHERE o.orderDate >= '20140101'
                  AND o.orderDate <  '20150101'
            ) AS DECIMAL(18,2)
        ) AS expected_value,
        CAST((SELECT SUM(net_sales) FROM analytics.vw_sales_2014) AS DECIMAL(18,2)) AS actual_value

    UNION ALL

    SELECT
        N'Sum of monthly Net Sales matches yearly Net Sales',
        CAST((SELECT SUM(net_sales) FROM analytics.vw_sales_2014) AS DECIMAL(18,2)),
        CAST((SELECT SUM(monthly_net_sales) FROM monthly_sales) AS DECIMAL(18,2))

    UNION ALL

    SELECT
        N'Gross Sales minus Discount Amount equals Net Sales',
        CAST((SELECT SUM(gross_sales) - SUM(discount_amount)
              FROM analytics.vw_sales_2014) AS DECIMAL(18,2)),
        CAST((SELECT SUM(net_sales)
              FROM analytics.vw_sales_2014) AS DECIMAL(18,2))
)
SELECT
    check_name,
    expected_value,
    actual_value,
    CASE WHEN ABS(expected_value - actual_value) <= 0.01 THEN N'PASS' ELSE N'FAIL' END AS result
FROM checks;
GO
