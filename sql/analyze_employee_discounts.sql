/*
    Northwind Sales Performance Analysis 2014
    Step 9: Employee contribution and discount analysis.

    Important interpretation:
    - Employee results describe sales contribution, not overall performance.
    - Discount results show association only, not causation.
*/

USE NorthwindAnalytics;
GO

SET NOCOUNT ON;

IF OBJECT_ID(N'analytics.vw_sales_2014', N'V') IS NULL
    THROW 51170, 'Run create_sales_analytics_views.sql first.', 1;
GO

CREATE OR ALTER VIEW analytics.vw_employee_contribution_2014
AS
WITH employee_base AS
(
    SELECT
        e.employeeID AS employee_id,
        e.employeeName AS employee_name,
        e.title,
        e.city,
        e.country,
        e.reportsTo AS manager_id,
        COUNT(DISTINCT s.order_id) AS total_orders,
        COUNT(DISTINCT s.customer_id) AS served_customers,
        COALESCE(SUM(s.quantity), 0) AS units_sold,
        COALESCE(SUM(s.gross_sales), 0) AS gross_sales,
        COALESCE(SUM(s.discount_amount), 0) AS discount_amount,
        COALESCE(SUM(s.net_sales), 0) AS net_sales
    FROM raw.employees AS e
    LEFT JOIN analytics.vw_sales_2014 AS s
        ON s.employee_id = e.employeeID
    GROUP BY
        e.employeeID,
        e.employeeName,
        e.title,
        e.city,
        e.country,
        e.reportsTo
)
SELECT
    employee_id,
    employee_name,
    title,
    city,
    country,
    manager_id,
    total_orders,
    served_customers,
    units_sold,
    CAST(gross_sales AS DECIMAL(19,4)) AS gross_sales,
    CAST(discount_amount AS DECIMAL(19,4)) AS discount_amount,
    CAST(net_sales AS DECIMAL(19,4)) AS net_sales,
    CAST(net_sales / NULLIF(total_orders, 0) AS DECIMAL(19,4)) AS average_order_value,
    CAST(
        discount_amount * 100.0 / NULLIF(gross_sales, 0)
        AS DECIMAL(7,2)
    ) AS weighted_discount_percent,
    CAST(
        net_sales * 100.0 / NULLIF(SUM(net_sales) OVER (), 0)
        AS DECIMAL(7,2)
    ) AS net_sales_share_percent,
    RANK() OVER (ORDER BY net_sales DESC) AS net_sales_rank
FROM employee_base;
GO

/* 1. Employee contribution to 2014 sales. */
SELECT N'1. Employee sales contribution' AS result_set;

SELECT
    net_sales_rank,
    employee_id,
    employee_name,
    title,
    total_orders,
    served_customers,
    units_sold,
    CAST(net_sales AS DECIMAL(18,2)) AS net_sales,
    CAST(average_order_value AS DECIMAL(18,2)) AS average_order_value,
    weighted_discount_percent,
    net_sales_share_percent
FROM analytics.vw_employee_contribution_2014
ORDER BY net_sales_rank, employee_id;

/*
    Discount bands:
    None   = 0%
    Low    = above 0% through 10%
    Medium = above 10% through 20%
    High   = above 20%
*/

/* 2. Overall sales by discount band. */
SELECT N'2. Discount-band summary (association only)' AS result_set;

;WITH discount_lines AS
(
    SELECT
        *,
        CASE
            WHEN discount_rate = 0 THEN N'None'
            WHEN discount_rate <= 0.10 THEN N'Low'
            WHEN discount_rate <= 0.20 THEN N'Medium'
            ELSE N'High'
        END AS discount_band,
        CASE
            WHEN discount_rate = 0 THEN 1
            WHEN discount_rate <= 0.10 THEN 2
            WHEN discount_rate <= 0.20 THEN 3
            ELSE 4
        END AS band_order
    FROM analytics.vw_sales_2014
)
SELECT
    discount_band,
    COUNT(*) AS order_lines,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS units_sold,
    CAST(AVG(CAST(quantity AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS avg_units_per_line,
    CAST(SUM(gross_sales) AS DECIMAL(18,2)) AS gross_sales,
    CAST(SUM(discount_amount) AS DECIMAL(18,2)) AS discount_amount,
    CAST(SUM(net_sales) AS DECIMAL(18,2)) AS net_sales,
    CAST(
        SUM(net_sales) * 100.0
        / NULLIF((SELECT SUM(net_sales) FROM analytics.vw_sales_2014), 0)
        AS DECIMAL(7,2)
    ) AS net_sales_share_percent
FROM discount_lines
GROUP BY discount_band, band_order
ORDER BY band_order;

/* 3. Discount profile for each employee. */
SELECT N'3. Employee discount profile' AS result_set;

;WITH discount_lines AS
(
    SELECT
        *,
        CASE
            WHEN discount_rate = 0 THEN N'None'
            WHEN discount_rate <= 0.10 THEN N'Low'
            WHEN discount_rate <= 0.20 THEN N'Medium'
            ELSE N'High'
        END AS discount_band,
        CASE
            WHEN discount_rate = 0 THEN 1
            WHEN discount_rate <= 0.10 THEN 2
            WHEN discount_rate <= 0.20 THEN 3
            ELSE 4
        END AS band_order
    FROM analytics.vw_sales_2014
),
employee_bands AS
(
    SELECT
        employee_id,
        employee_name,
        discount_band,
        band_order,
        COUNT(*) AS order_lines,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(gross_sales) AS gross_sales,
        SUM(discount_amount) AS discount_amount,
        SUM(net_sales) AS net_sales
    FROM discount_lines
    GROUP BY employee_id, employee_name, discount_band, band_order
)
SELECT
    employee_id,
    employee_name,
    discount_band,
    order_lines,
    total_orders,
    CAST(gross_sales AS DECIMAL(18,2)) AS gross_sales,
    CAST(discount_amount AS DECIMAL(18,2)) AS discount_amount,
    CAST(net_sales AS DECIMAL(18,2)) AS net_sales,
    CAST(
        gross_sales * 100.0
        / NULLIF(SUM(gross_sales) OVER (PARTITION BY employee_id), 0)
        AS DECIMAL(7,2)
    ) AS employee_gross_sales_share_percent
FROM employee_bands
ORDER BY employee_id, band_order;

/* 4. Products with the greatest exposure to discounted sales. */
SELECT N'4. Product discount exposure' AS result_set;

SELECT TOP (15)
    product_id,
    product_name,
    category_name,
    CAST(SUM(gross_sales) AS DECIMAL(18,2)) AS total_gross_sales,
    CAST(
        SUM(CASE WHEN discount_rate > 0 THEN gross_sales ELSE 0 END)
        AS DECIMAL(18,2)
    ) AS discounted_gross_sales,
    CAST(
        SUM(CASE WHEN discount_rate > 0 THEN gross_sales ELSE 0 END) * 100.0
        / NULLIF(SUM(gross_sales), 0)
        AS DECIMAL(7,2)
    ) AS discounted_sales_exposure_percent,
    CAST(
        SUM(discount_amount) * 100.0 / NULLIF(SUM(gross_sales), 0)
        AS DECIMAL(7,2)
    ) AS weighted_discount_percent,
    CAST(SUM(net_sales) AS DECIMAL(18,2)) AS net_sales
FROM analytics.vw_sales_2014
GROUP BY product_id, product_name, category_name
ORDER BY discounted_sales_exposure_percent DESC, total_gross_sales DESC, product_id;

/* 5. Validate employee grain and totals. */
SELECT N'5. Employee and discount validation' AS result_set;

SELECT
    check_name,
    issue_count,
    CASE WHEN issue_count = 0 THEN N'PASS' ELSE N'FAIL' END AS result
FROM
(
    SELECT
        N'Employee view row count differs from employee table' AS check_name,
        ABS(
            (SELECT COUNT(*) FROM analytics.vw_employee_contribution_2014)
            - (SELECT COUNT(*) FROM raw.employees)
        ) AS issue_count

    UNION ALL

    SELECT
        N'Duplicate employee_id in employee view',
        COUNT(*)
    FROM
    (
        SELECT employee_id
        FROM analytics.vw_employee_contribution_2014
        GROUP BY employee_id
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT
        N'Employee Net Sales differs from 2014 sales view',
        CASE
            WHEN ABS(
                (SELECT SUM(net_sales) FROM analytics.vw_employee_contribution_2014)
                - (SELECT SUM(net_sales) FROM analytics.vw_sales_2014)
            ) <= 0.01 THEN 0 ELSE 1
        END

    UNION ALL

    SELECT
        N'Discount band does not cover every order line',
        ABS
        (
            (SELECT COUNT(*) FROM analytics.vw_sales_2014)
            -
            (
                SELECT COUNT(*)
                FROM analytics.vw_sales_2014
                WHERE discount_rate = 0
                   OR discount_rate BETWEEN 0.0001 AND 0.10
                   OR discount_rate > 0.10 AND discount_rate <= 0.20
                   OR discount_rate > 0.20
            )
        )
) AS checks;
GO
