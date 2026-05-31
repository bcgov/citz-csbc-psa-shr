/*=============================================================================
File:    pos__updated_positions.sql
Purpose: Positions updated in the latest ETL run with delta view of key fields.
=============================================================================*/

SET NOCOUNT ON;

DECLARE @RunId UNIQUEIDENTIFIER =
(
    SELECT TOP (1) RunId
    FROM dbo.Peoplesoft_SO001HRORG_Audit
    ORDER BY AuditDtmUtc DESC
);

SELECT
    PosPosition,
    EmplId,
    AuditDtmUtc,

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
    END AS Status_Change

FROM dbo.Peoplesoft_SO001HRORG_Audit
WHERE RunId = @RunId
  AND ActionType = 'UPDATE'
ORDER BY AuditDtmUtc DESC, PosPosition;
