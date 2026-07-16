USE PilbaraRidgeFleetReliability;
GO

IF OBJECT_ID('dbo.breakdown_events', 'U') IS NOT NULL
    DROP TABLE dbo.breakdown_events;
GO

IF OBJECT_ID('dbo.asset_register', 'U') IS NOT NULL
    DROP TABLE dbo.asset_register;
GO

CREATE TABLE dbo.asset_register (
    asset_id VARCHAR(20) NOT NULL,
    asset_name VARCHAR(100) NOT NULL,
    asset_class VARCHAR(50) NOT NULL,
    manufacturer VARCHAR(50) NULL,
    model VARCHAR(50) NULL,
    year_commissioned INT NULL,
    criticality_rating VARCHAR(20) NULL,
    ownership_type VARCHAR(20) NULL,
    status VARCHAR(20) NULL,
    planned_operating_hours_per_day DECIMAL(5,2) NULL,

    CONSTRAINT PK_asset_register PRIMARY KEY (asset_id)
);
GO

CREATE TABLE dbo.breakdown_events (
    breakdown_id VARCHAR(20) NOT NULL,
    asset_id VARCHAR(20) NOT NULL,
    event_start DATETIME2 NULL,
    event_end DATETIME2 NULL,
    failure_system VARCHAR(50) NULL,
    failure_mode VARCHAR(100) NULL,
    severity VARCHAR(20) NULL,
    production_lost_tonnes DECIMAL(12,2) NULL,
    root_cause VARCHAR(100) NULL,
    linked_work_order_id VARCHAR(20) NULL,

    CONSTRAINT PK_breakdown_events PRIMARY KEY (breakdown_id),
    CONSTRAINT FK_breakdown_events_asset_register
        FOREIGN KEY (asset_id)
        REFERENCES dbo.asset_register(asset_id)
);
GO