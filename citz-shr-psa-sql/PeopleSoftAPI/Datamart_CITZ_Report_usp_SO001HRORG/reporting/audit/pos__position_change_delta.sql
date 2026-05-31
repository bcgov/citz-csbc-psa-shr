/*=============================================================================
File:    pos__position_change_delta.sql
Purpose: Delta-only view for a specific PosPosition — only events where
         key attributes actually changed.
Usage:   Set @PosPosition to the position to investigate.
=============================================================================*/

SET NOCOUNT ON;

DECLARE @PosPosition NVARCHAR(20) = '00000001';  -- <-- change this
DECLARE @TopN        INT          = 200;

SELECT TOP (@TopN)
    AuditDtmUtc,
    RunId,
    ActionType,
    PosPosition,
    EmplId,

    CASE WHEN ISNULL(OldOrganization,'') <> ISNULL(NewOrganization,'')
         THEN CONCAT(ISNULL(OldOrganization,'<NULL>'), ' -> ', ISNULL(NewOrganization,'<NULL>'))
    END AS Organization_Change,

    CASE WHEN ISNULL(OldLevel1,'') <> ISNULL(NewLevel1,'')
         THEN CONCAT(ISNULL(OldLevel1,'<NULL>'), ' -> ', ISNULL(NewLevel1,'<NULL>'))
    END AS Level1_Change,

    CASE WHEN ISNULL(OldLevel2,'') <> ISNULL(NewLevel2,'')
         THEN CONCAT(ISNULL(OldLevel2,'<NULL>'), ' -> ', ISNULL(NewLevel2,'<NULL>'))
    END AS Level2_Change,

    CASE WHEN ISNULL(OldLevel3,'') <> ISNULL(NewLevel3,'')
         THEN CONCAT(ISNULL(OldLevel3,'<NULL>'), ' -> ', ISNULL(NewLevel3,'<NULL>'))
    END AS Level3_Change,

    CASE WHEN ISNULL(OldTitle,'') <> ISNULL(NewTitle,'')
         THEN CONCAT(ISNULL(OldTitle,'<NULL>'), ' -> ', ISNULL(NewTitle,'<NULL>'))
    END AS Title_Change,

    CASE WHEN ISNULL(OldName,'') <> ISNULL(NewName,'')
         THEN CONCAT(ISNULL(OldName,'<NULL>'), ' -> ', ISNULL(NewName,'<NULL>'))
    END AS Name_Change,

    CASE WHEN ISNULL(OldStatus,'') <> ISNULL(NewStatus,'')
         THEN CONCAT(ISNULL(OldStatus,'<NULL>'), ' -> ', ISNULL(NewStatus,'<NULL>'))
    END AS Status_Change,

    CONCAT(
        COALESCE(CONVERT(varchar(1), OldIsActive), '<NULL>'),
        ' -> ',
        COALESCE(CONVERT(varchar(1), NewIsActive), '<NULL>')
    ) AS IsActive_Change

FROM dbo.Peoplesoft_SO001HRORG_Audit
WHERE PosPosition = @PosPosition
  AND (
       ISNULL(OldOrganization,'') <> ISNULL(NewOrganization,'')
    OR ISNULL(OldLevel1,'')       <> ISNULL(NewLevel1,'')
    OR ISNULL(OldLevel2,'')       <> ISNULL(NewLevel2,'')
    OR ISNULL(OldLevel3,'')       <> ISNULL(NewLevel3,'')
    OR ISNULL(OldTitle,'')        <> ISNULL(NewTitle,'')
    OR ISNULL(OldName,'')         <> ISNULL(NewName,'')
    OR ISNULL(OldStatus,'')       <> ISNULL(NewStatus,'')
    OR ISNULL(OldIsActive, 0)     <> ISNULL(NewIsActive, 0)
  )
ORDER BY AuditDtmUtc DESC;
