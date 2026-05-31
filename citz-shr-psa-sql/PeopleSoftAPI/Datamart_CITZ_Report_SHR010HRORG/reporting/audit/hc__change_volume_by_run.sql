-- hc__change_volume_by_run.sql
-- Total event counts per ETL run, ordered most recent first.
-- Use to monitor pipeline activity and detect anomalous change volumes.

SELECT
    a.RunId,
    CAST(MIN(a.AuditDtmUtc) AS DATE)                       AS RunDate,
    MIN(a.AuditDtmUtc)                                     AS RunDtmUtc,
    COUNT(*) FILTER (WHERE a.ActionType = 'INSERT')        AS Inserts,
    COUNT(*) FILTER (WHERE a.ActionType = 'UPDATE')        AS Updates,
    COUNT(*) FILTER (WHERE a.ActionType = 'SOFT_DELETE')   AS SoftDeletes,
    COUNT(*) FILTER (WHERE a.ActionType = 'REACTIVATE')    AS Reactivations,
    COUNT(*)                                               AS TotalEvents
FROM dbo.Peoplesoft_SHR010HRORG_Audit a
GROUP BY a.RunId
ORDER BY RunDtmUtc DESC;
