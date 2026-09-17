/*
    Northwind Sales Performance Analysis 2014
    Step 4: Data quality checks.

    Status:
    - PASS   : no issue found.
    - REVIEW : valid business exception or coverage gap to review.
    - FAIL   : data issue that can make the analysis incorrect.

    Scope:
    - Most checks use the full raw dataset.
    - The month-coverage check uses the 2014 reporting period.
    - This script does not modify the raw tables.
*/

USE NorthwindAnalytics;
GO

SET NOCOUNT ON;

DROP TABLE IF EXISTS #dq_checks;

CREATE TABLE #dq_checks
(
    check_order     INT            NOT NULL,
    check_group     NVARCHAR(50)   NOT NULL,
    check_name      NVARCHAR(150)  NOT NULL,
    issue_count     BIGINT         NOT NULL,
    total_rows      BIGINT         NOT NULL,
    status_if_found NVARCHAR(10)   NOT NULL,
    explanation     NVARCHAR(300)  NOT NULL
);

/* 1. Uniqueness: one row must match the intended grain. */
INSERT INTO #dq_checks
VALUES
(
    1, N'Uniqueness', N'Duplicate orderID',
    (SELECT COUNT(*) FROM
        (SELECT orderID FROM raw.orders GROUP BY orderID HAVING COUNT(*) > 1) AS d),
    (SELECT COUNT(*) FROM raw.orders), N'FAIL',
    N'Each orderID must represent exactly one order.'
),
(
    2, N'Uniqueness', N'Duplicate orderID + productID',
    (SELECT COUNT(*) FROM
        (SELECT orderID, productID FROM raw.order_details
         GROUP BY orderID, productID HAVING COUNT(*) > 1) AS d),
    (SELECT COUNT(*) FROM raw.order_details), N'FAIL',
    N'Each product must appear at most once within an order.'
),
(
    3, N'Uniqueness', N'Duplicate customerID',
    (SELECT COUNT(*) FROM
        (SELECT customerID FROM raw.customers GROUP BY customerID HAVING COUNT(*) > 1) AS d),
    (SELECT COUNT(*) FROM raw.customers), N'FAIL',
    N'Each customerID must identify one customer.'
),
(
    4, N'Uniqueness', N'Duplicate productID',
    (SELECT COUNT(*) FROM
        (SELECT productID FROM raw.products GROUP BY productID HAVING COUNT(*) > 1) AS d),
    (SELECT COUNT(*) FROM raw.products), N'FAIL',
    N'Each productID must identify one product.'
),
(
    5, N'Uniqueness', N'Duplicate employeeID',
    (SELECT COUNT(*) FROM
        (SELECT employeeID FROM raw.employees GROUP BY employeeID HAVING COUNT(*) > 1) AS d),
    (SELECT COUNT(*) FROM raw.employees), N'FAIL',
    N'Each employeeID must identify one employee.'
);

/* 2. Completeness: important names and IDs cannot be blank. */
INSERT INTO #dq_checks
VALUES
(
    10, N'Completeness', N'Blank customer ID or company name',
    (SELECT COUNT(*) FROM raw.customers
     WHERE NULLIF(LTRIM(RTRIM(customerID)), N'') IS NULL
        OR NULLIF(LTRIM(RTRIM(companyName)), N'') IS NULL),
    (SELECT COUNT(*) FROM raw.customers), N'FAIL',
    N'Blank customer fields prevent reliable identification and grouping.'
),
(
    11, N'Completeness', N'Blank product name',
    (SELECT COUNT(*) FROM raw.products
     WHERE NULLIF(LTRIM(RTRIM(productName)), N'') IS NULL),
    (SELECT COUNT(*) FROM raw.products), N'FAIL',
    N'Every product must have a usable name.'
),
(
    12, N'Completeness', N'Blank category name',
    (SELECT COUNT(*) FROM raw.categories
     WHERE NULLIF(LTRIM(RTRIM(categoryName)), N'') IS NULL),
    (SELECT COUNT(*) FROM raw.categories), N'FAIL',
    N'Every category must have a usable name.'
),
(
    13, N'Completeness', N'Blank employee name',
    (SELECT COUNT(*) FROM raw.employees
     WHERE NULLIF(LTRIM(RTRIM(employeeName)), N'') IS NULL),
    (SELECT COUNT(*) FROM raw.employees), N'FAIL',
    N'Every employee must have a usable name.'
);

/* 3. Referential integrity: every child key must match its parent table. */
INSERT INTO #dq_checks
VALUES
(
    20, N'Integrity', N'Orders with unknown customer',
    (SELECT COUNT(*) FROM raw.orders AS o
     LEFT JOIN raw.customers AS c ON c.customerID = o.customerID
     WHERE c.customerID IS NULL),
    (SELECT COUNT(*) FROM raw.orders), N'FAIL',
    N'An order without a customer cannot be analyzed by customer.'
),
(
    21, N'Integrity', N'Orders with unknown employee',
    (SELECT COUNT(*) FROM raw.orders AS o
     LEFT JOIN raw.employees AS e ON e.employeeID = o.employeeID
     WHERE e.employeeID IS NULL),
    (SELECT COUNT(*) FROM raw.orders), N'FAIL',
    N'An order without an employee cannot be analyzed by sales representative.'
),
(
    22, N'Integrity', N'Orders with unknown shipper',
    (SELECT COUNT(*) FROM raw.orders AS o
     LEFT JOIN raw.shippers AS s ON s.shipperID = o.shipperID
     WHERE s.shipperID IS NULL),
    (SELECT COUNT(*) FROM raw.orders), N'FAIL',
    N'Every shipperID should match the shippers table.'
),
(
    23, N'Integrity', N'Order lines with unknown order',
    (SELECT COUNT(*) FROM raw.order_details AS od
     LEFT JOIN raw.orders AS o ON o.orderID = od.orderID
     WHERE o.orderID IS NULL),
    (SELECT COUNT(*) FROM raw.order_details), N'FAIL',
    N'Every order line must belong to an existing order.'
),
(
    24, N'Integrity', N'Order lines with unknown product',
    (SELECT COUNT(*) FROM raw.order_details AS od
     LEFT JOIN raw.products AS p ON p.productID = od.productID
     WHERE p.productID IS NULL),
    (SELECT COUNT(*) FROM raw.order_details), N'FAIL',
    N'Every order line must refer to an existing product.'
),
(
    25, N'Integrity', N'Products with unknown category',
    (SELECT COUNT(*) FROM raw.products AS p
     LEFT JOIN raw.categories AS c ON c.categoryID = p.categoryID
     WHERE c.categoryID IS NULL),
    (SELECT COUNT(*) FROM raw.products), N'FAIL',
    N'Every product must belong to an existing category.'
),
(
    26, N'Integrity', N'Employees with unknown manager',
    (SELECT COUNT(*) FROM raw.employees AS e
     LEFT JOIN raw.employees AS manager ON manager.employeeID = e.reportsTo
     WHERE e.reportsTo IS NOT NULL AND manager.employeeID IS NULL),
    (SELECT COUNT(*) FROM raw.employees), N'FAIL',
    N'Every non-null reportsTo value must match another employee.'
),
(
    27, N'Integrity', N'Orders without order lines',
    (SELECT COUNT(*) FROM raw.orders AS o
     LEFT JOIN raw.order_details AS od ON od.orderID = o.orderID
     WHERE od.orderID IS NULL),
    (SELECT COUNT(*) FROM raw.orders), N'FAIL',
    N'An order without product lines has no calculable sales value.'
);

/* 4. Validity and cross-field date rules. */
INSERT INTO #dq_checks
VALUES
(
    30, N'Validity', N'Required date before order date',
    (SELECT COUNT(*) FROM raw.orders WHERE requiredDate < orderDate),
    (SELECT COUNT(*) FROM raw.orders), N'FAIL',
    N'The requested delivery date cannot occur before the order date.'
),
(
    31, N'Validity', N'Shipped date before order date',
    (SELECT COUNT(*) FROM raw.orders
     WHERE shippedDate IS NOT NULL AND shippedDate < orderDate),
    (SELECT COUNT(*) FROM raw.orders), N'FAIL',
    N'An order cannot be shipped before it is placed.'
),
(
    32, N'Validity', N'Negative freight',
    (SELECT COUNT(*) FROM raw.orders WHERE freight < 0),
    (SELECT COUNT(*) FROM raw.orders), N'FAIL',
    N'Freight cannot be negative.'
),
(
    33, N'Validity', N'Invalid product price',
    (SELECT COUNT(*) FROM raw.products WHERE unitPrice < 0),
    (SELECT COUNT(*) FROM raw.products), N'FAIL',
    N'Product price cannot be negative.'
),
(
    34, N'Validity', N'Invalid order-line price',
    (SELECT COUNT(*) FROM raw.order_details WHERE unitPrice < 0),
    (SELECT COUNT(*) FROM raw.order_details), N'FAIL',
    N'Historical selling price cannot be negative.'
),
(
    35, N'Validity', N'Invalid quantity',
    (SELECT COUNT(*) FROM raw.order_details WHERE quantity <= 0),
    (SELECT COUNT(*) FROM raw.order_details), N'FAIL',
    N'An order line must contain a positive quantity.'
),
(
    36, N'Validity', N'Discount outside 0 to 1',
    (SELECT COUNT(*) FROM raw.order_details WHERE discount < 0 OR discount > 1),
    (SELECT COUNT(*) FROM raw.order_details), N'FAIL',
    N'Discount must be a proportion between 0 and 1.'
);

/* 5. Review items: these can be valid but must be understood. */
INSERT INTO #dq_checks
VALUES
(
    40, N'Business review', N'Orders without shipped date',
    (SELECT COUNT(*) FROM raw.orders WHERE shippedDate IS NULL),
    (SELECT COUNT(*) FROM raw.orders), N'REVIEW',
    N'Usually means the order had not shipped when the dataset was captured.'
),
(
    41, N'Business review', N'Orders shipped after required date',
    (SELECT COUNT(*) FROM raw.orders
     WHERE shippedDate IS NOT NULL AND shippedDate > requiredDate),
    (SELECT COUNT(*) FROM raw.orders), N'REVIEW',
    N'This is a late-shipment business event, not automatically a data error.'
),
(
    42, N'Business review', N'Customers with no orders in full history',
    (SELECT COUNT(*) FROM raw.customers AS c
     LEFT JOIN raw.orders AS o ON o.customerID = c.customerID
     WHERE o.orderID IS NULL),
    (SELECT COUNT(*) FROM raw.customers), N'REVIEW',
    N'These customers are valid master records but are inactive in this dataset.'
),
(
    43, N'Business review', N'Products never sold in full history',
    (SELECT COUNT(*) FROM raw.products AS p
     LEFT JOIN raw.order_details AS od ON od.productID = p.productID
     WHERE od.productID IS NULL),
    (SELECT COUNT(*) FROM raw.products), N'REVIEW',
    N'These products exist in the catalog but have no recorded sales.'
),
(
    44, N'Report coverage', N'Missing months in 2014',
    (
        SELECT COUNT(*)
        FROM (VALUES (1), (2), (3), (4), (5), (6),
                     (7), (8), (9), (10), (11), (12)) AS m(month_no)
        LEFT JOIN
        (
            SELECT DISTINCT MONTH(orderDate) AS month_no
            FROM raw.orders
            WHERE orderDate >= '20140101'
              AND orderDate <  '20150101'
        ) AS o
            ON o.month_no = m.month_no
        WHERE o.month_no IS NULL
    ),
    12, N'FAIL',
    N'All 12 months are required for the selected 2014 annual report.'
);

/* Result 1: overall quality scorecard. */
SELECT N'1. Data-quality scorecard' AS result_set;

SELECT
    check_group,
    check_name,
    issue_count,
    total_rows,
    CAST(issue_count * 100.0 / NULLIF(total_rows, 0) AS DECIMAL(7,3)) AS issue_percent,
    CASE
        WHEN issue_count = 0 THEN N'PASS'
        ELSE status_if_found
    END AS result,
    explanation
FROM #dq_checks
ORDER BY check_order;

/* Result 2: concise summary by result. */
SELECT N'2. Result summary' AS result_set;

SELECT
    result,
    COUNT(*) AS total_checks
FROM
(
    SELECT
        CASE WHEN issue_count = 0 THEN N'PASS' ELSE status_if_found END AS result
    FROM #dq_checks
) AS s
GROUP BY result
ORDER BY CASE result WHEN N'FAIL' THEN 1 WHEN N'REVIEW' THEN 2 ELSE 3 END;

/* Result 3: optional missing values. These are informational, not automatic errors. */
SELECT N'3. Optional-field missingness' AS result_set;

SELECT
    field_name,
    missing_rows,
    total_rows,
    CAST(missing_rows * 100.0 / NULLIF(total_rows, 0) AS DECIMAL(7,3)) AS missing_percent,
    interpretation
FROM
(
    SELECT N'customers.contactName' AS field_name,
           SUM(CASE WHEN NULLIF(LTRIM(RTRIM(contactName)), N'') IS NULL THEN 1 ELSE 0 END) AS missing_rows,
           COUNT(*) AS total_rows,
           N'Optional customer contact information.' AS interpretation
    FROM raw.customers

    UNION ALL

    SELECT N'customers.contactTitle',
           SUM(CASE WHEN NULLIF(LTRIM(RTRIM(contactTitle)), N'') IS NULL THEN 1 ELSE 0 END),
           COUNT(*), N'Optional customer contact information.'
    FROM raw.customers

    UNION ALL

    SELECT N'customers.city',
           SUM(CASE WHEN NULLIF(LTRIM(RTRIM(city)), N'') IS NULL THEN 1 ELSE 0 END),
           COUNT(*), N'Needed only for city-level analysis.'
    FROM raw.customers

    UNION ALL

    SELECT N'customers.country',
           SUM(CASE WHEN NULLIF(LTRIM(RTRIM(country)), N'') IS NULL THEN 1 ELSE 0 END),
           COUNT(*), N'Needed for country-level analysis.'
    FROM raw.customers

    UNION ALL

    SELECT N'orders.shippedDate',
           SUM(CASE WHEN shippedDate IS NULL THEN 1 ELSE 0 END),
           COUNT(*), N'Can be null when an order has not shipped.'
    FROM raw.orders

    UNION ALL

    SELECT N'products.quantityPerUnit',
           SUM(CASE WHEN NULLIF(LTRIM(RTRIM(quantityPerUnit)), N'') IS NULL THEN 1 ELSE 0 END),
           COUNT(*), N'Product packaging description.'
    FROM raw.products
) AS missingness
ORDER BY missing_percent DESC, field_name;

/* Result 4: inspect the orders that require business review. */
SELECT N'4. Shipping records requiring review' AS result_set;

SELECT
    orderID,
    customerID,
    orderDate,
    requiredDate,
    shippedDate,
    CASE
        WHEN shippedDate IS NULL THEN N'Not shipped at data capture'
        WHEN shippedDate > requiredDate THEN N'Shipped after required date'
    END AS review_reason
FROM raw.orders
WHERE shippedDate IS NULL
   OR shippedDate > requiredDate
ORDER BY
    CASE WHEN shippedDate IS NULL THEN 1 ELSE 2 END,
    orderDate,
    orderID;

/* Result 5: verify the time coverage used by the project. */
SELECT N'5. Date coverage by year' AS result_set;

SELECT
    YEAR(orderDate) AS order_year,
    MIN(orderDate) AS first_order_date,
    MAX(orderDate) AS last_order_date,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT MONTH(orderDate)) AS months_with_orders
FROM raw.orders
GROUP BY YEAR(orderDate)
ORDER BY order_year;

DROP TABLE IF EXISTS #dq_checks;
GO
