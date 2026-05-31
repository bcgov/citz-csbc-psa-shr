-- hc__headcount_trend.sql
-- Net headcount change per ETL run (Inserts - SoftDeletes + Reactivations).
-- Provides a time-series view of active workforce size movement.

SELECT
    CAST(MIN(a.AuditDtmUtc) AS DATE)                           AS RunDate,
    a.RunId,
    COUNT(*) FILTER (WHERE a.ActionType = 'INSERT')            AS Inserts,
    COUNT(*) FILTER (WHERE a.ActionType = 'SOFT_DELETE')       AS SoftDeletes,
    COUNT(*) FILTER (WHERE a.ActionType = 'REACTIVATE')        AS Reactivations,
    (COUNT(*) FILTER (WHERE a.ActionType = 'INSERT')
     - COUNT(*) FILTER (WHERE a.ActionType = 'SOFT_DELETE')
     + COUNT(*) FILTER (WHERE a.ActionType = 'REACTIVATE'))    AS NetChange,
    SUM(
        COUNT(*) FILTER (WHERE a.ActionType = 'INSERT')
        - COUNT(*) FILTER (WHERE a.ActionType = 'SOFT_DELETE')
        + COUNT(*) FILTER (WHERE a.ActionType = 'REACTIVATE')
    ) OVER (ORDER BY MIN(a.AuditDtmUtc) ROWS UNBOUNDED PRECEDING)
                                                               AS CumulativeNetChange
FROM dbo.Peoplesoft_SHR010HRORG_Audit a
GROUP BY a.RunId
ORDER BY RunDate;
