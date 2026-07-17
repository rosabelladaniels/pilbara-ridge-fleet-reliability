USE PilbaraRidgeFleetReliability;
GO

DELETE FROM dbo.breakdown_events;
GO

BULK INSERT dbo.breakdown_events
FROM 'C:\Users\rosab\OneDrive\Desktop\Data-Analytics-Portfolio\01_Pilbara-Ridge_Fleet-Maintenance\pilbara-ridge-fleet-reliability\01_raw_data\breakdown_events.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

SELECT COUNT(*) AS breakdown_events_row_count
FROM dbo.breakdown_events;
GO