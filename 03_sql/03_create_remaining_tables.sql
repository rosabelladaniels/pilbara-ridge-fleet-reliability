CREATE TABLE dbo.maintenance_work_orders (
    work_order_id VARCHAR(20) NOT NULL,
    asset_id VARCHAR(20) NOT NULL,
    work_order_type VARCHAR(50) NULL,
    date_raised DATE NULL,
    planned_start_date DATE NULL,
    actual_start_date DATE NULL,
    actual_finish_date DATE NULL,
    status VARCHAR(50) NULL,
    priority VARCHAR(20) NULL,
    failure_code VARCHAR(50) NULL,
    failure_description VARCHAR(150) NULL,
    labour_hours DECIMAL(8,2) NULL,
    materials_cost_aud DECIMAL(12,2) NULL,
    external_service_cost_aud DECIMAL(12,2) NULL,
    downtime_hours DECIMAL(8,2) NULL,
    crew_id VARCHAR(20) NULL,
    Failure_Category_Standardised VARCHAR(100) NULL,
    Work_Order_Quality_Flag VARCHAR(100) NULL,
    Include_In_Work_Order_Analysis BIT NULL,

    CONSTRAINT PK_maintenance_work_orders PRIMARY KEY (work_order_id),
    CONSTRAINT FK_maintenance_work_orders_asset_register
        FOREIGN KEY (asset_id)
        REFERENCES dbo.asset_register(asset_id)
);
GO

CREATE TABLE dbo.shift_operations_log (
    shift_log_id VARCHAR(20) NOT NULL,
    date DATE NULL,
    shift_type VARCHAR(20) NULL,
    asset_id VARCHAR(20) NULL,
    Asset_ID_Standardised VARCHAR(20) NULL,
    crew_id VARCHAR(20) NULL,
    scheduled_hours DECIMAL(8,2) NULL,
    operating_hours DECIMAL(8,2) NULL,
    idle_hours DECIMAL(8,2) NULL,
    downtime_hours DECIMAL(8,2) NULL,
    tonnes_moved DECIMAL(12,2) NULL,
    metres_drilled DECIMAL(12,2) NULL,
    weather_condition VARCHAR(50) NULL,
    operator_id VARCHAR(20) NULL,
    Shift_Log_Quality_Flag VARCHAR(100) NULL,
    asset_name VARCHAR(100) NULL,
    asset_class VARCHAR(50) NULL,
    Asset_Match_Flag VARCHAR(100) NULL,
    Include_In_Shift_Analysis BIT NULL,

    CONSTRAINT PK_shift_operations_log PRIMARY KEY (shift_log_id),
    CONSTRAINT FK_shift_operations_log_asset_register
        FOREIGN KEY (Asset_ID_Standardised)
        REFERENCES dbo.asset_register(asset_id)
);
GO