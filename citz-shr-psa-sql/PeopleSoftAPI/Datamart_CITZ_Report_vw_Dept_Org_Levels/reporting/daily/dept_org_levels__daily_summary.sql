DECLARE @RunId UNIQUEIDENTIFIER =
(
    SELECT TOP (1) RunId
    FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
    ORDER BY AuditDtmUtc DESC
);

SELECT
	AuditDtmUtc,
    ActionType,
    COUNT(*) AS ChangeCount
FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
WHERE RunId = @RunId
GROUP BY ActionType, AuditDtmUtc
ORDER BY ChangeCount DESC;