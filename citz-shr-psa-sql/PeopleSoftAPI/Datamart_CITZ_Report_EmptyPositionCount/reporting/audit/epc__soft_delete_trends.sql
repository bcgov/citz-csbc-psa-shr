-- epc__soft_delete_trends.sql
-- Soft-delete volume per run: positions that stopped being reported by the API.

SELECT
    a.RunId,
    MIN(a.AuditDtmUtc)                              AS RunDtmUtc,
    COUNT(*)                                        AS SoftDeleteCount
FROM dbo.Peoplesoft_EPC_Audit AS a
WHERE a.ActionType = 'SOFT_DELETE'
GROUP BY a.RunId
ORDER BY RunDtmUtc DESC;
