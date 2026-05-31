/*=============================================================================
File:    pos__reactivated_positions.sql
Purpose: Positions reactivated (IsActive 0 -> 1) in the latest ETL run.
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
    a.OldOrganization    AS WasOrganization,
    a.NewOrganization    AS NowOrganization,
    a.OldTitle           AS WasTitle,
    a.NewTitle           AS NowTitle,
    a.OldName            AS WasName,
    a.NewName            AS NowName,
    a.OldIsActive        AS WasActive,
    a.NewIsActive        AS NowActive,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_SO001HRORG_Audit a
JOIN latest_run lr ON a.RunId = lr.RunId
WHERE a.ActionType = 'REACTIVATE'
ORDER BY a.PosPosition;
