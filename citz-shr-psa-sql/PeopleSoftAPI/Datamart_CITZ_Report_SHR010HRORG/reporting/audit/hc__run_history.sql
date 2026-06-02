-- hc__run_history.sql
-- All ETL runs with summary metrics and net headcount change.
-- Use to review pipeline history and track workforce size over time.

SELECT
    a.RunId,
    CAST(MIN(a.AuditDtmUtc) AS DATE)                           AS RunDate,
    MIN(a.AuditDtmUtc)                                         AS RunDtmUtc,

    SUM(CASE WHEN a.ActionType = 'INSERT'      THEN 1 ELSE 0 END) AS Inserts,
    SUM(CASE WHEN a.ActionType = 'UPDATE'      THEN 1 ELSE 0 END) AS Updates,
    SUM(CASE WHEN a.ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeletes,
    SUM(CASE WHEN a.ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END) AS Reactivations,

    (
        SUM(CASE WHEN a.ActionType = 'INSERT'      THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END)
      + SUM(CASE WHEN a.ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END)
    ) AS NetHeadcountChange,

    COUNT(*) AS TotalEvents

FROM dbo.Peoplesoft_SHR010HRORG_Audit a
GROUP BY a.RunId
ORDER BY RunDtmUtc;