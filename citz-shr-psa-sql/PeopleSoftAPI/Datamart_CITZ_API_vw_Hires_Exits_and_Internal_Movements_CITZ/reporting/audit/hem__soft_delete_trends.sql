-- hem__soft_delete_trends.sql
-- Daily soft-delete counts over time; spikes may indicate API feed issues.
SET NOCOUNT ON;

SELECT
    CAST(a.AuditDtmUtc AS DATE)                                       AS AuditDate,
    a.RunId,
    SUM(CASE WHEN a.ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END)    AS SoftDeletes,
    SUM(CASE WHEN a.ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END)    AS Reactivations,
    COUNT(*)                                                           AS TotalChanges
FROM dbo.Peoplesoft_HEM_Audit a
GROUP BY CAST(a.AuditDtmUtc AS DATE), a.RunId
ORDER BY AuditDate DESC;
