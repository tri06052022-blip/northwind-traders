/*
    Northwind Sales Performance Analysis 2014
    Step 10: Prepare a star-schema model for Power BI.

    Model:
    - vw_fact_sales_2014: one product line in one order.
    - vw_dim_date_2014: one calendar date.
    - vw_dim_product_2014: one product.
    - vw_dim_customer_2014: one active customer.
    - vw_dim_employee_2014: one employee.
*/

USE NorthwindAnalytics;
GO

SET NOCOUNT ON;

IF OBJECT_ID(N'analytics.vw_sales_2014', N'V') IS NULL
    THROW 51180, 'Run create_sales_analytics_views.sql first.', 1;

IF OBJECT_ID(N'analytics.vw_product_performance_2014', N'V') IS NULL
    THROW 51181, 'Run analyze_product_performance.sql first.', 1;

IF OBJECT_ID(N'analytics.vw_customer_rfm_2014', N'V') IS NULL
    THROW 51182, 'Run analyze_customer_rfm.sql first.', 1;

IF OBJECT_ID(N'analytics.vw_employee_contribution_2014', N'V') IS NULL
    THROW 51183, 'Run analyze_employee_discounts.sql first.', 1;
GO

CREATE OR ALTER VIEW analytics.vw_fact_sales_2014
AS
SELECT
    order_id,
    product_id,
    order_date,
    customer_id,
    employee_id,
    selling_unit_price,
    quantity,
    discount_rate,
    gross_sales,
    discount_amount,
    net_sales
FROM analytics.vw_sales_2014;
GO

CREATE OR ALTER VIEW analytics.vw_dim_date_2014
AS
WITH digits AS
(
    SELECT digit
    FROM (VALUES (0), (1), (2), (3), (4),
                 (5), (6), (7), (8), (9)) AS d(digit)
),
numbers AS
(
    SELECT
        ones.digit
        + tens.digit * 10
        + hundreds.digit * 100 AS day_offset
    FROM digits AS ones
    CROSS JOIN digits AS tens
    CROSS JOIN digits AS hundreds
),
calendar AS
(
    SELECT DATEADD(DAY, day_offset, CAST('20140101' AS DATE)) AS calendar_date
    FROM numbers
    WHERE day_offset < DATEDIFF(DAY, '20140101', '20150101')
)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), calendar_date, 112)) AS date_key,
    calendar_date AS full_date,
    YEAR(calendar_date) AS calendar_year,
    DATEPART(QUARTER, calendar_date) AS quarter_number,
    CONCAT(N'Q', DATEPART(QUARTER, calendar_date)) AS quarter_name,
    MONTH(calendar_date) AS month_number,
    DATENAME(MONTH, calendar_date) AS month_name,
    CONVERT(CHAR(7), calendar_date, 120) AS year_month,
    YEAR(calendar_date) * 100 + MONTH(calendar_date) AS year_month_sort,
    DATEFROMPARTS(YEAR(calendar_date), MONTH(calendar_date), 1) AS month_start,
    DAY(calendar_date) AS day_of_month,
    DATEDIFF(DAY, '19000101', calendar_date) % 7 + 1 AS weekday_number_monday,
    DATENAME(WEEKDAY, calendar_date) AS weekday_name
FROM calendar;
GO

CREATE OR ALTER VIEW analytics.vw_dim_product_2014
AS
SELECT
    product_id,
    product_name,
    category_id,
    category_name,
    discontinued,
    net_sales_rank,
    net_sales_share_percent,
    cumulative_net_sales_percent,
    abc_class
FROM analytics.vw_product_performance_2014;
GO

CREATE OR ALTER VIEW analytics.vw_dim_customer_2014
AS
SELECT
    customer_id,
    customer_name,
    customer_city,
    customer_country,
    rfm_reference_date,
    last_order_date,
    recency_days,
    frequency_orders,
    monetary_value,
    average_order_value,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_score,
    rfm_segment,
    net_sales_rank,
    net_sales_share_percent,
    cumulative_net_sales_percent
FROM analytics.vw_customer_rfm_2014;
GO

CREATE OR ALTER VIEW analytics.vw_dim_employee_2014
AS
SELECT
    employee_id,
    employee_name,
    title,
    city,
    country,
    manager_id,
    net_sales_rank,
    net_sales_share_percent,
    weighted_discount_percent
FROM analytics.vw_employee_contribution_2014;
GO

/* 1. Confirm all Power BI views exist. */
SELECT N'1. Power BI model views' AS result_set;

SELECT
    s.name AS schema_name,
    v.name AS view_name
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
WHERE s.name = N'analytics'
  AND v.name IN
  (
      N'vw_fact_sales_2014',
      N'vw_dim_date_2014',
      N'vw_dim_product_2014',
      N'vw_dim_customer_2014',
      N'vw_dim_employee_2014'
  )
ORDER BY v.name;

/* 2. Validate row counts. */
SELECT N'2. Power BI model row counts' AS result_set;

SELECT N'Fact Sales' AS model_table, COUNT(*) AS row_count
FROM analytics.vw_fact_sales_2014
UNION ALL
SELECT N'Dim Date', COUNT(*) FROM analytics.vw_dim_date_2014
UNION ALL
SELECT N'Dim Product', COUNT(*) FROM analytics.vw_dim_product_2014
UNION ALL
SELECT N'Dim Customer', COUNT(*) FROM analytics.vw_dim_customer_2014
UNION ALL
SELECT N'Dim Employee', COUNT(*) FROM analytics.vw_dim_employee_2014;

/* 3. Validate dimension keys and fact totals. */
SELECT N'3. Power BI model validation' AS result_set;

SELECT
    check_name,
    issue_count,
    CASE WHEN issue_count = 0 THEN N'PASS' ELSE N'FAIL' END AS result
FROM
(
    SELECT
        N'Duplicate date key' AS check_name,
        COUNT(*) AS issue_count
    FROM
    (
        SELECT full_date
        FROM analytics.vw_dim_date_2014
        GROUP BY full_date
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT N'Duplicate product key', COUNT(*)
    FROM
    (
        SELECT product_id
        FROM analytics.vw_dim_product_2014
        GROUP BY product_id
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT N'Duplicate customer key', COUNT(*)
    FROM
    (
        SELECT customer_id
        FROM analytics.vw_dim_customer_2014
        GROUP BY customer_id
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT N'Duplicate employee key', COUNT(*)
    FROM
    (
        SELECT employee_id
        FROM analytics.vw_dim_employee_2014
        GROUP BY employee_id
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT
        N'Fact row count differs from 2014 sales view',
        ABS(
            (SELECT COUNT(*) FROM analytics.vw_fact_sales_2014)
            - (SELECT COUNT(*) FROM analytics.vw_sales_2014)
        )

    UNION ALL

    SELECT
        N'Fact Net Sales differs from 2014 sales view',
        CASE
            WHEN ABS(
                (SELECT SUM(net_sales) FROM analytics.vw_fact_sales_2014)
                - (SELECT SUM(net_sales) FROM analytics.vw_sales_2014)
            ) <= 0.01 THEN 0 ELSE 1
        END

    UNION ALL

    SELECT
        N'Date dimension does not contain exactly 365 days',
        ABS((SELECT COUNT(*) FROM analytics.vw_dim_date_2014) - 365)
) AS checks;

/* Relationship map for Power BI. */
SELECT N'4. Relationships to create in Power BI' AS result_set;

SELECT N'vw_dim_date_2014[full_date]' AS one_side,
       N'vw_fact_sales_2014[order_date]' AS many_side
UNION ALL
SELECT N'vw_dim_product_2014[product_id]', N'vw_fact_sales_2014[product_id]'
UNION ALL
SELECT N'vw_dim_customer_2014[customer_id]', N'vw_fact_sales_2014[customer_id]'
UNION ALL
SELECT N'vw_dim_employee_2014[employee_id]', N'vw_fact_sales_2014[employee_id]';
GO
