/*
    Northwind Sales Performance Analysis 2014
    Step 7: Product performance and ABC analysis.

    ABC rule based on cumulative 2014 Net Sales:
    - A: products needed to reach approximately 80%.
    - B: next products needed to reach approximately 95%.
    - C: remaining products.
*/

USE NorthwindAnalytics;
GO

SET NOCOUNT ON;

IF OBJECT_ID(N'analytics.vw_sales_2014', N'V') IS NULL
    THROW 51150, 'Run create_sales_analytics_views.sql first.', 1;
GO

CREATE OR ALTER VIEW analytics.vw_product_performance_2014
AS
WITH product_base AS
(
    SELECT
        p.productID AS product_id,
        p.productName AS product_name,
        p.categoryID AS category_id,
        c.categoryName AS category_name,
        p.discontinued,
        COUNT(DISTINCT s.order_id) AS total_orders,
        COUNT(DISTINCT s.customer_id) AS purchasing_customers,
        COALESCE(SUM(s.quantity), 0) AS units_sold,
        COALESCE(SUM(s.gross_sales), 0) AS gross_sales,
        COALESCE(SUM(s.discount_amount), 0) AS discount_amount,
        COALESCE(SUM(s.net_sales), 0) AS net_sales
    FROM raw.products AS p
    INNER JOIN raw.categories AS c
        ON c.categoryID = p.categoryID
    LEFT JOIN analytics.vw_sales_2014 AS s
        ON s.product_id = p.productID
    GROUP BY
        p.productID,
        p.productName,
        p.categoryID,
        c.categoryName,
        p.discontinued
),
ranked AS
(
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY net_sales DESC, product_id) AS net_sales_rank,
        SUM(net_sales) OVER () AS total_portfolio_net_sales,
        SUM(net_sales) OVER
        (
            ORDER BY net_sales DESC, product_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_net_sales,
        SUM(net_sales) OVER
        (
            ORDER BY net_sales DESC, product_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_cumulative_net_sales
    FROM product_base
)
SELECT
    product_id,
    product_name,
    category_id,
    category_name,
    discontinued,
    total_orders,
    purchasing_customers,
    units_sold,
    CAST(gross_sales AS DECIMAL(19,4)) AS gross_sales,
    CAST(discount_amount AS DECIMAL(19,4)) AS discount_amount,
    CAST(net_sales AS DECIMAL(19,4)) AS net_sales,
    CAST(
        net_sales * 100.0 / NULLIF(total_portfolio_net_sales, 0)
        AS DECIMAL(7,2)
    ) AS net_sales_share_percent,
    CAST(
        cumulative_net_sales * 100.0 / NULLIF(total_portfolio_net_sales, 0)
        AS DECIMAL(7,2)
    ) AS cumulative_net_sales_percent,
    net_sales_rank,
    CASE
        WHEN total_portfolio_net_sales = 0 THEN N'C'
        WHEN COALESCE(previous_cumulative_net_sales, 0) < total_portfolio_net_sales * 0.80 THEN N'A'
        WHEN COALESCE(previous_cumulative_net_sales, 0) < total_portfolio_net_sales * 0.95 THEN N'B'
        ELSE N'C'
    END AS abc_class
FROM ranked;
GO

/* 1. Ten highest-selling products. */
SELECT N'1. Top 10 products by Net Sales' AS result_set;

SELECT TOP (10)
    net_sales_rank,
    product_id,
    product_name,
    category_name,
    units_sold,
    total_orders,
    CAST(net_sales AS DECIMAL(18,2)) AS net_sales,
    net_sales_share_percent,
    cumulative_net_sales_percent,
    abc_class
FROM analytics.vw_product_performance_2014
ORDER BY net_sales_rank;

/* 2. ABC portfolio summary. */
SELECT N'2. ABC product summary' AS result_set;

SELECT
    abc_class,
    COUNT(*) AS total_products,
    SUM(units_sold) AS units_sold,
    CAST(SUM(net_sales) AS DECIMAL(18,2)) AS net_sales,
    CAST(
        SUM(net_sales) * 100.0
        / NULLIF((SELECT SUM(net_sales) FROM analytics.vw_product_performance_2014), 0)
        AS DECIMAL(7,2)
    ) AS net_sales_share_percent
FROM analytics.vw_product_performance_2014
GROUP BY abc_class
ORDER BY abc_class;

/* 3. Full product list for Pareto and ABC inspection. */
SELECT N'3. Full ABC product list' AS result_set;

SELECT
    net_sales_rank,
    product_id,
    product_name,
    category_name,
    discontinued,
    units_sold,
    total_orders,
    purchasing_customers,
    CAST(net_sales AS DECIMAL(18,2)) AS net_sales,
    net_sales_share_percent,
    cumulative_net_sales_percent,
    abc_class
FROM analytics.vw_product_performance_2014
ORDER BY net_sales_rank;

/* 4. Category performance. */
SELECT N'4. Category performance' AS result_set;

SELECT
    category_id,
    category_name,
    COUNT(*) AS total_products,
    SUM(CASE WHEN discontinued = 1 THEN 1 ELSE 0 END) AS discontinued_products,
    SUM(units_sold) AS units_sold,
    CAST(SUM(gross_sales) AS DECIMAL(18,2)) AS gross_sales,
    CAST(SUM(discount_amount) AS DECIMAL(18,2)) AS discount_amount,
    CAST(SUM(net_sales) AS DECIMAL(18,2)) AS net_sales,
    CAST(
        SUM(net_sales) * 100.0
        / NULLIF((SELECT SUM(net_sales) FROM analytics.vw_product_performance_2014), 0)
        AS DECIMAL(7,2)
    ) AS net_sales_share_percent,
    RANK() OVER (ORDER BY SUM(net_sales) DESC) AS net_sales_rank
FROM analytics.vw_product_performance_2014
GROUP BY category_id, category_name
ORDER BY net_sales_rank, category_id;

/* 5. Validate grain and totals. */
SELECT N'5. Product-analysis validation' AS result_set;

SELECT
    check_name,
    issue_count,
    CASE WHEN issue_count = 0 THEN N'PASS' ELSE N'FAIL' END AS result
FROM
(
    SELECT
        N'Product view row count differs from product catalog' AS check_name,
        ABS(
            (SELECT COUNT(*) FROM analytics.vw_product_performance_2014)
            - (SELECT COUNT(*) FROM raw.products)
        ) AS issue_count

    UNION ALL

    SELECT
        N'Duplicate product_id in product view',
        COUNT(*)
    FROM
    (
        SELECT product_id
        FROM analytics.vw_product_performance_2014
        GROUP BY product_id
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT
        N'Product Net Sales differs from 2014 sales view',
        CASE
            WHEN ABS(
                (SELECT SUM(net_sales) FROM analytics.vw_product_performance_2014)
                - (SELECT SUM(net_sales) FROM analytics.vw_sales_2014)
            ) <= 0.01 THEN 0 ELSE 1
        END

    UNION ALL

    SELECT
        N'Product without ABC class',
        COUNT(*)
    FROM analytics.vw_product_performance_2014
    WHERE abc_class IS NULL

    UNION ALL

    SELECT
        N'Final cumulative share differs from 100 percent',
        CASE
            WHEN ABS(MAX(cumulative_net_sales_percent) - 100.00) <= 0.01 THEN 0 ELSE 1
        END
    FROM analytics.vw_product_performance_2014
) AS checks;
GO
