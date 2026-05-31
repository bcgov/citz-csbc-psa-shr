-- hc__daily_summary.sql
-- Two result sets:
--   1. Current snapshot: total active employees + breakdown by top categories
--   2. Latest run activity: counts of INSERT / UPDATE / SOFT_DELETE / REACTIVATE

-- Result set 1: current snapshot
SELECT
    COUNT(*) FILTER (WHERE IsActive = 1)  AS TotalActive,
    COUNT(*) FILTER (WHERE IsActive = 0)  AS TotalInactive,
    COUNT(*)                              AS TotalRecords
FROM dbo.Peoplesoft_SHR010HRORG;

-- Result set 2: latest run activity
;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SHR010HRORG_Audit
)
SELECT
    a.ActionType,
    COUNT(*)        AS EventCount
FROM dbo.Peoplesoft_SHR010HRORG_Audit  a
JOIN latest_run                        lr ON a.RunId = lr.RunId
GROUP BY a.ActionType
ORDER BY a.ActionType;
