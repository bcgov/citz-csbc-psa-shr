/*=============================================================================
File:    pos__position_movement.sql
Purpose: Positions that changed Organization or Level hierarchy in the latest run.
         Use to detect workforce restructuring events.
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
    a.OldLevel1          AS WasLevel1,
    a.NewLevel1          AS NowLevel1,
    a.OldLevel2          AS WasLevel2,
    a.NewLevel2          AS NowLevel2,
    a.OldLevel3          AS WasLevel3,
    a.NewLevel3          AS NowLevel3,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_SO001HRORG_Audit a
JOIN latest_run lr ON a.RunId = lr.RunId
WHERE a.ActionType IN ('UPDATE', 'REACTIVATE')
  AND (
       ISNULL(a.OldOrganization,'') <> ISNULL(a.NewOrganization,'')
    OR ISNULL(a.OldLevel1,'') <> ISNULL(a.NewLevel1,'')
    OR ISNULL(a.OldLevel2,'') <> ISNULL(a.NewLevel2,'')
    OR ISNULL(a.OldLevel3,'') <> ISNULL(a.NewLevel3,'')
  )
ORDER BY a.AuditDtmUtc DESC, a.PosPosition;
