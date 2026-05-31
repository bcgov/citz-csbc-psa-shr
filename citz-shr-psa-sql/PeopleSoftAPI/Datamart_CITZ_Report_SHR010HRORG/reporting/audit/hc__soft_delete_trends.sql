-- hc__soft_delete_trends.sql
-- Soft-delete counts by run date.
-- Use to detect unusual attrition spikes or API feed truncation events.

SELECT
    CAST(MIN(a.AuditDtmUtc) AS DATE)   AS RunDate,
    a.RunId,
    COUNT(*)                           AS SoftDeleteCount
FROM dbo.Peoplesoft_SHR010HRORG_Audit a
WHERE a.ActionType = 'SOFT_DELETE'
GROUP BY a.RunId
ORDER BY RunDate DESC;
