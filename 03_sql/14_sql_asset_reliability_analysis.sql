USE PilbaraRidgeFleetReliability;
GO

/*
14_sql_asset_reliability_analysis.sql

Purpose:
Analyse asset reliability across breakdown events, shift operations and maintenance work orders.

This script answers:
1. Which assets have the most breakdown events?
2. Which asset classes have the most breakdown events?
3. Which failure categories appear most often in maintenance work orders?
4. Which failure categories drive the most work order downtime?
5. Which assets have the highest operational downtime?
6. Which asset classes have the highest operational downtime?
7. Which assets have the highest work order downtime and cost?
8. Which assets have repeated maintenance issues?
9. Which assets are the strongest reliability risks?

Risk logic:
The reliability risk flag uses a ranked score rather than broad thresholds.
This avoids classifying every asset as high risk.
*/


-- 1. Breakdown events by asset

SELECT
    b.asset_id,
    a.asset_name,
    a.asset_class,
    COUNT(*) AS breakdown_event_count
FROM dbo.breakdown_events b
LEFT JOIN dbo.asset_register a
    ON b.asset_id = a.asset_id
GROUP BY
    b.asset_id,
    a.asset_name,
    a.asset_class
ORDER BY
    breakdown_event_count DESC,
    b.asset_id;
GO


-- 2. Breakdown events by asset class

SELECT
    a.asset_class,
    COUNT(*) AS breakdown_event_count
FROM dbo.breakdown_events b
LEFT JOIN dbo.asset_register a
    ON b.asset_id = a.asset_id
GROUP BY
    a.asset_class
ORDER BY
    breakdown_event_count DESC;
GO


-- 3. Maintenance work orders by standardised failure category

SELECT
    w.Failure_Category_Standardised,
    COUNT(*) AS valid_work_order_count,
    SUM(w.labour_hours) AS total_labour_hours,
    SUM(w.downtime_hours) AS total_work_order_downtime_hours,
    SUM(w.materials_cost_aud) AS total_materials_cost_aud,
    SUM(w.external_service_cost_aud) AS total_external_service_cost_aud,
    SUM(w.materials_cost_aud + w.external_service_cost_aud) AS total_maintenance_cost_aud
FROM dbo.maintenance_work_orders w
WHERE w.Include_In_Work_Order_Analysis = 1
GROUP BY
    w.Failure_Category_Standardised
ORDER BY
    total_work_order_downtime_hours DESC,
    valid_work_order_count DESC;
GO


-- 4. Operational downtime by asset from valid shift logs only

SELECT
    s.Asset_ID_Standardised AS asset_id,
    s.asset_name,
    s.asset_class,
    COUNT(*) AS valid_shift_record_count,
    SUM(s.operating_hours) AS total_operating_hours,
    SUM(s.downtime_hours) AS total_shift_downtime_hours,
    AVG(s.downtime_hours) AS avg_shift_downtime_hours,
    CAST(
        SUM(s.downtime_hours) * 100.0 /
        NULLIF(SUM(s.operating_hours) + SUM(s.downtime_hours), 0)
        AS DECIMAL(10,2)
    ) AS downtime_rate_percent
FROM dbo.shift_operations_log s
WHERE s.Include_In_Shift_Analysis = 1
GROUP BY
    s.Asset_ID_Standardised,
    s.asset_name,
    s.asset_class
ORDER BY
    total_shift_downtime_hours DESC;
GO


-- 5. Operational downtime by asset class from valid shift logs only

SELECT
    s.asset_class,
    COUNT(*) AS valid_shift_record_count,
    SUM(s.operating_hours) AS total_operating_hours,
    SUM(s.downtime_hours) AS total_shift_downtime_hours,
    AVG(s.downtime_hours) AS avg_shift_downtime_hours,
    CAST(
        SUM(s.downtime_hours) * 100.0 /
        NULLIF(SUM(s.operating_hours) + SUM(s.downtime_hours), 0)
        AS DECIMAL(10,2)
    ) AS downtime_rate_percent
FROM dbo.shift_operations_log s
WHERE s.Include_In_Shift_Analysis = 1
GROUP BY
    s.asset_class
ORDER BY
    total_shift_downtime_hours DESC;
GO


-- 6. Work order downtime and cost by asset from valid work orders only

SELECT
    w.asset_id,
    a.asset_name,
    a.asset_class,
    COUNT(*) AS valid_work_order_count,
    SUM(w.labour_hours) AS total_labour_hours,
    SUM(w.downtime_hours) AS total_work_order_downtime_hours,
    SUM(w.materials_cost_aud) AS total_materials_cost_aud,
    SUM(w.external_service_cost_aud) AS total_external_service_cost_aud,
    SUM(w.materials_cost_aud + w.external_service_cost_aud) AS total_maintenance_cost_aud
FROM dbo.maintenance_work_orders w
LEFT JOIN dbo.asset_register a
    ON w.asset_id = a.asset_id
WHERE w.Include_In_Work_Order_Analysis = 1
GROUP BY
    w.asset_id,
    a.asset_name,
    a.asset_class
ORDER BY
    total_work_order_downtime_hours DESC;
GO


-- 7. Repeated maintenance issues by asset and failure category

SELECT
    w.asset_id,
    a.asset_name,
    a.asset_class,
    w.Failure_Category_Standardised,
    COUNT(*) AS valid_work_order_count,
    SUM(w.downtime_hours) AS total_work_order_downtime_hours,
    SUM(w.labour_hours) AS total_labour_hours,
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
    total_work_order_downtime_hours DESC;
GO


-- 8. Ranked reliability risk view by asset

WITH breakdown_summary AS (
    SELECT
        asset_id,
        COUNT(*) AS breakdown_event_count
    FROM dbo.breakdown_events
    GROUP BY asset_id
),
shift_summary AS (
    SELECT
        Asset_ID_Standardised AS asset_id,
        SUM(downtime_hours) AS total_shift_downtime_hours,
        SUM(operating_hours) AS total_operating_hours,
        CAST(
            SUM(downtime_hours) * 100.0 /
            NULLIF(SUM(operating_hours) + SUM(downtime_hours), 0)
            AS DECIMAL(10,2)
        ) AS downtime_rate_percent
    FROM dbo.shift_operations_log
    WHERE Include_In_Shift_Analysis = 1
    GROUP BY Asset_ID_Standardised
),
work_order_summary AS (
    SELECT
        asset_id,
        COUNT(*) AS valid_work_order_count,
        SUM(downtime_hours) AS total_work_order_downtime_hours,
        SUM(materials_cost_aud + external_service_cost_aud) AS total_maintenance_cost_aud
    FROM dbo.maintenance_work_orders
    WHERE Include_In_Work_Order_Analysis = 1
    GROUP BY asset_id
),
asset_metrics AS (
    SELECT
        a.asset_id,
        a.asset_name,
        a.asset_class,
        COALESCE(b.breakdown_event_count, 0) AS breakdown_event_count,
        COALESCE(s.total_shift_downtime_hours, 0) AS total_shift_downtime_hours,
        COALESCE(s.total_operating_hours, 0) AS total_operating_hours,
        COALESCE(s.downtime_rate_percent, 0) AS downtime_rate_percent,
        COALESCE(w.valid_work_order_count, 0) AS valid_work_order_count,
        COALESCE(w.total_work_order_downtime_hours, 0) AS total_work_order_downtime_hours,
        COALESCE(w.total_maintenance_cost_aud, 0) AS total_maintenance_cost_aud
    FROM dbo.asset_register a
    LEFT JOIN breakdown_summary b
        ON a.asset_id = b.asset_id
    LEFT JOIN shift_summary s
        ON a.asset_id = s.asset_id
    LEFT JOIN work_order_summary w
        ON a.asset_id = w.asset_id
),
ranked_metrics AS (
    SELECT
        *,
        RANK() OVER (ORDER BY breakdown_event_count DESC) AS breakdown_rank,
        RANK() OVER (ORDER BY total_shift_downtime_hours DESC) AS shift_downtime_rank,
        RANK() OVER (ORDER BY downtime_rate_percent DESC) AS downtime_rate_rank,
        RANK() OVER (ORDER BY total_work_order_downtime_hours DESC) AS work_order_downtime_rank,
        RANK() OVER (ORDER BY total_maintenance_cost_aud DESC) AS maintenance_cost_rank
    FROM asset_metrics
),
risk_scored AS (
    SELECT
        *,
        (
            breakdown_rank +
            shift_downtime_rank +
            downtime_rate_rank +
            work_order_downtime_rank +
            maintenance_cost_rank
        ) AS reliability_risk_score
    FROM ranked_metrics
),
final_risk AS (
    SELECT
        *,
        RANK() OVER (ORDER BY reliability_risk_score ASC) AS reliability_risk_rank
    FROM risk_scored
)
SELECT
    asset_id,
    asset_name,
    asset_class,
    breakdown_event_count,
    total_shift_downtime_hours,
    total_operating_hours,
    downtime_rate_percent,
    valid_work_order_count,
    total_work_order_downtime_hours,
    total_maintenance_cost_aud,
    reliability_risk_score,
    reliability_risk_rank,
    CASE
        WHEN reliability_risk_rank <= 5 THEN 'High reliability risk'
        WHEN reliability_risk_rank <= 15 THEN 'Medium reliability risk'
        ELSE 'Lower reliability risk'
    END AS reliability_risk_flag
FROM final_risk
ORDER BY
    reliability_risk_rank,
    reliability_risk_score,
    breakdown_event_count DESC,
    total_shift_downtime_hours DESC;
GO


-- 9. Reliability risk flag summary

WITH breakdown_summary AS (
    SELECT
        asset_id,
        COUNT(*) AS breakdown_event_count
    FROM dbo.breakdown_events
    GROUP BY asset_id
),
shift_summary AS (
    SELECT
        Asset_ID_Standardised AS asset_id,
        SUM(downtime_hours) AS total_shift_downtime_hours,
        SUM(operating_hours) AS total_operating_hours,
        CAST(
            SUM(downtime_hours) * 100.0 /
            NULLIF(SUM(operating_hours) + SUM(downtime_hours), 0)
            AS DECIMAL(10,2)
        ) AS downtime_rate_percent
    FROM dbo.shift_operations_log
    WHERE Include_In_Shift_Analysis = 1
    GROUP BY Asset_ID_Standardised
),
work_order_summary AS (
    SELECT
        asset_id,
        COUNT(*) AS valid_work_order_count,
        SUM(downtime_hours) AS total_work_order_downtime_hours,
        SUM(materials_cost_aud + external_service_cost_aud) AS total_maintenance_cost_aud
    FROM dbo.maintenance_work_orders
    WHERE Include_In_Work_Order_Analysis = 1
    GROUP BY asset_id
),
asset_metrics AS (
    SELECT
        a.asset_id,
        a.asset_name,
        a.asset_class,
        COALESCE(b.breakdown_event_count, 0) AS breakdown_event_count,
        COALESCE(s.total_shift_downtime_hours, 0) AS total_shift_downtime_hours,
        COALESCE(s.total_operating_hours, 0) AS total_operating_hours,
        COALESCE(s.downtime_rate_percent, 0) AS downtime_rate_percent,
        COALESCE(w.valid_work_order_count, 0) AS valid_work_order_count,
        COALESCE(w.total_work_order_downtime_hours, 0) AS total_work_order_downtime_hours,
        COALESCE(w.total_maintenance_cost_aud, 0) AS total_maintenance_cost_aud
    FROM dbo.asset_register a
    LEFT JOIN breakdown_summary b
        ON a.asset_id = b.asset_id
    LEFT JOIN shift_summary s
        ON a.asset_id = s.asset_id
    LEFT JOIN work_order_summary w
        ON a.asset_id = w.asset_id
),
ranked_metrics AS (
    SELECT
        *,
        RANK() OVER (ORDER BY breakdown_event_count DESC) AS breakdown_rank,
        RANK() OVER (ORDER BY total_shift_downtime_hours DESC) AS shift_downtime_rank,
        RANK() OVER (ORDER BY downtime_rate_percent DESC) AS downtime_rate_rank,
        RANK() OVER (ORDER BY total_work_order_downtime_hours DESC) AS work_order_downtime_rank,
        RANK() OVER (ORDER BY total_maintenance_cost_aud DESC) AS maintenance_cost_rank
    FROM asset_metrics
),
risk_scored AS (
    SELECT
        *,
        (
            breakdown_rank +
            shift_downtime_rank +
            downtime_rate_rank +
            work_order_downtime_rank +
            maintenance_cost_rank
        ) AS reliability_risk_score
    FROM ranked_metrics
),
final_risk AS (
    SELECT
        *,
        RANK() OVER (ORDER BY reliability_risk_score ASC) AS reliability_risk_rank
    FROM risk_scored
),
risk_labelled AS (
    SELECT
        CASE
            WHEN reliability_risk_rank <= 5 THEN 'High reliability risk'
            WHEN reliability_risk_rank <= 15 THEN 'Medium reliability risk'
            ELSE 'Lower reliability risk'
        END AS reliability_risk_flag
    FROM final_risk
)
SELECT
    reliability_risk_flag,
    COUNT(*) AS asset_count
FROM risk_labelled
GROUP BY reliability_risk_flag
ORDER BY
    CASE reliability_risk_flag
        WHEN 'High reliability risk' THEN 1
        WHEN 'Medium reliability risk' THEN 2
        ELSE 3
    END;
GO