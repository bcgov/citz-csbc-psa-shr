/*=============================================================================
File:    pos__position_change_history.sql
Purpose: Full change history for a single PosPosition across all runs.
Usage:
  - Set @PosPosition to the position number you want to track.
  - Adjust @TopN as needed.
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

    -- Key change fields (before / after)
    OldOrganization,  NewOrganization,
    OldLevel1,        NewLevel1,
    OldLevel2,        NewLevel2,
    OldLevel3,        NewLevel3,
    OldTitle,         NewTitle,
    OldName,          NewName,
    OldStatus,        NewStatus,
    OldPosDepartment, NewPosDepartment,
    OldSupervisorPos, NewSupervisorPos,
    OldIsActive,      NewIsActive

FROM dbo.Peoplesoft_SO001HRORG_Audit
WHERE PosPosition = @PosPosition
ORDER BY AuditDtmUtc DESC;
