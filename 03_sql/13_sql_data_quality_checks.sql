USE PilbaraRidgeFleetReliability;
GO

/*
13_sql_data_quality_checks.sql

Purpose:
Run SQL data quality checks across the Pilbara Ridge Fleet Reliability project tables.

This script checks:
1. Final row counts by table
2. Duplicate work_order_id values
3. Work orders excluded from analysis and why
4. Shift records excluded from analysis and why
5. Fuel records excluded from analysis and why
6. Asset IDs that failed matching
7. Negative operating, downtime and labour hour records
8. Missing dates and missing fuel litres
*/

-- 1. Final row counts across all loaded tables

SELECT 'asset_register' AS table_name, COUNT(*) AS row_count
FROM dbo.asset_register

UNION ALL

SELECT 'breakdown_events' AS table_name, COUNT(*) AS row_count
FROM dbo.breakdown_events

UNION ALL

SELECT 'crew_roster' AS table_name, COUNT(*) AS row_count
FROM dbo.crew_roster

UNION ALL

SELECT 'fuel_usage' AS table_name, COUNT(*) AS row_count
FROM dbo.fuel_usage

UNION ALL

SELECT 'maintenance_work_orders' AS table_name, COUNT(*) AS row_count
FROM dbo.maintenance_work_orders

UNION ALL

SELECT 'parts_inventory' AS table_name, COUNT(*) AS row_count
FROM dbo.parts_inventory

UNION ALL

SELECT 'shift_operations_log' AS table_name, COUNT(*) AS row_count
FROM dbo.shift_operations_log

ORDER BY table_name;
GO


-- 2. Duplicate work_order_id values

SELECT
    work_order_id,
    COUNT(*) AS duplicate_count
FROM dbo.maintenance_work_orders
GROUP BY work_order_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, work_order_id;
GO


-- 3. Work order quality flag summary

SELECT
    Work_Order_Quality_Flag,
    COUNT(*) AS record_count
FROM dbo.maintenance_work_orders
GROUP BY Work_Order_Quality_Flag
ORDER BY record_count DESC;
GO


-- 4. Work orders excluded from analysis

SELECT
    Work_Order_Quality_Flag,
    Include_In_Work_Order_Analysis,
    COUNT(*) AS record_count
FROM dbo.maintenance_work_orders
GROUP BY
    Work_Order_Quality_Flag,
    Include_In_Work_Order_Analysis
ORDER BY
    Include_In_Work_Order_Analysis,
    record_count DESC;
GO


-- 5. Shift log quality flag summary

SELECT
    Shift_Log_Quality_Flag,
    COUNT(*) AS record_count
FROM dbo.shift_operations_log
GROUP BY Shift_Log_Quality_Flag
ORDER BY record_count DESC;
GO


-- 6. Shift records excluded from analysis

SELECT
    Shift_Log_Quality_Flag,
    Asset_Match_Flag,
    Include_In_Shift_Analysis,
    COUNT(*) AS record_count
FROM dbo.shift_operations_log
GROUP BY
    Shift_Log_Quality_Flag,
    Asset_Match_Flag,
    Include_In_Shift_Analysis
ORDER BY
    Include_In_Shift_Analysis,
    record_count DESC;
GO


-- 7. Fuel quality flag summary

SELECT
    Fuel_Record_Quality_Flag,
    COUNT(*) AS record_count
FROM dbo.fuel_usage
GROUP BY Fuel_Record_Quality_Flag
ORDER BY record_count DESC;
GO


-- 8. Fuel records excluded from analysis

SELECT
    Fuel_Record_Quality_Flag,
    Include_In_Fuel_Analysis,
    COUNT(*) AS record_count
FROM dbo.fuel_usage
GROUP BY
    Fuel_Record_Quality_Flag,
    Include_In_Fuel_Analysis
ORDER BY
    Include_In_Fuel_Analysis,
    record_count DESC;
GO


-- 9. Unmatched fuel asset IDs

SELECT
    asset_id,
    Asset_ID_Standardised,
    Fuel_Record_Quality_Flag,
    COUNT(*) AS record_count
FROM dbo.fuel_usage
WHERE Fuel_Record_Quality_Flag = 'Asset not found in asset register'
GROUP BY
    asset_id,
    Asset_ID_Standardised,
    Fuel_Record_Quality_Flag
ORDER BY record_count DESC;
GO


-- 10. Unmatched shift operation asset IDs

SELECT
    asset_id,
    Asset_ID_Standardised,
    Asset_Match_Flag,
    COUNT(*) AS record_count
FROM dbo.shift_operations_log
WHERE Asset_Match_Flag = 'Asset not found in asset register'
GROUP BY
    asset_id,
    Asset_ID_Standardised,
    Asset_Match_Flag
ORDER BY record_count DESC;
GO


-- 11. Negative operating hours in shift logs

SELECT
    shift_log_id,
    [date],
    shift_type,
    asset_id,
    Asset_ID_Standardised,
    operating_hours,
    downtime_hours,
    Shift_Log_Quality_Flag
FROM dbo.shift_operations_log
WHERE operating_hours < 0
ORDER BY [date], shift_log_id;
GO


-- 12. Negative downtime hours in shift logs

SELECT
    shift_log_id,
    [date],
    shift_type,
    asset_id,
    Asset_ID_Standardised,
    operating_hours,
    downtime_hours,
    Shift_Log_Quality_Flag
FROM dbo.shift_operations_log
WHERE downtime_hours < 0
ORDER BY [date], shift_log_id;
GO


-- 13. Negative labour hours in work orders

SELECT
    work_order_id,
    asset_id,
    date_raised,
    work_order_type,
    status,
    priority,
    labour_hours,
    downtime_hours,
    Work_Order_Quality_Flag,
    Include_In_Work_Order_Analysis
FROM dbo.maintenance_work_orders
WHERE labour_hours < 0
ORDER BY date_raised, work_order_id;
GO


-- 14. Missing fuel litres

SELECT
    COUNT(*) AS missing_fuel_litres_count
FROM dbo.fuel_usage
WHERE fuel_litres IS NULL;
GO


-- 15. Missing or invalid work order dates

SELECT
    Work_Order_Quality_Flag,
    COUNT(*) AS record_count
FROM dbo.maintenance_work_orders
WHERE date_raised IS NULL
   OR planned_start_date IS NULL
   OR actual_start_date IS NULL
GROUP BY Work_Order_Quality_Flag
ORDER BY record_count DESC;
GO