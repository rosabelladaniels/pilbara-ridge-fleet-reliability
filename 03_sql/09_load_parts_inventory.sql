USE PilbaraRidgeFleetReliability;
GO

/*
Load parts_inventory.csv into SQL Server

Actual CSV column order:
part_id, part_name, asset_class, supplier_name,
current_stock, reorder_point,
order_date, expected_delivery_date, actual_delivery_date,
unit_cost_aud, stockout_flag

The final SQL table does not include unit_cost_aud, so it is loaded into staging
but not inserted into dbo.parts_inventory.
*/

DELETE FROM dbo.parts_inventory;
GO

DROP TABLE IF EXISTS #parts_inventory_stage;
GO

CREATE TABLE #parts_inventory_stage (
    part_id VARCHAR(50),
    part_name VARCHAR(100),
    asset_class VARCHAR(100),
    supplier_name VARCHAR(100),
    current_stock VARCHAR(50),
    reorder_point VARCHAR(50),
    order_date VARCHAR(100),
    expected_delivery_date VARCHAR(100),
    actual_delivery_date VARCHAR(100),
    unit_cost_aud VARCHAR(50),
    stockout_flag VARCHAR(50)
);
GO

BULK INSERT #parts_inventory_stage
FROM 'C:\Users\rosab\OneDrive\Desktop\Data-Analytics-Portfolio\01_Pilbara-Ridge_Fleet-Maintenance\pilbara-ridge-fleet-reliability\01_raw_data\parts_inventory.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

WITH cleaned AS (
    SELECT
        TRIM(REPLACE(part_id, '"', '')) AS part_id,
        TRIM(REPLACE(part_name, '"', '')) AS part_name,
        TRIM(REPLACE(asset_class, '"', '')) AS asset_class,
        TRIM(REPLACE(supplier_name, '"', '')) AS supplier_name,
        TRIM(REPLACE(current_stock, '"', '')) AS current_stock,
        TRIM(REPLACE(reorder_point, '"', '')) AS reorder_point,
        TRIM(REPLACE(REPLACE(REPLACE(order_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS order_date,
        TRIM(REPLACE(REPLACE(REPLACE(expected_delivery_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS expected_delivery_date,
        TRIM(REPLACE(REPLACE(REPLACE(actual_delivery_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS actual_delivery_date,
        TRIM(REPLACE(stockout_flag, '"', '')) AS stockout_flag
    FROM #parts_inventory_stage
)
INSERT INTO dbo.parts_inventory (
    part_id,
    part_name,
    asset_class,
    supplier_name,
    order_date,
    expected_delivery_date,
    actual_delivery_date,
    current_stock,
    reorder_point,
    stockout_flag
)
SELECT
    part_id,
    part_name,
    asset_class,
    supplier_name,
    COALESCE(
        TRY_CONVERT(DATE, order_date, 103),
        TRY_CONVERT(DATE, order_date, 101),
        TRY_CONVERT(DATE, order_date, 111),
        TRY_CONVERT(DATE, order_date, 23),
        TRY_CONVERT(DATE, order_date, 120)
    ),
    COALESCE(
        TRY_CONVERT(DATE, expected_delivery_date, 103),
        TRY_CONVERT(DATE, expected_delivery_date, 101),
        TRY_CONVERT(DATE, expected_delivery_date, 111),
        TRY_CONVERT(DATE, expected_delivery_date, 23),
        TRY_CONVERT(DATE, expected_delivery_date, 120)
    ),
    COALESCE(
        TRY_CONVERT(DATE, actual_delivery_date, 103),
        TRY_CONVERT(DATE, actual_delivery_date, 101),
        TRY_CONVERT(DATE, actual_delivery_date, 111),
        TRY_CONVERT(DATE, actual_delivery_date, 23),
        TRY_CONVERT(DATE, actual_delivery_date, 120)
    ),
    TRY_CONVERT(INT, current_stock),
    TRY_CONVERT(INT, reorder_point),
    stockout_flag
FROM cleaned;
GO

SELECT COUNT(*) AS parts_inventory_row_count
FROM dbo.parts_inventory;
GO

SELECT TOP 10 *
FROM dbo.parts_inventory
ORDER BY part_id;
GO