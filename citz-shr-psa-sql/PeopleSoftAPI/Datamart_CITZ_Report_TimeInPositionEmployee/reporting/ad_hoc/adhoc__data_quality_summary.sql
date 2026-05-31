-- adhoc__data_quality_summary.sql
-- Overall data quality summary for the TIP pipeline:
-- row counts, active vs inactive, null key fields, and dropped totals.
SET NOCOUNT ON;

-- Target table summary
SELECT
    'Target'                                                               AS Source,
    COUNT(*)                                                               AS TotalRows,
    SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END)                         AS ActiveRows,
    SUM(CASE WHEN IsActive = 0 THEN 1 ELSE 0 END)                         AS SoftDeletedRows,
    COUNT(DISTINCT EmployeeId)                                             AS UniqueEmployees,
    SUM(CASE WHEN ExitDate IS NULL THEN 1 ELSE 0 END)                     AS CurrentlyInPosition,
    SUM(CASE WHEN ExitDate IS NOT NULL THEN 1 ELSE 0 END)                 AS ExitedPosition,
    SUM(CASE WHEN Organization IS NULL THEN 1 ELSE 0 END)                 AS NullOrganization,
    SUM(CASE WHEN ClassificationGroupAtEntry IS NULL THEN 1 ELSE 0 END)   AS NullClassification,
    MIN(EntryDate)                                                         AS EarliestEntryDate,
    MAX(EntryDate)                                                         AS LatestEntryDate
FROM dbo.Peoplesoft_TIP

UNION ALL

-- Staging table summary
SELECT
    'Staging',
    COUNT(*),
    NULL, NULL,
    COUNT(DISTINCT EmployeeId),
    SUM(CASE WHEN ExitDate IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN ExitDate IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN Organization IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN ClassificationGroupAtEntry IS NULL THEN 1 ELSE 0 END),
    MIN(EntryDate),
    MAX(EntryDate)
FROM dbo.Stg_Peoplesoft_TIP

UNION ALL

-- Dropped records summary
SELECT
    'Dropped',
    COUNT(*),
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    MIN(CAST(LoadDtmUtc AS DATE)),
    MAX(CAST(LoadDtmUtc AS DATE))
FROM dbo.Stg_Peoplesoft_TIP_Dropped;
