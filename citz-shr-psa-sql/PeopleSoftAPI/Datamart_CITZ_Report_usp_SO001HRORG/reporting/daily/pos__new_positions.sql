/*=============================================================================
File:    pos__new_positions.sql
Purpose: Positions inserted during the latest ETL run.
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
    a.NewName            AS Name,
    a.NewTitle           AS Title,
    a.NewOrganization    AS Organization,
    a.NewLevel1          AS Level1,
    a.NewLevel2          AS Level2,
    a.NewLevel3          AS Level3,
    a.NewPosDepartment   AS PosDepartment,
    a.NewStatus          AS Status,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_SO001HRORG_Audit a
JOIN latest_run lr ON a.RunId = lr.RunId
WHERE a.ActionType = 'INSERT'
ORDER BY a.PosPosition;
