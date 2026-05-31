/*=============================================================================
File:    pos__update_history.sql
Purpose: All UPDATE audit events — shows which fields actually changed per row.
         Only the columns that differ are populated in the _Change aliases.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.PosPosition,
    a.EmplId,
    t.Organization                       AS CurrentOrganization,

    CASE WHEN ISNULL(a.OldOrganization,'') <> ISNULL(a.NewOrganization,'')
         THEN CONCAT(ISNULL(a.OldOrganization,'<NULL>'), ' -> ', ISNULL(a.NewOrganization,'<NULL>'))
    END AS Organization_Change,

    CASE WHEN ISNULL(a.OldLevel1,'') <> ISNULL(a.NewLevel1,'')
         THEN CONCAT(ISNULL(a.OldLevel1,'<NULL>'), ' -> ', ISNULL(a.NewLevel1,'<NULL>'))
    END AS Level1_Change,

    CASE WHEN ISNULL(a.OldLevel2,'') <> ISNULL(a.NewLevel2,'')
         THEN CONCAT(ISNULL(a.OldLevel2,'<NULL>'), ' -> ', ISNULL(a.NewLevel2,'<NULL>'))
    END AS Level2_Change,

    CASE WHEN ISNULL(a.OldLevel3,'') <> ISNULL(a.NewLevel3,'')
         THEN CONCAT(ISNULL(a.OldLevel3,'<NULL>'), ' -> ', ISNULL(a.NewLevel3,'<NULL>'))
    END AS Level3_Change,

    CASE WHEN ISNULL(a.OldTitle,'') <> ISNULL(a.NewTitle,'')
         THEN CONCAT(ISNULL(a.OldTitle,'<NULL>'), ' -> ', ISNULL(a.NewTitle,'<NULL>'))
    END AS Title_Change,

    CASE WHEN ISNULL(a.OldName,'') <> ISNULL(a.NewName,'')
         THEN CONCAT(ISNULL(a.OldName,'<NULL>'), ' -> ', ISNULL(a.NewName,'<NULL>'))
    END AS Name_Change,

    CASE WHEN ISNULL(a.OldStatus,'') <> ISNULL(a.NewStatus,'')
         THEN CONCAT(ISNULL(a.OldStatus,'<NULL>'), ' -> ', ISNULL(a.NewStatus,'<NULL>'))
    END AS Status_Change,

    CASE WHEN ISNULL(a.OldPosDepartment,'') <> ISNULL(a.NewPosDepartment,'')
         THEN CONCAT(ISNULL(a.OldPosDepartment,'<NULL>'), ' -> ', ISNULL(a.NewPosDepartment,'<NULL>'))
    END AS PosDepartment_Change,

    CASE WHEN ISNULL(a.OldSupervisorPos,'') <> ISNULL(a.NewSupervisorPos,'')
         THEN CONCAT(ISNULL(a.OldSupervisorPos,'<NULL>'), ' -> ', ISNULL(a.NewSupervisorPos,'<NULL>'))
    END AS SupervisorPos_Change

FROM dbo.Peoplesoft_SO001HRORG_Audit a
LEFT JOIN dbo.Peoplesoft_SO001HRORG t
    ON  t.PosPosition = a.PosPosition
    AND t.EmplId      = a.EmplId
WHERE a.ActionType = 'UPDATE'
  AND (
       ISNULL(a.OldOrganization,'')  <> ISNULL(a.NewOrganization,'')
    OR ISNULL(a.OldLevel1,'')        <> ISNULL(a.NewLevel1,'')
    OR ISNULL(a.OldLevel2,'')        <> ISNULL(a.NewLevel2,'')
    OR ISNULL(a.OldLevel3,'')        <> ISNULL(a.NewLevel3,'')
    OR ISNULL(a.OldTitle,'')         <> ISNULL(a.NewTitle,'')
    OR ISNULL(a.OldName,'')          <> ISNULL(a.NewName,'')
    OR ISNULL(a.OldStatus,'')        <> ISNULL(a.NewStatus,'')
    OR ISNULL(a.OldPosDepartment,'') <> ISNULL(a.NewPosDepartment,'')
    OR ISNULL(a.OldSupervisorPos,'') <> ISNULL(a.NewSupervisorPos,'')
  )
ORDER BY a.AuditDtmUtc DESC, a.PosPosition;
