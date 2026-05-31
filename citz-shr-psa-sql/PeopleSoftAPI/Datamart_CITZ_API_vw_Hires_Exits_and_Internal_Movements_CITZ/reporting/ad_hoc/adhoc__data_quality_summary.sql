-- adhoc__data_quality_summary.sql
-- Overall data quality summary: row counts, active vs inactive, key field nulls,
-- soft-delete counts, and dropped record totals.
SET NOCOUNT ON;

-- Target table summary
SELECT
    'Target'                                                    AS Source,
    COUNT(*)                                                    AS TotalRows,
    SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END)             AS ActiveRows,
    SUM(CASE WHEN IsActive = 0 THEN 1 ELSE 0 END)             AS SoftDeletedRows,
    SUM(CASE WHEN MoveType = 'Hire' THEN 1 ELSE 0 END)        AS Hires,
    SUM(CASE WHEN MoveType = 'Exit' THEN 1 ELSE 0 END)        AS Exits,
    SUM(CASE WHEN MoveType = 'Move' THEN 1 ELSE 0 END)        AS Moves,
    COUNT(DISTINCT EmplId)                                      AS UniqueEmployees,
    SUM(CASE WHEN NewDeptId IS NULL THEN 1 ELSE 0 END)         AS NullNewDeptId,
    SUM(CASE WHEN NewOrganization IS NULL THEN 1 ELSE 0 END)   AS NullNewOrg,
    SUM(CASE WHEN RowHash IS NULL THEN 1 ELSE 0 END)           AS NullRowHash,
    MIN(EffDt)                                                  AS EarliestEffDt,
    MAX(EffDt)                                                  AS LatestEffDt
FROM dbo.Peoplesoft_HEM

UNION ALL

-- Staging table summary
SELECT
    'Staging',
    COUNT(*),
    NULL, NULL,
    SUM(CASE WHEN MoveType = 'Hire' THEN 1 ELSE 0 END),
    SUM(CASE WHEN MoveType = 'Exit' THEN 1 ELSE 0 END),
    SUM(CASE WHEN MoveType = 'Move' THEN 1 ELSE 0 END),
    COUNT(DISTINCT EmplId),
    SUM(CASE WHEN NewDeptId IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN NewOrganization IS NULL THEN 1 ELSE 0 END),
    NULL,
    MIN(EffDt),
    MAX(EffDt)
FROM dbo.Stg_Peoplesoft_HEM

UNION ALL

-- Dropped records summary
SELECT
    'Dropped',
    COUNT(*),
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    MIN(CAST(LoadDtmUtc AS DATE)),
    MAX(CAST(LoadDtmUtc AS DATE))
FROM dbo.Stg_Peoplesoft_HEM_Dropped;
