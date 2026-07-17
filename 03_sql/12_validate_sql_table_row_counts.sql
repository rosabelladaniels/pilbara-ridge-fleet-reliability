USE PilbaraRidgeFleetReliability;
GO

/*
Final SQL load validation

Purpose:
Confirm that all seven project tables have loaded into SQL Server
and compare row counts against expected project counts.
*/

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

SELECT 'parts_inventory' AS table_name, COUNT(*) AS row_count
FROM dbo.parts_inventory

UNION ALL

SELECT 'maintenance_work_orders' AS table_name, COUNT(*) AS row_count
FROM dbo.maintenance_work_orders

UNION ALL

SELECT 'shift_operations_log' AS table_name, COUNT(*) AS row_count
FROM dbo.shift_operations_log

ORDER BY table_name;
GO