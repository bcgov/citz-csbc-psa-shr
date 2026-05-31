/*=============================================================================
File:    pos__employee_change_history.sql
Purpose: Full change history for a single EmplId across all runs.
Usage:
  - Set @EmplId to the employee ID you want to track.
  - Adjust @TopN as needed.
=============================================================================*/

SET NOCOUNT ON;

DECLARE @EmplId NVARCHAR(20) = '12345678';  -- <-- change this
DECLARE @TopN   INT          = 200;

SELECT TOP (@TopN)
    AuditDtmUtc,
    RunId,
    ActionType,
    PosPosition,
    EmplId,

    -- Key change fields (before / after)
    OldOrganization, NewOrganization,
    OldLevel1,       NewLevel1,
    OldLevel2,       NewLevel2,
    OldLevel3,       NewLevel3,
    OldTitle,        NewTitle,
    OldName,         NewName,
    OldStatus,       NewStatus,
    OldPosDepartment, NewPosDepartment,
    OldGrade,        NewGrade,
    OldEmplStatus,   NewEmplStatus,
    OldIsActive,     NewIsActive

FROM dbo.Peoplesoft_SO001HRORG_Audit
WHERE EmplId = @EmplId
ORDER BY AuditDtmUtc DESC;
