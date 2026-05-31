-- hc__run_history.sql
-- All ETL runs with summary metrics and net headcount change.
-- Use to review pipeline history and track workforce size over time.

SELECT
    a.RunId,
    CAST(MIN(a.AuditDtmUtc) AS DATE)                           AS RunDate,
    MIN(a.AuditDtmUtc)                                         AS RunDtmUtc,
    COUNT(*) FILTER (WHERE a.ActionType = 'INSERT')            AS Inserts,
    COUNT(*) FILTER (WHERE a.ActionType = 'UPDATE')            AS Updates,
    COUNT(*) FILTER (WHERE a.ActionType = 'SOFT_DELETE')       AS SoftDeletes,
    COUNT(*) FILTER (WHERE a.ActionType = 'REACTIVATE')        AS Reactivations,
    (COUNT(*) FILTER (WHERE a.ActionType = 'INSERT')
     - COUNT(*) FILTER (WHERE a.ActionType = 'SOFT_DELETE')
     + COUNT(*) FILTER (WHERE a.ActionType = 'REACTIVATE'))    AS NetHeadcountChange,
    COUNT(*)                                                   AS TotalEvents
FROM dbo.Peoplesoft_SHR010HRORG_Audit a
GROUP BY a.RunId
ORDER BY RunDtmUtc;
