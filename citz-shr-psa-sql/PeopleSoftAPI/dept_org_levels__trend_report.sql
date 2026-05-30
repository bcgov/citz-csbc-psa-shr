SELECT TOP (30)
    RunId,
    MIN(AuditDtmUtc) AS RunStartUtc,
    SUM(CASE WHEN ActionType='INSERT' THEN 1 ELSE 0 END) AS Inserts,
    SUM(CASE WHEN ActionType='UPDATE' THEN 1 ELSE 0 END) AS Updates,
    SUM(CASE WHEN ActionType='SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeletes,
    SUM(CASE WHEN ActionType='REACTIVATE' THEN 1 ELSE 0 END) AS Reactivations,
    COUNT(*) AS TotalEvents
FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
GROUP BY RunId
ORDER BY RunStartUtc DESC;