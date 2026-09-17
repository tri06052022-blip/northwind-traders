/*
    Northwind Sales Performance Analysis 2014
    Step 5: Create reusable analytical views.

    Grain: one row per product in one order (orderID + productID).
    The raw tables remain unchanged.
*/

USE NorthwindAnalytics;
GO

/* Full-history view: useful for validation and future analysis. */
CREATE OR ALTER VIEW analytics.vw_sales_detail
AS
SELECT
    o.orderID AS order_id,
    od.productID AS product_id,
    o.orderDate AS order_date,
    YEAR(o.orderDate) AS order_year,
    MONTH(o.orderDate) AS order_month,
    DATEFROMPARTS(YEAR(o.orderDate), MONTH(o.orderDate), 1) AS month_start,

    o.customerID AS customer_id,
    cu.companyName AS customer_name,
    cu.city AS customer_city,
    cu.country AS customer_country,

    o.employeeID AS employee_id,
    e.employeeName AS employee_name,

    p.productName AS product_name,
    p.categoryID AS category_id,
    c.categoryName AS category_name,
    p.discontinued,

    od.unitPrice AS selling_unit_price,
    od.quantity,
    od.discount AS discount_rate,
    CAST(od.unitPrice * od.quantity AS DECIMAL(19,4)) AS gross_sales,
    CAST(od.unitPrice * od.quantity * od.discount AS DECIMAL(19,4)) AS discount_amount,
    CAST(od.unitPrice * od.quantity * (1 - od.discount) AS DECIMAL(19,4)) AS net_sales
FROM raw.orders AS o
INNER JOIN raw.order_details AS od
    ON od.orderID = o.orderID
INNER JOIN raw.customers AS cu
    ON cu.customerID = o.customerID
INNER JOIN raw.employees AS e
    ON e.employeeID = o.employeeID
INNER JOIN raw.products AS p
    ON p.productID = od.productID
INNER JOIN raw.categories AS c
    ON c.categoryID = p.categoryID;
GO

/* Reporting view: only transactions placed during calendar year 2014. */
CREATE OR ALTER VIEW analytics.vw_sales_2014
AS
SELECT
    order_id,
    product_id,
    order_date,
    order_year,
    order_month,
    month_start,
    customer_id,
    customer_name,
    customer_city,
    customer_country,
    employee_id,
    employee_name,
    product_name,
    category_id,
    category_name,
    discontinued,
    selling_unit_price,
    quantity,
    discount_rate,
    gross_sales,
    discount_amount,
    net_sales
FROM analytics.vw_sales_detail
WHERE order_date >= '20140101'
  AND order_date <  '20150101';
GO

/* Verification results. */
SELECT N'1. Analytics views created' AS result_set;

SELECT
    s.name AS schema_name,
    v.name AS view_name
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
WHERE s.name = N'analytics'
  AND v.name IN (N'vw_sales_detail', N'vw_sales_2014')
ORDER BY v.name;

SELECT N'2. Row-count validation' AS result_set;

SELECT
    check_name,
    expected_rows,
    actual_rows,
    CASE WHEN expected_rows = actual_rows THEN N'PASS' ELSE N'FAIL' END AS result
FROM
(
    SELECT
        N'Full-history view matches raw order lines' AS check_name,
        (SELECT COUNT(*) FROM raw.order_details) AS expected_rows,
        (SELECT COUNT(*) FROM analytics.vw_sales_detail) AS actual_rows

    UNION ALL

    SELECT
        N'2014 view matches raw 2014 order lines',
        (
            SELECT COUNT(*)
            FROM raw.orders AS o
            INNER JOIN raw.order_details AS od
                ON od.orderID = o.orderID
            WHERE o.orderDate >= '20140101'
              AND o.orderDate <  '20150101'
        ),
        (SELECT COUNT(*) FROM analytics.vw_sales_2014)
) AS row_checks;

SELECT N'3. Grain and calculation validation' AS result_set;

SELECT
    check_name,
    issue_count,
    CASE WHEN issue_count = 0 THEN N'PASS' ELSE N'FAIL' END AS result
FROM
(
    SELECT
        N'Duplicate order_id + product_id' AS check_name,
        COUNT(*) AS issue_count
    FROM
    (
        SELECT order_id, product_id
        FROM analytics.vw_sales_detail
        GROUP BY order_id, product_id
        HAVING COUNT(*) > 1
    ) AS duplicate_grain

    UNION ALL

    SELECT
        N'Rows outside 2014 in reporting view',
        COUNT(*)
    FROM analytics.vw_sales_2014
    WHERE order_date < '20140101'
       OR order_date >= '20150101'

    UNION ALL

    SELECT
        N'Net Sales calculation mismatch',
        COUNT(*)
    FROM analytics.vw_sales_detail
    WHERE ABS(net_sales - CAST(selling_unit_price * quantity * (1 - discount_rate)
                               AS DECIMAL(19,4))) > 0.0001

    UNION ALL

    SELECT
        N'Gross Sales differs from Discount Amount + Net Sales',
        COUNT(*)
    FROM analytics.vw_sales_detail
    WHERE ABS(gross_sales - discount_amount - net_sales) > 0.0001
) AS quality_checks;

SELECT N'4. 2014 analytical snapshot' AS result_set;

SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS active_customers,
    SUM(quantity) AS units_sold,
    CAST(SUM(gross_sales) AS DECIMAL(18,2)) AS gross_sales,
    CAST(SUM(discount_amount) AS DECIMAL(18,2)) AS discount_amount,
    CAST(SUM(net_sales) AS DECIMAL(18,2)) AS net_sales
FROM analytics.vw_sales_2014;
GO
