/*=============================================================================
File:    adhoc__data_quality_summary.sql
Purpose: End-to-end data quality summary — target state, staging anomalies,
         and dropped record history in a single query set.
=============================================================================*/

SET NOCOUNT ON;

-- 1. Target table counts
SELECT
    'Target'                                         AS Source,
    COUNT(*)                                         AS TotalRows,
    SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END)   AS ActiveRows,
    SUM(CASE WHEN IsActive = 0 THEN 1 ELSE 0 END)   AS SoftDeletedRows,
    SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END)   AS FilledPositions,
    SUM(CASE WHEN EmplId = ''  THEN 1 ELSE 0 END)   AS VacantPositions
FROM dbo.Peoplesoft_SO001HRORG;

-- 2. NULL key check (should be 0 in target — enforced by NOT NULL constraint)
SELECT
    'NullPosPosition' AS Check_Name,
    SUM(CASE WHEN PosPosition IS NULL OR PosPosition = '' THEN 1 ELSE 0 END) AS ViolationCount
FROM dbo.Peoplesoft_SO001HRORG;

-- 3. Duplicate key check (should be 0 in target — enforced by PK)
SELECT
    'DuplicateCompositeKey' AS Check_Name,
    COUNT(*) AS ViolationCount
FROM (
    SELECT PosPosition, EmplId
    FROM dbo.Peoplesoft_SO001HRORG
    GROUP BY PosPosition, EmplId
    HAVING COUNT(*) > 1
) dup;

-- 4. Missing key attributes on active rows
SELECT
    CASE
        WHEN Organization IS NULL OR LTRIM(RTRIM(Organization)) = ''
        THEN 'Missing Organization'
        ELSE 'Valid Organization'
    END AS OrganizationStatus,
    COUNT(*) AS RowCount
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
GROUP BY
    CASE
        WHEN Organization IS NULL OR LTRIM(RTRIM(Organization)) = ''
        THEN 'Missing Organization'
        ELSE 'Valid Organization'
    END;

-- 5. Dropped records summary (lifetime from quality log)
SELECT
    DropReason,
    COUNT(*)         AS TotalDropped,
    MIN(LoadDtmUtc)  AS FirstSeenUtc,
    MAX(LoadDtmUtc)  AS LastSeenUtc
FROM dbo.Stg_Peoplesoft_SO001HRORG_Dropped
GROUP BY DropReason
ORDER BY TotalDropped DESC;
