-- hc__reactivation_trends.sql
-- Reactivation counts by run date.
-- Use to track employees returning after a soft-delete (e.g., return from leave).

SELECT
    CAST(MIN(a.AuditDtmUtc) AS DATE)   AS RunDate,
    a.RunId,
    COUNT(*)                           AS ReactivationCount
FROM dbo.Peoplesoft_SHR010HRORG_Audit a
WHERE a.ActionType = 'REACTIVATE'
GROUP BY a.RunId
ORDER BY RunDate DESC;
