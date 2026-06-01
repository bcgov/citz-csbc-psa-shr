-- epc__run_history.sql
-- One row per MERGE run: total changes, inserts, updates, soft deletes, reactivations.

SELECT
    a.RunId,
    MIN(a.AuditDtmUtc)                              AS RunDtmUtc,
    COUNT(*)                                        AS TotalChanges,
    SUM(CASE WHEN a.ActionType = 'INSERT'      THEN 1 ELSE 0 END) AS Inserts,
    SUM(CASE WHEN a.ActionType = 'UPDATE'      THEN 1 ELSE 0 END) AS Updates,
    SUM(CASE WHEN a.ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeletes,
    SUM(CASE WHEN a.ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END) AS Reactivations
FROM dbo.Peoplesoft_EPC_Audit AS a
GROUP BY a.RunId
ORDER BY RunDtmUtc DESC;
