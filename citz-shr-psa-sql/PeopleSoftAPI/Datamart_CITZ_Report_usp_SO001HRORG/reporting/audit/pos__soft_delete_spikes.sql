/*=============================================================================
File:    pos__soft_delete_spikes.sql
Purpose: Drill into SOFT_DELETE events on a specific date.
Usage:   Set @AuditDate to the spike date you want to investigate.
=============================================================================*/

SET NOCOUNT ON;

DECLARE @AuditDate date = CAST(SYSUTCDATETIME() AS date);  -- set to target spike date

SELECT
    PosPosition,
    EmplId,
    OldName          AS Name,
    OldTitle         AS Title,
    OldOrganization  AS Organization,
    OldLevel1        AS Level1,
    OldLevel2        AS Level2,
    OldLevel3        AS Level3,
    OldStatus        AS Status,
    ActionType,
    AuditDtmUtc,
    RunId
FROM dbo.Peoplesoft_SO001HRORG_Audit
WHERE ActionType = 'SOFT_DELETE'
  AND CAST(AuditDtmUtc AS date) = @AuditDate
ORDER BY AuditDtmUtc DESC, PosPosition;
