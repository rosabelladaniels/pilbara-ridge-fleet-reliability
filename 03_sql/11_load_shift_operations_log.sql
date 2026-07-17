USE PilbaraRidgeFleetReliability;
GO

/*
Load shift_operations_log.csv into SQL Server

Approach:
1. Clear the final shift_operations_log table.
2. Load the CSV into a temporary staging table as text.
3. Convert date and operational metric fields safely.
4. Standardise asset IDs.
5. Match assets to dbo.asset_register.
6. Bring asset_name and asset_class into the final table.
7. Create shift quality, asset match and inclusion flags.
8. Validate row count and quality flag counts.
*/

DELETE FROM dbo.shift_operations_log;
GO

DROP TABLE IF EXISTS #shift_operations_log_stage;
GO

CREATE TABLE #shift_operations_log_stage (
    shift_log_id VARCHAR(50),
    raw_date VARCHAR(100),
    shift_type VARCHAR(50),
    asset_id VARCHAR(100),
    crew_id VARCHAR(50),
    scheduled_hours VARCHAR(50),
    operating_hours VARCHAR(50),
    idle_hours VARCHAR(50),
    downtime_hours VARCHAR(50),
    tonnes_moved VARCHAR(50),
    metres_drilled VARCHAR(50),
    weather_condition VARCHAR(100),
    operator_id VARCHAR(50)
);
GO

BULK INSERT #shift_operations_log_stage
FROM 'C:\Users\rosab\OneDrive\Desktop\Data-Analytics-Portfolio\01_Pilbara-Ridge_Fleet-Maintenance\pilbara-ridge-fleet-reliability\01_raw_data\shift_operations_log.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

WITH cleaned AS (
    SELECT
        TRIM(REPLACE(shift_log_id, '"', '')) AS shift_log_id,
        TRIM(REPLACE(REPLACE(REPLACE(raw_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS clean_date,
        TRIM(REPLACE(shift_type, '"', '')) AS shift_type,
        TRIM(REPLACE(asset_id, '"', '')) AS asset_id,
        TRIM(REPLACE(crew_id, '"', '')) AS crew_id,
        TRIM(REPLACE(scheduled_hours, '"', '')) AS scheduled_hours,
        TRIM(REPLACE(operating_hours, '"', '')) AS operating_hours,
        TRIM(REPLACE(idle_hours, '"', '')) AS idle_hours,
        TRIM(REPLACE(downtime_hours, '"', '')) AS downtime_hours,
        TRIM(REPLACE(tonnes_moved, '"', '')) AS tonnes_moved,
        TRIM(REPLACE(metres_drilled, '"', '')) AS metres_drilled,
        TRIM(REPLACE(weather_condition, '"', '')) AS weather_condition,
        TRIM(REPLACE(operator_id, '"', '')) AS operator_id
    FROM #shift_operations_log_stage
),
converted AS (
    SELECT
        shift_log_id,
        COALESCE(
            TRY_CONVERT(DATE, clean_date, 103),
            TRY_CONVERT(DATE, clean_date, 101),
            TRY_CONVERT(DATE, clean_date, 111),
            TRY_CONVERT(DATE, clean_date, 23),
            TRY_CONVERT(DATE, clean_date, 120)
        ) AS converted_date,
        shift_type,
        asset_id,
        CASE
            WHEN asset_id IS NULL OR asset_id = '' THEN NULL
            WHEN asset_id LIKE 'PRM-%' THEN UPPER(asset_id)
            WHEN asset_id LIKE 'PRM%' AND asset_id NOT LIKE 'PRM-%'
                THEN 'PRM-' + UPPER(SUBSTRING(asset_id, 4, LEN(asset_id)))
            ELSE UPPER(asset_id)
        END AS Asset_ID_Candidate,
        crew_id,
        TRY_CONVERT(DECIMAL(8,2), scheduled_hours) AS scheduled_hours,
        TRY_CONVERT(DECIMAL(8,2), operating_hours) AS operating_hours,
        TRY_CONVERT(DECIMAL(8,2), idle_hours) AS idle_hours,
        TRY_CONVERT(DECIMAL(8,2), downtime_hours) AS downtime_hours,
        TRY_CONVERT(DECIMAL(12,2), tonnes_moved) AS tonnes_moved,
        TRY_CONVERT(DECIMAL(12,2), metres_drilled) AS metres_drilled,
        weather_condition,
        operator_id
    FROM cleaned
),
asset_checked AS (
    SELECT
        c.*,
        ar.asset_id AS matched_asset_id,
        ar.asset_name,
        ar.asset_class
    FROM converted c
    LEFT JOIN dbo.asset_register ar
        ON c.Asset_ID_Candidate = ar.asset_id
),
flagged AS (
    SELECT
        shift_log_id,
        converted_date,
        shift_type,
        asset_id,
        CASE
            WHEN matched_asset_id IS NOT NULL THEN Asset_ID_Candidate
            ELSE NULL
        END AS Asset_ID_Standardised,
        crew_id,
        scheduled_hours,
        operating_hours,
        idle_hours,
        downtime_hours,
        tonnes_moved,
        metres_drilled,
        weather_condition,
        operator_id,
        CASE
            WHEN converted_date IS NULL THEN 'Missing or invalid date'
            WHEN operating_hours IS NULL THEN 'Missing operating hours'
            WHEN operating_hours < 0 THEN 'Negative operating hours'
            WHEN downtime_hours IS NULL THEN 'Missing downtime hours'
            WHEN downtime_hours < 0 THEN 'Negative downtime hours'
            ELSE 'Valid shift log'
        END AS Shift_Log_Quality_Flag,
        asset_name,
        asset_class,
        CASE
            WHEN matched_asset_id IS NOT NULL THEN 'Asset matched'
            ELSE 'Asset not found in asset register'
        END AS Asset_Match_Flag
    FROM asset_checked
)
INSERT INTO dbo.shift_operations_log (
    shift_log_id,
    [date],
    shift_type,
    asset_id,
    Asset_ID_Standardised,
    crew_id,
    scheduled_hours,
    operating_hours,
    idle_hours,
    downtime_hours,
    tonnes_moved,
    metres_drilled,
    weather_condition,
    operator_id,
    Shift_Log_Quality_Flag,
    asset_name,
    asset_class,
    Asset_Match_Flag,
    Include_In_Shift_Analysis
)
SELECT
    shift_log_id,
    converted_date,
    shift_type,
    asset_id,
    Asset_ID_Standardised,
    crew_id,
    scheduled_hours,
    operating_hours,
    idle_hours,
    downtime_hours,
    tonnes_moved,
    metres_drilled,
    weather_condition,
    operator_id,
    Shift_Log_Quality_Flag,
    asset_name,
    asset_class,
    Asset_Match_Flag,
    CASE
        WHEN Shift_Log_Quality_Flag = 'Valid shift log'
             AND Asset_Match_Flag = 'Asset matched' THEN 1
        ELSE 0
    END AS Include_In_Shift_Analysis
FROM flagged;
GO

SELECT COUNT(*) AS shift_operations_log_row_count
FROM dbo.shift_operations_log;
GO

SELECT
    Shift_Log_Quality_Flag,
    COUNT(*) AS record_count
FROM dbo.shift_operations_log
GROUP BY Shift_Log_Quality_Flag
ORDER BY record_count DESC;
GO

SELECT
    Asset_Match_Flag,
    COUNT(*) AS record_count
FROM dbo.shift_operations_log
GROUP BY Asset_Match_Flag
ORDER BY record_count DESC;
GO

SELECT
    Include_In_Shift_Analysis,
    COUNT(*) AS record_count
FROM dbo.shift_operations_log
GROUP BY Include_In_Shift_Analysis
ORDER BY Include_In_Shift_Analysis DESC;
GO

SELECT TOP 30
    shift_log_id,
    [date],
    shift_type,
    asset_id,
    Asset_ID_Standardised,
    asset_name,
    asset_class,
    Shift_Log_Quality_Flag,
    Asset_Match_Flag,
    Include_In_Shift_Analysis
FROM dbo.shift_operations_log
ORDER BY shift_log_id;
GO