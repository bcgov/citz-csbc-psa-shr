/*=============================================================================
File:    pos__soft_deleted_positions.sql
Purpose: Positions soft-deleted (IsActive 1 -> 0) in the latest ETL run.
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
    a.OldName            AS Name,
    a.OldTitle           AS Title,
    a.OldOrganization    AS Organization,
    a.OldLevel1          AS Level1,
    a.OldLevel2          AS Level2,
    a.OldLevel3          AS Level3,
    a.OldPosDepartment   AS PosDepartment,
    a.OldStatus          AS Status,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_SO001HRORG_Audit a
JOIN latest_run lr ON a.RunId = lr.RunId
WHERE a.ActionType = 'SOFT_DELETE'
ORDER BY a.PosPosition;
