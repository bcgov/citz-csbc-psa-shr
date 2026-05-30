DECLARE @RunId UNIQUEIDENTIFIER =
(
    SELECT TOP (1) RunId
    FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
    ORDER BY AuditDtmUtc DESC
);

SELECT
    DepartmentID,
    OldOrganization,
    OldLevel1, OldLevel2, OldLevel3, OldLevel4, OldLevel5,
    AuditDtmUtc
FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
WHERE RunId = @RunId
  AND ActionType = 'SOFT_DELETE'
ORDER BY DepartmentID;