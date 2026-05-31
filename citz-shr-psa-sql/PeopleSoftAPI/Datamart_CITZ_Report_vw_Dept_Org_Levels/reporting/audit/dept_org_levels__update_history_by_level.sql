/*=============================================================================
File: dept_org_levels__update_history_by_level.sql
Purpose:
  Show ALL update events across entire audit history.
  Only displays the level(s) that actually changed per row.
  Includes current Organization from target table for context.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.DepartmentID,
    t.Organization AS CurrentOrganization,

    CASE WHEN ISNULL(a.OldLevel1,'') <> ISNULL(a.NewLevel1,'')
         THEN CONCAT(ISNULL(a.OldLevel1,'<NULL>'), ' -> ', ISNULL(a.NewLevel1,'<NULL>'))
    END AS Level1_Change,

    CASE WHEN ISNULL(a.OldLevel1Key,-1) <> ISNULL(a.NewLevel1Key,-1)
         THEN CONCAT(ISNULL(CONVERT(varchar(20),a.OldLevel1Key),'<NULL>'), ' -> ', ISNULL(CONVERT(varchar(20),a.NewLevel1Key),'<NULL>'))
    END AS Level1Key_Change,

    CASE WHEN ISNULL(a.OldLevel2,'') <> ISNULL(a.NewLevel2,'')
         THEN CONCAT(ISNULL(a.OldLevel2,'<NULL>'), ' -> ', ISNULL(a.NewLevel2,'<NULL>'))
    END AS Level2_Change,

    CASE WHEN ISNULL(a.OldLevel2Key,-1) <> ISNULL(a.NewLevel2Key,-1)
         THEN CONCAT(ISNULL(CONVERT(varchar(20),a.OldLevel2Key),'<NULL>'), ' -> ', ISNULL(CONVERT(varchar(20),a.NewLevel2Key),'<NULL>'))
    END AS Level2Key_Change,

    CASE WHEN ISNULL(a.OldLevel3,'') <> ISNULL(a.NewLevel3,'')
         THEN CONCAT(ISNULL(a.OldLevel3,'<NULL>'), ' -> ', ISNULL(a.NewLevel3,'<NULL>'))
    END AS Level3_Change,

    CASE WHEN ISNULL(a.OldLevel3Key,-1) <> ISNULL(a.NewLevel3Key,-1)
         THEN CONCAT(ISNULL(CONVERT(varchar(20),a.OldLevel3Key),'<NULL>'), ' -> ', ISNULL(CONVERT(varchar(20),a.NewLevel3Key),'<NULL>'))
    END AS Level3Key_Change,

    CASE WHEN ISNULL(a.OldLevel4,'') <> ISNULL(a.NewLevel4,'')
         THEN CONCAT(ISNULL(a.OldLevel4,'<NULL>'), ' -> ', ISNULL(a.NewLevel4,'<NULL>'))
    END AS Level4_Change,

    CASE WHEN ISNULL(a.OldLevel4Key,-1) <> ISNULL(a.NewLevel4Key,-1)
         THEN CONCAT(ISNULL(CONVERT(varchar(20),a.OldLevel4Key),'<NULL>'), ' -> ', ISNULL(CONVERT(varchar(20),a.NewLevel4Key),'<NULL>'))
    END AS Level4Key_Change,

    CASE WHEN ISNULL(a.OldLevel5,'') <> ISNULL(a.NewLevel5,'')
         THEN CONCAT(ISNULL(a.OldLevel5,'<NULL>'), ' -> ', ISNULL(a.NewLevel5,'<NULL>'))
    END AS Level5_Change,

    CASE WHEN ISNULL(a.OldLevel5Key,-1) <> ISNULL(a.NewLevel5Key,-1)
         THEN CONCAT(ISNULL(CONVERT(varchar(20),a.OldLevel5Key),'<NULL>'), ' -> ', ISNULL(CONVERT(varchar(20),a.NewLevel5Key),'<NULL>'))
    END AS Level5Key_Change,

    CASE WHEN ISNULL(a.OldOrganization,'') <> ISNULL(a.NewOrganization,'')
         THEN CONCAT(ISNULL(a.OldOrganization,'<NULL>'), ' -> ', ISNULL(a.NewOrganization,'<NULL>'))
    END AS Organization_Change

FROM dbo.PeopleSoft_Dept_Org_Levels_Audit a
LEFT JOIN dbo.PeopleSoft_Dept_Org_Levels t
    ON t.DepartmentID = a.DepartmentID
WHERE a.ActionType = 'UPDATE'
  AND (
       ISNULL(a.OldLevel1,'')       <> ISNULL(a.NewLevel1,'')
    OR ISNULL(a.OldLevel1Key,-1)    <> ISNULL(a.NewLevel1Key,-1)
    OR ISNULL(a.OldLevel2,'')       <> ISNULL(a.NewLevel2,'')
    OR ISNULL(a.OldLevel2Key,-1)    <> ISNULL(a.NewLevel2Key,-1)
    OR ISNULL(a.OldLevel3,'')       <> ISNULL(a.NewLevel3,'')
    OR ISNULL(a.OldLevel3Key,-1)    <> ISNULL(a.NewLevel3Key,-1)
    OR ISNULL(a.OldLevel4,'')       <> ISNULL(a.NewLevel4,'')
    OR ISNULL(a.OldLevel4Key,-1)    <> ISNULL(a.NewLevel4Key,-1)
    OR ISNULL(a.OldLevel5,'')       <> ISNULL(a.NewLevel5,'')
    OR ISNULL(a.OldLevel5Key,-1)    <> ISNULL(a.NewLevel5Key,-1)
    OR ISNULL(a.OldOrganization,'') <> ISNULL(a.NewOrganization,'')
  )
ORDER BY a.AuditDtmUtc DESC, a.DepartmentID;