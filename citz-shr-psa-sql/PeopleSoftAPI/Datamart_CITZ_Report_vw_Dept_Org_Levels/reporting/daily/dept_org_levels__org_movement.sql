DECLARE @RunId UNIQUEIDENTIFIER =
(
    SELECT TOP (1) RunId
    FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
    ORDER BY AuditDtmUtc DESC
);

SELECT
    DepartmentID,
    OldOrganization, NewOrganization,
    OldLevel1, NewLevel1,
    OldLevel2, NewLevel2,
    OldLevel3, NewLevel3,
    AuditDtmUtc
FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
WHERE RunId = @RunId
  AND ActionType IN ('UPDATE','REACTIVATE')
  AND (
       ISNULL(OldOrganization,'') <> ISNULL(NewOrganization,'')
    OR ISNULL(OldLevel1,'') <> ISNULL(NewLevel1,'')
    OR ISNULL(OldLevel2,'') <> ISNULL(NewLevel2,'')
    OR ISNULL(OldLevel3,'') <> ISNULL(NewLevel3,'')
  )
ORDER BY AuditDtmUtc DESC, DepartmentID;
