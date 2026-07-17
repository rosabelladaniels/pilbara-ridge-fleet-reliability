USE PilbaraRidgeFleetReliability;
GO

DELETE FROM dbo.asset_register;
GO

BULK INSERT dbo.asset_register
FROM 'C:\Users\rosab\OneDrive\Desktop\Data-Analytics-Portfolio\01_Pilbara-Ridge_Fleet-Maintenance\pilbara-ridge-fleet-reliability\01_raw_data\asset_register.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

SELECT COUNT(*) AS asset_register_row_count
FROM dbo.asset_register;
GO