-- tip__run_history.sql
-- One row per MERGE run with summary action counts.
SET NOCOUNT ON;

SELECT
    a.RunId,
    MIN(a.AuditDtmUtc)                                             AS RunDtmUtc,
    SUM(CASE WHEN a.ActionType = 'INSERT'      THEN 1 ELSE 0 END) AS Inserted,
    SUM(CASE WHEN a.ActionType = 'UPDATE'      THEN 1 ELSE 0 END) AS Updated,
    SUM(CASE WHEN a.ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeleted,
    SUM(CASE WHEN a.ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END) AS Reactivated,
    COUNT(*)                                                        AS TotalChanges
FROM dbo.Peoplesoft_TIP_Audit a
GROUP BY a.RunId
ORDER BY RunDtmUtc DESC;
