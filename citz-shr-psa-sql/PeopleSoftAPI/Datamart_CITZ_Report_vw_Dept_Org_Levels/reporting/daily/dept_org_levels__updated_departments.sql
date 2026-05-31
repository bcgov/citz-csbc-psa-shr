DECLARE @RunId UNIQUEIDENTIFIER =
(
    SELECT TOP (1) RunId
    FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
    ORDER BY AuditDtmUtc DESC
);

SELECT
    DepartmentID,
    AuditDtmUtc,

    CASE WHEN ISNULL(OldOrganization,'') <> ISNULL(NewOrganization,'')
         THEN CONCAT(ISNULL(OldOrganization,'<NULL>'), ' -> ', ISNULL(NewOrganization,'<NULL>')) END AS Organization_Change,

    CASE WHEN ISNULL(OldLevel1,'') <> ISNULL(NewLevel1,'')
         THEN CONCAT(ISNULL(OldLevel1,'<NULL>'), ' -> ', ISNULL(NewLevel1,'<NULL>')) END AS Level1_Change,

    CASE WHEN ISNULL(OldLevel2,'') <> ISNULL(NewLevel2,'')
         THEN CONCAT(ISNULL(OldLevel2,'<NULL>'), ' -> ', ISNULL(NewLevel2,'<NULL>')) END AS Level2_Change,

    CASE WHEN ISNULL(OldLevel3,'') <> ISNULL(NewLevel3,'')
         THEN CONCAT(ISNULL(OldLevel3,'<NULL>'), ' -> ', ISNULL(NewLevel3,'<NULL>')) END AS Level3_Change,

    CASE WHEN ISNULL(OldLevel4,'') <> ISNULL(NewLevel4,'')
         THEN CONCAT(ISNULL(OldLevel4,'<NULL>'), ' -> ', ISNULL(NewLevel4,'<NULL>')) END AS Level4_Change,

    CASE WHEN ISNULL(OldLevel5,'') <> ISNULL(NewLevel5,'')
         THEN CONCAT(ISNULL(OldLevel5,'<NULL>'), ' -> ', ISNULL(NewLevel5,'<NULL>')) END AS Level5_Change

FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
WHERE RunId = @RunId
  AND ActionType = 'UPDATE'
  AND (
         ISNULL(OldOrganization,'') <> ISNULL(NewOrganization,'')
      OR ISNULL(OldLevel1,'') <> ISNULL(NewLevel1,'')
      OR ISNULL(OldLevel2,'') <> ISNULL(NewLevel2,'')
      OR ISNULL(OldLevel3,'') <> ISNULL(NewLevel3,'')
      OR ISNULL(OldLevel4,'') <> ISNULL(NewLevel4,'')
      OR ISNULL(OldLevel5,'') <> ISNULL(NewLevel5,'')
  )
ORDER BY AuditDtmUtc DESC, DepartmentID;