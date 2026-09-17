/*
    Northwind Sales Performance Analysis 2014
    Step 2: Load the seven supplied CSV files into the raw tables.

    Preconditions:
    - Run create_database_and_source_tables.sql first.
    - SQL Server must be able to read the absolute CSV paths below.
    - All raw tables must be empty. This script stops instead of duplicating data.
*/

USE NorthwindAnalytics;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM raw.categories)
    OR EXISTS (SELECT 1 FROM raw.customers)
    OR EXISTS (SELECT 1 FROM raw.employees)
    OR EXISTS (SELECT 1 FROM raw.shippers)
    OR EXISTS (SELECT 1 FROM raw.products)
    OR EXISTS (SELECT 1 FROM raw.orders)
    OR EXISTS (SELECT 1 FROM raw.order_details)
    THROW 51110, 'Import stopped: at least one raw table already contains data.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    /*
        Compile each BULK INSERT separately. SQL Server 17 can raise error 4130
        when several CSV bulk rowsets with the same hints are compiled together.
        sp_executesql still runs in this transaction, so any failure rolls back all tables.
    */
    EXEC sys.sp_executesql N'
        BULK INSERT raw.categories
        FROM ''F:\DA Projects\DA-projects\Sample Projects\DA2\Northwind Traders\northwind-traders\categories.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'',
              CODEPAGE = ''65001'', KEEPNULLS, TABLOCK);';

    -- Source contains Windows-1252 accents (for example Taquería: byte ED).
    EXEC sys.sp_executesql N'
        BULK INSERT raw.customers
        FROM ''F:\DA Projects\DA-projects\Sample Projects\DA2\Northwind Traders\northwind-traders\customers.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'',
              CODEPAGE = ''1252'', KEEPNULLS, TABLOCK);';

    EXEC sys.sp_executesql N'
        BULK INSERT raw.employees
        FROM ''F:\DA Projects\DA-projects\Sample Projects\DA2\Northwind Traders\northwind-traders\employees.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'',
              CODEPAGE = ''65001'', KEEPNULLS, TABLOCK);';

    EXEC sys.sp_executesql N'
        BULK INSERT raw.shippers
        FROM ''F:\DA Projects\DA-projects\Sample Projects\DA2\Northwind Traders\northwind-traders\shippers.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'',
              CODEPAGE = ''65001'', KEEPNULLS, TABLOCK);';

    -- Products also contains Windows-1252 characters; preserve their accents.
    EXEC sys.sp_executesql N'
        BULK INSERT raw.products
        FROM ''F:\DA Projects\DA-projects\Sample Projects\DA2\Northwind Traders\northwind-traders\products.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'',
              CODEPAGE = ''1252'', KEEPNULLS, TABLOCK);';

    EXEC sys.sp_executesql N'
        BULK INSERT raw.orders
        FROM ''F:\DA Projects\DA-projects\Sample Projects\DA2\Northwind Traders\northwind-traders\orders.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'',
              CODEPAGE = ''65001'', KEEPNULLS, TABLOCK);';

    EXEC sys.sp_executesql N'
        BULK INSERT raw.order_details
        FROM ''F:\DA Projects\DA-projects\Sample Projects\DA2\Northwind Traders\northwind-traders\order_details.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'',
              CODEPAGE = ''65001'', KEEPNULLS, TABLOCK);';

    IF (SELECT COUNT(*) FROM raw.categories) <> 8
        OR (SELECT COUNT(*) FROM raw.customers) <> 91
        OR (SELECT COUNT(*) FROM raw.employees) <> 9
        OR (SELECT COUNT(*) FROM raw.shippers) <> 3
        OR (SELECT COUNT(*) FROM raw.products) <> 77
        OR (SELECT COUNT(*) FROM raw.orders) <> 830
        OR (SELECT COUNT(*) FROM raw.order_details) <> 2155
        THROW 51111, 'Import rolled back: one or more row counts are incorrect.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM raw.employees AS e
        LEFT JOIN raw.employees AS manager
            ON manager.employeeID = e.reportsTo
        WHERE e.reportsTo IS NOT NULL
          AND manager.employeeID IS NULL
    )
        THROW 51112, 'Import rolled back: employees.reportsTo contains an orphan value.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_raw_employees_reportsTo'
          AND parent_object_id = OBJECT_ID(N'raw.employees')
    )
    BEGIN
        ALTER TABLE raw.employees WITH CHECK
            ADD CONSTRAINT FK_raw_employees_reportsTo
            FOREIGN KEY (reportsTo)
            REFERENCES raw.employees (employeeID);

        ALTER TABLE raw.employees
            CHECK CONSTRAINT FK_raw_employees_reportsTo;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

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
GO
