/*=============================================================================
File:    pos__updated_positions.sql
Purpose: Positions updated in the latest ETL run with delta view of key fields.
=============================================================================*/

SET NOCOUNT ON;

;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SO001HRORG_Audit
)
SELECT
    a.PosPosition,
    a.EmplId,
    a.AuditDtmUtc,

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
    END AS Status_Change

FROM dbo.Peoplesoft_SO001HRORG_Audit a
JOIN latest_run lr ON a.RunId = lr.RunId
WHERE a.ActionType = 'UPDATE'
ORDER BY a.AuditDtmUtc DESC, a.PosPosition;
