/*
    Northwind Sales Performance Analysis 2014
    Step 3: Explore and understand the imported data.

    This script is read-only:
    - It does not insert, update, delete, or create database objects.
    - Run the whole file once and review each result set in order.
*/

USE NorthwindAnalytics;
GO

SET NOCOUNT ON;

/* 1. Inventory: how many rows are in each source table? */
SELECT N'1. Table inventory' AS result_set;

SELECT N'categories' AS table_name, COUNT(*) AS row_count FROM raw.categories
UNION ALL
SELECT N'customers', COUNT(*) FROM raw.customers
UNION ALL
SELECT N'employees', COUNT(*) FROM raw.employees
UNION ALL
SELECT N'order_details', COUNT(*) FROM raw.order_details
UNION ALL
SELECT N'orders', COUNT(*) FROM raw.orders
UNION ALL
SELECT N'products', COUNT(*) FROM raw.products
UNION ALL
SELECT N'shippers', COUNT(*) FROM raw.shippers
ORDER BY table_name;

/* 2. Structure: which columns and data types does each table contain? */
SELECT N'2. Table structure' AS result_set;

SELECT
    t.name AS table_name,
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c
    ON c.object_id = t.object_id
WHERE s.name = N'raw'
ORDER BY t.name, c.column_id;

/* 3. Time coverage: which years are complete or partial? */
SELECT N'3. Order coverage by year' AS result_set;

SELECT
    YEAR(orderDate) AS order_year,
    MIN(orderDate) AS first_order_date,
    MAX(orderDate) AS last_order_date,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT customerID) AS active_customers
FROM raw.orders
GROUP BY YEAR(orderDate)
ORDER BY order_year;

/* 4. Reporting period: activity in every month of 2014. */
SELECT N'4. Monthly activity in 2014' AS result_set;

;WITH months AS
(
    SELECT month_no
    FROM (VALUES (1), (2), (3), (4), (5), (6),
                 (7), (8), (9), (10), (11), (12)) AS m(month_no)
),
monthly_orders AS
(
    SELECT
        MONTH(orderDate) AS month_no,
        COUNT(*) AS total_orders,
        COUNT(DISTINCT customerID) AS active_customers
    FROM raw.orders
    WHERE orderDate >= '20140101'
      AND orderDate <  '20150101'
    GROUP BY MONTH(orderDate)
)
SELECT
    m.month_no,
    DATENAME(MONTH, DATEFROMPARTS(2014, m.month_no, 1)) AS month_name,
    COALESCE(o.total_orders, 0) AS total_orders,
    COALESCE(o.active_customers, 0) AS active_customers
FROM months AS m
LEFT JOIN monthly_orders AS o
    ON o.month_no = m.month_no
ORDER BY m.month_no;

/* 5. Business coverage: basic scale of the dataset. */
SELECT N'5. Business coverage' AS result_set;

SELECT
    (SELECT COUNT(*) FROM raw.customers) AS total_customers,
    (SELECT COUNT(DISTINCT country) FROM raw.customers) AS customer_countries,
    (SELECT COUNT(*) FROM raw.products) AS total_products,
    (SELECT COUNT(*) FROM raw.categories) AS total_categories,
    (SELECT COUNT(*) FROM raw.employees) AS total_employees,
    (SELECT COUNT(*) FROM raw.shippers) AS total_shippers,
    (SELECT COUNT(*) FROM raw.orders) AS total_orders,
    (SELECT COUNT(*) FROM raw.order_details) AS total_order_lines;

/* 6A. Customer distribution by country. */
SELECT N'6A. Customers by country' AS result_set;

SELECT
    country,
    COUNT(*) AS total_customers
FROM raw.customers
GROUP BY country
ORDER BY total_customers DESC, country;

/* 6B. Product distribution by category. */
SELECT N'6B. Products by category' AS result_set;

SELECT
    c.categoryID,
    c.categoryName,
    COUNT(p.productID) AS total_products,
    SUM(CASE WHEN p.discontinued = 1 THEN 1 ELSE 0 END) AS discontinued_products
FROM raw.categories AS c
LEFT JOIN raw.products AS p
    ON p.categoryID = c.categoryID
GROUP BY c.categoryID, c.categoryName
ORDER BY total_products DESC, c.categoryID;

/* 7. Numeric ranges: understand the scale of price, quantity, discount, and freight. */
SELECT N'7A. Order-line numeric ranges' AS result_set;

SELECT
    MIN(unitPrice) AS min_unit_price,
    MAX(unitPrice) AS max_unit_price,
    CAST(AVG(unitPrice) AS DECIMAL(12,2)) AS avg_unit_price,
    MIN(quantity) AS min_quantity,
    MAX(quantity) AS max_quantity,
    CAST(AVG(CAST(quantity AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS avg_quantity,
    MIN(discount) AS min_discount,
    MAX(discount) AS max_discount,
    CAST(AVG(discount) AS DECIMAL(6,4)) AS avg_discount
FROM raw.order_details;

SELECT N'7B. Order freight range' AS result_set;

SELECT
    MIN(freight) AS min_freight,
    MAX(freight) AS max_freight,
    CAST(AVG(freight) AS DECIMAL(12,2)) AS avg_freight
FROM raw.orders;

/* 8. A readable sample showing how the main tables connect. */
SELECT N'8. Joined transaction sample' AS result_set;

SELECT TOP (10)
    o.orderID,
    o.orderDate,
    cu.companyName AS customer_name,
    cu.country AS customer_country,
    e.employeeName,
    p.productName,
    c.categoryName,
    od.unitPrice,
    od.quantity,
    od.discount,
    CAST(od.unitPrice * od.quantity AS DECIMAL(14,2)) AS gross_sales,
    CAST(od.unitPrice * od.quantity * (1 - od.discount) AS DECIMAL(14,2)) AS net_sales
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
    ON c.categoryID = p.categoryID
ORDER BY o.orderDate, o.orderID, p.productID;

/* 9. Final snapshot for the chosen reporting period: calendar year 2014. */
SELECT N'9. Reporting-period snapshot: 2014' AS result_set;

SELECT
    MIN(o.orderDate) AS first_order_date,
    MAX(o.orderDate) AS last_order_date,
    COUNT(DISTINCT o.orderID) AS total_orders,
    COUNT(DISTINCT o.customerID) AS active_customers,
    COUNT(DISTINCT od.productID) AS products_sold,
    SUM(od.quantity) AS units_sold,
    CAST(SUM(od.unitPrice * od.quantity) AS DECIMAL(18,2)) AS gross_sales,
    CAST(SUM(od.unitPrice * od.quantity * (1 - od.discount)) AS DECIMAL(18,2)) AS net_sales
FROM raw.orders AS o
INNER JOIN raw.order_details AS od
    ON od.orderID = o.orderID
WHERE o.orderDate >= '20140101'
  AND o.orderDate <  '20150101';
GO
