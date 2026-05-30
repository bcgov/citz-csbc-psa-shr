DECLARE @RunId UNIQUEIDENTIFIER =
(
    SELECT TOP (1) RunId
    FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
    ORDER BY AuditDtmUtc DESC
);

SELECT
    DepartmentID,
    NewOrganization,
    NewLevel1, NewLevel2, NewLevel3, NewLevel4, NewLevel5,
    AuditDtmUtc
FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
WHERE RunId = @RunId
  AND ActionType = 'INSERT'
ORDER BY DepartmentID;