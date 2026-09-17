/*
    Northwind Sales Performance Analysis 2014
    Step 1: Create the database, schemas, and seven source tables.

    Safe to rerun:
    - Existing database, schemas, and tables are preserved.
    - This script never drops or truncates data.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_ID(N'NorthwindAnalytics') IS NULL
BEGIN
    PRINT N'Creating database NorthwindAnalytics...';
    EXEC(N'CREATE DATABASE NorthwindAnalytics;');
END
ELSE
    PRINT N'Database NorthwindAnalytics already exists; keeping it unchanged.';
GO

USE NorthwindAnalytics;
GO

IF SCHEMA_ID(N'raw') IS NULL
    EXEC(N'CREATE SCHEMA raw AUTHORIZATION dbo;');
GO

IF SCHEMA_ID(N'analytics') IS NULL
    EXEC(N'CREATE SCHEMA analytics AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'raw.categories', N'U') IS NULL
BEGIN
    CREATE TABLE raw.categories
    (
        categoryID   INT           NOT NULL,
        categoryName NVARCHAR(100) NOT NULL,
        description  NVARCHAR(500) NULL,

        CONSTRAINT PK_raw_categories
            PRIMARY KEY (categoryID)
    );
END;
GO

IF OBJECT_ID(N'raw.customers', N'U') IS NULL
BEGIN
    CREATE TABLE raw.customers
    (
        customerID   NCHAR(5)      NOT NULL,
        companyName  NVARCHAR(150) NOT NULL,
        contactName  NVARCHAR(100) NULL,
        contactTitle NVARCHAR(100) NULL,
        city          NVARCHAR(100) NULL,
        country       NVARCHAR(100) NULL,

        CONSTRAINT PK_raw_customers
            PRIMARY KEY (customerID)
    );
END;
GO

IF OBJECT_ID(N'raw.employees', N'U') IS NULL
BEGIN
    CREATE TABLE raw.employees
    (
        employeeID   INT           NOT NULL,
        employeeName NVARCHAR(100) NOT NULL,
        title         NVARCHAR(100) NULL,
        city          NVARCHAR(100) NULL,
        country       NVARCHAR(100) NULL,
        reportsTo     INT           NULL,

        CONSTRAINT PK_raw_employees
            PRIMARY KEY (employeeID)
    );
END;
GO

IF OBJECT_ID(N'raw.shippers', N'U') IS NULL
BEGIN
    CREATE TABLE raw.shippers
    (
        shipperID  INT           NOT NULL,
        companyName NVARCHAR(150) NOT NULL,

        CONSTRAINT PK_raw_shippers
            PRIMARY KEY (shipperID)
    );
END;
GO

IF OBJECT_ID(N'raw.products', N'U') IS NULL
BEGIN
    CREATE TABLE raw.products
    (
        productID       INT           NOT NULL,
        productName     NVARCHAR(150) NOT NULL,
        quantityPerUnit NVARCHAR(100) NULL,
        unitPrice       DECIMAL(12,2) NOT NULL,
        discontinued    BIT           NOT NULL,
        categoryID      INT           NOT NULL,

        CONSTRAINT PK_raw_products
            PRIMARY KEY (productID),

        CONSTRAINT FK_raw_products_categories
            FOREIGN KEY (categoryID)
            REFERENCES raw.categories (categoryID),

        CONSTRAINT CK_raw_products_unitPrice
            CHECK (unitPrice >= 0)
    );
END;
GO

IF OBJECT_ID(N'raw.orders', N'U') IS NULL
BEGIN
    CREATE TABLE raw.orders
    (
        orderID      INT           NOT NULL,
        customerID   NCHAR(5)      NOT NULL,
        employeeID   INT           NOT NULL,
        orderDate    DATE          NOT NULL,
        requiredDate DATE          NOT NULL,
        shippedDate  DATE          NULL,
        shipperID    INT           NOT NULL,
        freight      DECIMAL(12,2) NOT NULL,

        CONSTRAINT PK_raw_orders
            PRIMARY KEY (orderID),

        CONSTRAINT FK_raw_orders_customers
            FOREIGN KEY (customerID)
            REFERENCES raw.customers (customerID),

        CONSTRAINT FK_raw_orders_employees
            FOREIGN KEY (employeeID)
            REFERENCES raw.employees (employeeID),

        CONSTRAINT FK_raw_orders_shippers
            FOREIGN KEY (shipperID)
            REFERENCES raw.shippers (shipperID),

        CONSTRAINT CK_raw_orders_freight
            CHECK (freight >= 0)
    );
END;
GO

IF OBJECT_ID(N'raw.order_details', N'U') IS NULL
BEGIN
    CREATE TABLE raw.order_details
    (
        orderID   INT           NOT NULL,
        productID INT           NOT NULL,
        unitPrice DECIMAL(12,2) NOT NULL,
        quantity  SMALLINT      NOT NULL,
        discount  DECIMAL(5,4)  NOT NULL,

        CONSTRAINT PK_raw_order_details
            PRIMARY KEY (orderID, productID),

        CONSTRAINT FK_raw_order_details_orders
            FOREIGN KEY (orderID)
            REFERENCES raw.orders (orderID),

        CONSTRAINT FK_raw_order_details_products
            FOREIGN KEY (productID)
            REFERENCES raw.products (productID),

        CONSTRAINT CK_raw_order_details_unitPrice
            CHECK (unitPrice >= 0),

        CONSTRAINT CK_raw_order_details_quantity
            CHECK (quantity > 0),

        CONSTRAINT CK_raw_order_details_discount
            CHECK (discount >= 0 AND discount <= 1)
    );
END;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    SUM(p.rows) AS row_count
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.partitions AS p
    ON p.object_id = t.object_id
   AND p.index_id IN (0, 1)
WHERE s.name = N'raw'
GROUP BY s.name, t.name
ORDER BY t.name;
GO
