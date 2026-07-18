USE PilbaraRidgeFleetReliability;
GO

/*
15_sql_maintenance_performance_analysis.sql

Purpose:
Analyse maintenance performance using the maintenance_work_orders table.

This script answers:
1. What is the overall work order quality and inclusion profile?
2. Which work order types drive volume, labour, downtime and cost?
3. Which priority levels drive downtime and cost?
4. Which failure categories drive downtime and cost?
5. Which assets have the highest valid work order burden?
6. Which individual work orders have the highest downtime?
7. Which individual work orders have the highest maintenance cost?
8. Which assets show repeated failure category patterns?
9. Which excluded work orders need attention before analysis?
*/


-- 1. Work order quality and inclusion summary

SELECT
    Work_Order_Quality_Flag,
    Include_In_Work_Order_Analysis,
    COUNT(*) AS work_order_count
FROM dbo.maintenance_work_orders
GROUP BY
    Work_Order_Quality_Flag,
    Include_In_Work_Order_Analysis
ORDER BY
    Include_In_Work_Order_Analysis,
    work_order_count DESC;
GO


-- 2. Work order performance by work order type

SELECT
    work_order_type,
    COUNT(*) AS valid_work_order_count,
    SUM(labour_hours) AS total_labour_hours,
    AVG(labour_hours) AS avg_labour_hours,
    SUM(downtime_hours) AS total_downtime_hours,
    AVG(downtime_hours) AS avg_downtime_hours,
    SUM(materials_cost_aud) AS total_materials_cost_aud,
    SUM(external_service_cost_aud) AS total_external_service_cost_aud,
    SUM(materials_cost_aud + external_service_cost_aud) AS total_maintenance_cost_aud,
    AVG(materials_cost_aud + external_service_cost_aud) AS avg_maintenance_cost_aud
FROM dbo.maintenance_work_orders
WHERE Include_In_Work_Order_Analysis = 1
GROUP BY
    work_order_type
ORDER BY
    total_maintenance_cost_aud DESC;
GO


-- 3. Work order performance by priority

SELECT
    priority,
    COUNT(*) AS valid_work_order_count,
    SUM(labour_hours) AS total_labour_hours,
    AVG(labour_hours) AS avg_labour_hours,
    SUM(downtime_hours) AS total_downtime_hours,
    AVG(downtime_hours) AS avg_downtime_hours,
    SUM(materials_cost_aud + external_service_cost_aud) AS total_maintenance_cost_aud,
    AVG(materials_cost_aud + external_service_cost_aud) AS avg_maintenance_cost_aud
FROM dbo.maintenance_work_orders
WHERE Include_In_Work_Order_Analysis = 1
GROUP BY
    priority
ORDER BY
    total_downtime_hours DESC;
GO


-- 4. Work order performance by standardised failure category

SELECT
    Failure_Category_Standardised,
    COUNT(*) AS valid_work_order_count,
    SUM(labour_hours) AS total_labour_hours,
    AVG(labour_hours) AS avg_labour_hours,
    SUM(downtime_hours) AS total_downtime_hours,
    AVG(downtime_hours) AS avg_downtime_hours,
    SUM(materials_cost_aud) AS total_materials_cost_aud,
    SUM(external_service_cost_aud) AS total_external_service_cost_aud,
    SUM(materials_cost_aud + external_service_cost_aud) AS total_maintenance_cost_aud,
    AVG(materials_cost_aud + external_service_cost_aud) AS avg_maintenance_cost_aud
FROM dbo.maintenance_work_orders
WHERE Include_In_Work_Order_Analysis = 1
GROUP BY
    Failure_Category_Standardised
ORDER BY
    total_downtime_hours DESC,
    total_maintenance_cost_aud DESC;
GO


-- 5. Maintenance burden by asset

SELECT
    w.asset_id,
    a.asset_name,
    a.asset_class,
    COUNT(*) AS valid_work_order_count,
    SUM(w.labour_hours) AS total_labour_hours,
    SUM(w.downtime_hours) AS total_downtime_hours,
    SUM(w.materials_cost_aud + w.external_service_cost_aud) AS total_maintenance_cost_aud,
    AVG(w.materials_cost_aud + w.external_service_cost_aud) AS avg_maintenance_cost_aud
FROM dbo.maintenance_work_orders w
LEFT JOIN dbo.asset_register a
    ON w.asset_id = a.asset_id
WHERE w.Include_In_Work_Order_Analysis = 1
GROUP BY
    w.asset_id,
    a.asset_name,
    a.asset_class
ORDER BY
    total_downtime_hours DESC,
    total_maintenance_cost_aud DESC;
GO


-- 6. Top 20 work orders by downtime

SELECT TOP 20
    work_order_id,
    asset_id,
    date_raised,
    work_order_type,
    status,
    priority,
    Failure_Category_Standardised,
    labour_hours,
    downtime_hours,
    materials_cost_aud,
    external_service_cost_aud,
    materials_cost_aud + external_service_cost_aud AS total_maintenance_cost_aud
FROM dbo.maintenance_work_orders
WHERE Include_In_Work_Order_Analysis = 1
ORDER BY
    downtime_hours DESC,
    materials_cost_aud + external_service_cost_aud DESC;
GO


-- 7. Top 20 work orders by maintenance cost

SELECT TOP 20
    work_order_id,
    asset_id,
    date_raised,
    work_order_type,
    status,
    priority,
    Failure_Category_Standardised,
    labour_hours,
    downtime_hours,
    materials_cost_aud,
    external_service_cost_aud,
    materials_cost_aud + external_service_cost_aud AS total_maintenance_cost_aud
FROM dbo.maintenance_work_orders
WHERE Include_In_Work_Order_Analysis = 1
ORDER BY
    materials_cost_aud + external_service_cost_aud DESC,
    downtime_hours DESC;
GO


-- 8. Repeated maintenance patterns by asset and failure category

SELECT
    w.asset_id,
    a.asset_name,
    a.asset_class,
    w.Failure_Category_Standardised,
    COUNT(*) AS valid_work_order_count,
    SUM(w.labour_hours) AS total_labour_hours,
    SUM(w.downtime_hours) AS total_downtime_hours,
    SUM(w.materials_cost_aud + w.external_service_cost_aud) AS total_maintenance_cost_aud
FROM dbo.maintenance_work_orders w
LEFT JOIN dbo.asset_register a
    ON w.asset_id = a.asset_id
WHERE w.Include_In_Work_Order_Analysis = 1
GROUP BY
    w.asset_id,
    a.asset_name,
    a.asset_class,
    w.Failure_Category_Standardised
HAVING COUNT(*) >= 2
ORDER BY
    valid_work_order_count DESC,
    total_downtime_hours DESC,
    total_maintenance_cost_aud DESC;
GO


-- 9. Excluded work order records for audit

SELECT
    work_order_id,
    asset_id,
    date_raised,
    planned_start_date,
    actual_start_date,
    actual_finish_date,
    work_order_type,
    status,
    priority,
    Failure_Category_Standardised,
    labour_hours,
    downtime_hours,
    Work_Order_Quality_Flag,
    Include_In_Work_Order_Analysis
FROM dbo.maintenance_work_orders
WHERE Include_In_Work_Order_Analysis = 0
ORDER BY
    Work_Order_Quality_Flag,
    work_order_id;
GO


-- 10. Excluded work order summary by reason

SELECT
    Work_Order_Quality_Flag,
    COUNT(*) AS excluded_work_order_count
FROM dbo.maintenance_work_orders
WHERE Include_In_Work_Order_Analysis = 0
GROUP BY
    Work_Order_Quality_Flag
ORDER BY
    excluded_work_order_count DESC;
GO