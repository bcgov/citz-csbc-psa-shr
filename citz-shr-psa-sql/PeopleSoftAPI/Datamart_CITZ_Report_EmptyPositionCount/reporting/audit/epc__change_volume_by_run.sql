-- epc__change_volume_by_run.sql
-- Change volume trend across all MERGE runs.

SELECT
    a.RunId,
    MIN(a.AuditDtmUtc)                              AS RunDtmUtc,
    SUM(CASE WHEN a.ActionType = 'INSERT'      THEN 1 ELSE 0 END) AS Inserts,
    SUM(CASE WHEN a.ActionType = 'UPDATE'      THEN 1 ELSE 0 END) AS Updates,
    SUM(CASE WHEN a.ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeletes,
    SUM(CASE WHEN a.ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END) AS Reactivations,
    COUNT(*)                                        AS TotalChanges
FROM dbo.Peoplesoft_EPC_Audit AS a
GROUP BY a.RunId
ORDER BY RunDtmUtc DESC;
