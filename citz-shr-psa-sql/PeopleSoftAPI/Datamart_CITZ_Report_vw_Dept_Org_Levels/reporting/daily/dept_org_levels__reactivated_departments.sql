DECLARE @RunId UNIQUEIDENTIFIER =
(
    SELECT TOP (1) RunId
    FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
    ORDER BY AuditDtmUtc DESC
);

SELECT
    DepartmentID,
    OldOrganization AS WasOrganization,
    NewOrganization AS NowOrganization,
    OldLevel1 AS WasLevel1, NewLevel1 AS NowLevel1,
    OldLevel2 AS WasLevel2, NewLevel2 AS NowLevel2,
    OldLevel3 AS WasLevel3, NewLevel3 AS NowLevel3,
    AuditDtmUtc
FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
WHERE RunId = @RunId
  AND ActionType = 'REACTIVATE'
ORDER BY DepartmentID;
