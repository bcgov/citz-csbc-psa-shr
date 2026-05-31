-- hc__executive_summary.sql
-- Four result sets for an executive daily briefing on employee headcount.
--   1. Current state snapshot
--   2. Latest run activity (changes this ETL run)
--   3. Data quality indicators
--   4. Trend indicators (last 7 run-days)

-- Result set 1: current state snapshot
SELECT
    COUNT(*) FILTER (WHERE IsActive = 1)                        AS TotalActive,
    COUNT(*) FILTER (WHERE IsActive = 0)                        AS TotalInactive,
    COUNT(*)                                                    AS TotalRecords,
    COUNT(DISTINCT Level1) FILTER (WHERE IsActive = 1)          AS DistinctLevel1,
    COUNT(DISTINCT DeptId) FILTER (WHERE IsActive = 1)          AS DistinctDepartments,
    COUNT(DISTINCT SalAdminPlan) FILTER (WHERE IsActive = 1)    AS DistinctSalaryPlans,
    CAST(MAX(LastUpdatedUtc) AS DATE)                           AS LatestUpdateDate
FROM dbo.Peoplesoft_SHR010HRORG;

-- Result set 2: latest run activity
;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SHR010HRORG_Audit
)
SELECT
    lr.RunId,
    MAX(a.AuditDtmUtc)                                         AS RunDtmUtc,
    COUNT(*) FILTER (WHERE a.ActionType = 'INSERT')            AS Inserts,
    COUNT(*) FILTER (WHERE a.ActionType = 'UPDATE')            AS Updates,
    COUNT(*) FILTER (WHERE a.ActionType = 'SOFT_DELETE')       AS SoftDeletes,
    COUNT(*) FILTER (WHERE a.ActionType = 'REACTIVATE')        AS Reactivations,
    COUNT(*)                                                   AS TotalEvents
FROM dbo.Peoplesoft_SHR010HRORG_Audit  a
JOIN latest_run                        lr ON a.RunId = lr.RunId
GROUP BY lr.RunId;

-- Result set 3: data quality indicators
SELECT
    COUNT(*) FILTER (WHERE IsActive = 1 AND EmailId IS NULL)    AS ActiveMissingEmail,
    COUNT(*) FILTER (WHERE IsActive = 1 AND Idir IS NULL)       AS ActiveMissingIdir,
    COUNT(*) FILTER (WHERE IsActive = 1 AND Supervisor IS NULL) AS ActiveMissingSupervisor,
    COUNT(*) FILTER (WHERE IsActive = 1 AND FutureReturnDate IS NOT NULL) AS ActiveOnLeave
FROM dbo.Peoplesoft_SHR010HRORG;

-- Result set 4: trend indicators — net headcount change per ETL run (last 7)
;WITH run_summary AS
(
    SELECT
        a.RunId,
        CAST(MIN(a.AuditDtmUtc) AS DATE)                       AS RunDate,
        COUNT(*) FILTER (WHERE a.ActionType = 'INSERT')        AS Inserts,
        COUNT(*) FILTER (WHERE a.ActionType = 'SOFT_DELETE')   AS SoftDeletes,
        COUNT(*) FILTER (WHERE a.ActionType = 'REACTIVATE')    AS Reactivations
    FROM dbo.Peoplesoft_SHR010HRORG_Audit a
    GROUP BY a.RunId
),
ranked AS
(
    SELECT *, ROW_NUMBER() OVER (ORDER BY RunDate DESC) AS RowNum
    FROM run_summary
)
SELECT
    RunDate,
    Inserts,
    SoftDeletes,
    Reactivations,
    (Inserts - SoftDeletes + Reactivations)                    AS NetChange
FROM ranked
WHERE RowNum <= 7
ORDER BY RunDate DESC;
