USE PilbaraRidgeFleetReliability;
GO

/*
Load crew_roster.csv into SQL Server

The CSV column order is:
crew_id, crew_name, shift_type, supervisor_id, date,
scheduled_headcount, actual_headcount, absenteeism_count, overtime_hours

The final SQL table does not include supervisor_id, so it is loaded into staging
but not inserted into dbo.crew_roster.
*/

DELETE FROM dbo.crew_roster;
GO

DROP TABLE IF EXISTS #crew_roster_stage;
GO

CREATE TABLE #crew_roster_stage (
    crew_id VARCHAR(50),
    crew_name VARCHAR(100),
    shift_type VARCHAR(50),
    supervisor_id VARCHAR(50),
    raw_date VARCHAR(100),
    scheduled_headcount VARCHAR(50),
    actual_headcount VARCHAR(50),
    absenteeism_count VARCHAR(50),
    overtime_hours VARCHAR(50)
);
GO

BULK INSERT #crew_roster_stage
FROM 'C:\Users\rosab\OneDrive\Desktop\Data-Analytics-Portfolio\01_Pilbara-Ridge_Fleet-Maintenance\pilbara-ridge-fleet-reliability\01_raw_data\crew_roster.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

WITH cleaned AS (
    SELECT
        TRIM(REPLACE(crew_id, '"', '')) AS crew_id,
        TRIM(REPLACE(crew_name, '"', '')) AS crew_name,
        TRIM(REPLACE(shift_type, '"', '')) AS shift_type,
        TRIM(REPLACE(REPLACE(REPLACE(raw_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS clean_date,
        TRIM(REPLACE(scheduled_headcount, '"', '')) AS scheduled_headcount,
        TRIM(REPLACE(actual_headcount, '"', '')) AS actual_headcount,
        TRIM(REPLACE(absenteeism_count, '"', '')) AS absenteeism_count,
        TRIM(REPLACE(overtime_hours, '"', '')) AS overtime_hours
    FROM #crew_roster_stage
),
converted AS (
    SELECT
        COALESCE(
            TRY_CONVERT(DATE, clean_date, 103),
            TRY_CONVERT(DATE, clean_date, 101),
            TRY_CONVERT(DATE, clean_date, 111),
            TRY_CONVERT(DATE, clean_date, 23),
            TRY_CONVERT(DATE, clean_date, 120)
        ) AS converted_date,
        crew_id,
        crew_name,
        shift_type,
        TRY_CONVERT(INT, scheduled_headcount) AS scheduled_headcount,
        TRY_CONVERT(INT, actual_headcount) AS actual_headcount,
        TRY_CONVERT(INT, absenteeism_count) AS absenteeism_count,
        TRY_CONVERT(DECIMAL(8,2), overtime_hours) AS overtime_hours,
        clean_date
    FROM cleaned
)
INSERT INTO dbo.crew_roster (
    [date],
    crew_id,
    crew_name,
    shift_type,
    scheduled_headcount,
    actual_headcount,
    absenteeism_count,
    overtime_hours
)
SELECT
    converted_date,
    crew_id,
    crew_name,
    shift_type,
    scheduled_headcount,
    actual_headcount,
    absenteeism_count,
    overtime_hours
FROM converted
WHERE converted_date IS NOT NULL;
GO

SELECT COUNT(*) AS crew_roster_row_count
FROM dbo.crew_roster;
GO

WITH cleaned AS (
    SELECT
        TRIM(REPLACE(crew_id, '"', '')) AS crew_id,
        TRIM(REPLACE(crew_name, '"', '')) AS crew_name,
        TRIM(REPLACE(shift_type, '"', '')) AS shift_type,
        TRIM(REPLACE(REPLACE(REPLACE(raw_date, CHAR(13), ''), CHAR(10), ''), '"', '')) AS clean_date
    FROM #crew_roster_stage
),
converted AS (
    SELECT
        clean_date,
        crew_id,
        crew_name,
        shift_type,
        COALESCE(
            TRY_CONVERT(DATE, clean_date, 103),
            TRY_CONVERT(DATE, clean_date, 101),
            TRY_CONVERT(DATE, clean_date, 111),
            TRY_CONVERT(DATE, clean_date, 23),
            TRY_CONVERT(DATE, clean_date, 120)
        ) AS converted_date
    FROM cleaned
)
SELECT TOP 20
    clean_date,
    crew_id,
    crew_name,
    shift_type
FROM converted
WHERE converted_date IS NULL;
GO