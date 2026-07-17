USE PilbaraRidgeFleetReliability;
GO

/*
Load maintenance_work_orders.csv into SQL Server

Data governance decision:
The source file contains duplicate work_order_id values, so work_order_id is treated
as a business identifier rather than the SQL primary key.

A surrogate SQL key called sql_row_id is used as the table primary key so that all
source rows can be loaded, audited and flagged instead of deleted.

Actual CSV column order:
work_order_id, asset_id, date_raised, planned_start_date,
actual_start_date, actual_finish_date, work_order_type, status,
failure_code, failure_description, priority, labour_hours,
materials_cost_aud, external_service_cost_aud, downtime_hours, crew_id
*/

IF EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = 'PK_maintenance_work_orders'
      AND parent_object_id = OBJECT_ID('dbo.maintenance_work_orders')
)
BEGIN
    ALTER TABLE dbo.maintenance_work_orders
    DROP CONSTRAINT PK_maintenance_work_orders;
END;
GO

IF COL_LENGTH('dbo.maintenance_work_orders', 'sql_row_id') IS NULL
BEGIN
    ALTER TABLE dbo.maintenance_work_orders
    ADD sql_row_id INT IDENTITY(1,1) NOT NULL;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.maintenance_work_orders')
      AND type = 'PK'
)
BEGIN
    ALTER TABLE dbo.maintenance_work_orders
    ADD CONSTRAINT PK_maintenance_work_orders_sql_row_id
    PRIMARY KEY (sql_row_id);
END;
GO

DELETE FROM dbo.maintenance_work_orders;
GO

DROP TABLE IF EXISTS #maintenance_work_orders_stage;
GO

CREATE TABLE #maintenance_work_orders_stage (
    work_order_id VARCHAR(50),
    asset_id VARCHAR(100),
    raw_date_raised VARCHAR(100),
    raw_planned_start_date VARCHAR(100),
    raw_actual_start_date VARCHAR(100),
    raw_actual_finish_date VARCHAR(100),
    work_order_type VARCHAR(100),
    status VARCHAR(50),
    failure_code VARCHAR(100),
    failure_description VARCHAR(255),
    priority VARCHAR(50),
    labour_hours VARCHAR(50),
    materials_cost_aud VARCHAR(50),
    external_service_cost_aud VARCHAR(50),
    downtime_hours VARCHAR(50),
    crew_id VARCHAR(50)
);
GO

BULK INSERT #maintenance_work_orders_stage
FROM 'C:\Users\rosab\OneDrive\Desktop\Data-Analytics-Portfolio\01_Pilbara-Ridge_Fleet-Maintenance\pilbara-ridge-fleet-reliability\01_raw_data\maintenance_work_orders.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

WITH cleaned AS (
    SELECT
        TRIM(REPLACE(work_order_id, '"', '')) AS work_order_id,
        TRIM(REPLACE(asset_id, '"', '')) AS asset_id,
        TRIM(REPLACE(work_order_type, '"', '')) AS work_order_type,
        TRIM(REPLACE(REPLACE(REPLACE(raw_date_raised, CHAR(13), ''), CHAR(10), ''), '"', '')) AS date_raised,
        TRIM(REPLACE(REPLACE(REPLACE(raw_planned_start_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS planned_start_date,
        TRIM(REPLACE(REPLACE(REPLACE(raw_actual_start_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS actual_start_date,
        TRIM(REPLACE(REPLACE(REPLACE(raw_actual_finish_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS actual_finish_date,
        TRIM(REPLACE(status, '"', '')) AS status,
        NULLIF(TRIM(REPLACE(priority, '"', '')), '') AS priority,
        NULLIF(TRIM(REPLACE(failure_code, '"', '')), '') AS failure_code,
        TRIM(REPLACE(failure_description, '"', '')) AS failure_description,
        TRIM(REPLACE(labour_hours, '"', '')) AS labour_hours,
        TRIM(REPLACE(materials_cost_aud, '"', '')) AS materials_cost_aud,
        TRIM(REPLACE(external_service_cost_aud, '"', '')) AS external_service_cost_aud,
        TRIM(REPLACE(downtime_hours, '"', '')) AS downtime_hours,
        TRIM(REPLACE(crew_id, '"', '')) AS crew_id
    FROM #maintenance_work_orders_stage
),
converted AS (
    SELECT
        *,
        COALESCE(
            TRY_CONVERT(DATE, date_raised, 103),
            TRY_CONVERT(DATE, date_raised, 101),
            TRY_CONVERT(DATE, date_raised, 111),
            TRY_CONVERT(DATE, date_raised, 23),
            TRY_CONVERT(DATE, date_raised, 120)
        ) AS converted_date_raised,
        COALESCE(
            TRY_CONVERT(DATE, planned_start_date, 103),
            TRY_CONVERT(DATE, planned_start_date, 101),
            TRY_CONVERT(DATE, planned_start_date, 111),
            TRY_CONVERT(DATE, planned_start_date, 23),
            TRY_CONVERT(DATE, planned_start_date, 120)
        ) AS converted_planned_start_date,
        COALESCE(
            TRY_CONVERT(DATE, actual_start_date, 103),
            TRY_CONVERT(DATE, actual_start_date, 101),
            TRY_CONVERT(DATE, actual_start_date, 111),
            TRY_CONVERT(DATE, actual_start_date, 23),
            TRY_CONVERT(DATE, actual_start_date, 120)
        ) AS converted_actual_start_date,
        COALESCE(
            TRY_CONVERT(DATE, NULLIF(actual_finish_date, ''), 103),
            TRY_CONVERT(DATE, NULLIF(actual_finish_date, ''), 101),
            TRY_CONVERT(DATE, NULLIF(actual_finish_date, ''), 111),
            TRY_CONVERT(DATE, NULLIF(actual_finish_date, ''), 23),
            TRY_CONVERT(DATE, NULLIF(actual_finish_date, ''), 120)
        ) AS converted_actual_finish_date,
        TRY_CONVERT(DECIMAL(8,2), labour_hours) AS converted_labour_hours,
        TRY_CONVERT(DECIMAL(12,2), materials_cost_aud) AS converted_materials_cost_aud,
        TRY_CONVERT(DECIMAL(12,2), external_service_cost_aud) AS converted_external_service_cost_aud,
        TRY_CONVERT(DECIMAL(8,2), downtime_hours) AS converted_downtime_hours,
        COUNT(*) OVER (PARTITION BY work_order_id) AS work_order_id_count
    FROM cleaned
),
flagged AS (
    SELECT
        *,
        CASE
            WHEN failure_code IS NULL OR failure_code = '' THEN 'Preventive Maintenance'
            WHEN UPPER(failure_code) IN ('ELEC', 'ELECTRIC', 'ELECTRICAL') THEN 'Electrical'
            WHEN UPPER(failure_code) IN ('TYR', 'TYRE', 'TYRES') THEN 'Tyre'
            WHEN UPPER(failure_code) IN ('HYD', 'HYDRAULIC', 'HYDRAULICS', 'HYDROLICS') THEN 'Hydraulics'
            WHEN UPPER(failure_code) IN ('TRANS', 'TRANSMISSION') THEN 'Transmission'
            WHEN UPPER(failure_code) IN ('ENG', 'ENGINE') THEN 'Engine'
            WHEN UPPER(failure_code) IN ('COOL', 'COOLING') THEN 'Cooling'
            WHEN UPPER(failure_code) IN ('STRUCT', 'STRUCTURAL') THEN 'Structural'
            WHEN UPPER(failure_code) IN ('UNDER', 'UNDERCARRIAGE') THEN 'Undercarriage'
            ELSE 'Unknown'
        END AS Failure_Category_Standardised,
        CASE
            WHEN work_order_id IS NULL OR work_order_id = '' THEN 'Missing work order ID'
            WHEN work_order_id_count > 1 THEN 'Duplicate work order ID'
            WHEN asset_id IS NULL OR asset_id = '' THEN 'Missing asset ID'
            WHEN converted_date_raised IS NULL THEN 'Missing or invalid date raised'
            WHEN converted_planned_start_date IS NULL THEN 'Missing planned start date'
            WHEN converted_actual_start_date IS NOT NULL
                 AND converted_actual_finish_date IS NOT NULL
                 AND converted_actual_finish_date < converted_actual_start_date THEN 'Actual finish before actual start'
            WHEN converted_labour_hours IS NULL THEN 'Missing labour hours'
            WHEN converted_labour_hours < 0 THEN 'Negative labour hours'
            WHEN converted_downtime_hours IS NULL THEN 'Missing downtime hours'
            WHEN converted_downtime_hours < 0 THEN 'Negative downtime hours'
            ELSE 'Valid work order'
        END AS Work_Order_Quality_Flag
    FROM converted
)
INSERT INTO dbo.maintenance_work_orders (
    work_order_id,
    asset_id,
    work_order_type,
    date_raised,
    planned_start_date,
    actual_start_date,
    actual_finish_date,
    status,
    priority,
    failure_code,
    failure_description,
    labour_hours,
    materials_cost_aud,
    external_service_cost_aud,
    downtime_hours,
    crew_id,
    Failure_Category_Standardised,
    Work_Order_Quality_Flag,
    Include_In_Work_Order_Analysis
)
SELECT
    work_order_id,
    asset_id,
    work_order_type,
    converted_date_raised,
    converted_planned_start_date,
    converted_actual_start_date,
    converted_actual_finish_date,
    status,
    priority,
    failure_code,
    failure_description,
    converted_labour_hours,
    converted_materials_cost_aud,
    converted_external_service_cost_aud,
    converted_downtime_hours,
    crew_id,
    Failure_Category_Standardised,
    Work_Order_Quality_Flag,
    CASE
        WHEN Work_Order_Quality_Flag = 'Valid work order' THEN 1
        ELSE 0
    END AS Include_In_Work_Order_Analysis
FROM flagged;
GO

SELECT COUNT(*) AS maintenance_work_orders_row_count
FROM dbo.maintenance_work_orders;
GO

SELECT
    Work_Order_Quality_Flag,
    COUNT(*) AS record_count
FROM dbo.maintenance_work_orders
GROUP BY Work_Order_Quality_Flag
ORDER BY record_count DESC;
GO

SELECT
    Failure_Category_Standardised,
    COUNT(*) AS record_count
FROM dbo.maintenance_work_orders
GROUP BY Failure_Category_Standardised
ORDER BY record_count DESC;
GO

SELECT TOP 30
    work_order_id,
    asset_id,
    date_raised,
    work_order_type,
    status,
    priority,
    failure_code,
    failure_description
FROM dbo.maintenance_work_orders
ORDER BY work_order_id;
GO