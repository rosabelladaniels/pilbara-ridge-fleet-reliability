USE PilbaraRidgeFleetReliability;
GO

/*
Load fuel_usage.csv into SQL Server

Approach:
1. Clear the final fuel_usage table.
2. Load the CSV into a temporary staging table as text.
3. Convert dates and numbers safely.
4. Standardise asset IDs.
5. Check asset IDs against dbo.asset_register.
6. Keep original asset_id for audit.
7. Only load matched asset IDs into Asset_ID_Standardised to satisfy the foreign key.
8. Create quality and inclusion flags.
9. Validate row count and quality flag counts.
*/

DELETE FROM dbo.fuel_usage;
GO

DROP TABLE IF EXISTS #fuel_usage_stage;
GO

CREATE TABLE #fuel_usage_stage (
    fuel_record_id VARCHAR(50),
    raw_date VARCHAR(100),
    asset_id VARCHAR(100),
    operating_hours VARCHAR(50),
    fuel_litres VARCHAR(50),
    fuel_cost_aud VARCHAR(50),
    shift_type VARCHAR(50)
);
GO

BULK INSERT #fuel_usage_stage
FROM 'C:\Users\rosab\OneDrive\Desktop\Data-Analytics-Portfolio\01_Pilbara-Ridge_Fleet-Maintenance\pilbara-ridge-fleet-reliability\01_raw_data\fuel_usage.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

WITH cleaned AS (
    SELECT
        TRIM(REPLACE(fuel_record_id, '"', '')) AS fuel_record_id,
        TRIM(REPLACE(REPLACE(REPLACE(raw_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS clean_date,
        TRIM(REPLACE(asset_id, '"', '')) AS asset_id,
        TRIM(REPLACE(operating_hours, '"', '')) AS operating_hours,
        TRIM(REPLACE(fuel_litres, '"', '')) AS fuel_litres,
        TRIM(REPLACE(fuel_cost_aud, '"', '')) AS fuel_cost_aud,
        TRIM(REPLACE(shift_type, '"', '')) AS shift_type
    FROM #fuel_usage_stage
),
converted AS (
    SELECT
        fuel_record_id,
        COALESCE(
            TRY_CONVERT(DATE, clean_date, 103),
            TRY_CONVERT(DATE, clean_date, 101),
            TRY_CONVERT(DATE, clean_date, 111),
            TRY_CONVERT(DATE, clean_date, 23),
            TRY_CONVERT(DATE, clean_date, 120)
        ) AS converted_date,
        asset_id,
        CASE
            WHEN asset_id IS NULL OR asset_id = '' THEN NULL
            WHEN asset_id LIKE 'PRM-%' THEN UPPER(asset_id)
            WHEN asset_id LIKE 'PRM%' AND asset_id NOT LIKE 'PRM-%'
                THEN 'PRM-' + UPPER(SUBSTRING(asset_id, 4, LEN(asset_id)))
            ELSE UPPER(asset_id)
        END AS Asset_ID_Candidate,
        TRY_CONVERT(DECIMAL(8,2), operating_hours) AS operating_hours,
        TRY_CONVERT(DECIMAL(10,2), fuel_litres) AS fuel_litres,
        TRY_CONVERT(DECIMAL(12,2), fuel_cost_aud) AS fuel_cost_aud,
        shift_type
    FROM cleaned
),
asset_checked AS (
    SELECT
        c.*,
        ar.asset_id AS matched_asset_id
    FROM converted c
    LEFT JOIN dbo.asset_register ar
        ON c.Asset_ID_Candidate = ar.asset_id
),
flagged AS (
    SELECT
        fuel_record_id,
        converted_date,
        asset_id,
        CASE
            WHEN matched_asset_id IS NOT NULL THEN Asset_ID_Candidate
            ELSE NULL
        END AS Asset_ID_Standardised,
        operating_hours,
        fuel_litres,
        fuel_cost_aud,
        shift_type,
        CASE
            WHEN converted_date IS NULL THEN 'Missing or invalid date'
            WHEN fuel_record_id IS NULL OR fuel_record_id = '' THEN 'Missing fuel record ID'
            WHEN asset_id IS NULL OR asset_id = '' THEN 'Missing asset ID'
            WHEN matched_asset_id IS NULL THEN 'Asset not found in asset register'
            WHEN operating_hours IS NULL THEN 'Missing operating hours'
            WHEN operating_hours < 0 THEN 'Negative operating hours'
            WHEN fuel_litres IS NULL THEN 'Missing fuel litres'
            WHEN fuel_litres < 0 THEN 'Negative fuel litres'
            WHEN fuel_cost_aud IS NULL THEN 'Missing fuel cost'
            WHEN fuel_cost_aud < 0 THEN 'Negative fuel cost'
            ELSE 'Valid fuel record'
        END AS Fuel_Record_Quality_Flag
    FROM asset_checked
)
INSERT INTO dbo.fuel_usage (
    fuel_record_id,
    [date],
    asset_id,
    Asset_ID_Standardised,
    operating_hours,
    fuel_litres,
    fuel_cost_aud,
    shift_type,
    Fuel_Record_Quality_Flag,
    Include_In_Fuel_Analysis
)
SELECT
    fuel_record_id,
    converted_date,
    asset_id,
    Asset_ID_Standardised,
    operating_hours,
    fuel_litres,
    fuel_cost_aud,
    shift_type,
    Fuel_Record_Quality_Flag,
    CASE
        WHEN Fuel_Record_Quality_Flag = 'Valid fuel record' THEN 1
        ELSE 0
    END AS Include_In_Fuel_Analysis
FROM flagged;
GO

SELECT COUNT(*) AS fuel_usage_row_count
FROM dbo.fuel_usage;
GO

SELECT
    Fuel_Record_Quality_Flag,
    COUNT(*) AS record_count
FROM dbo.fuel_usage
GROUP BY Fuel_Record_Quality_Flag
ORDER BY record_count DESC;
GO