/*=============================================================================
File: dept_org_levels__department_change_history.sql
Purpose: Full change history for one DepartmentID across runs.
Usage:
  - Set @DepartmentID to the dept you want.
  - Optional: limit to recent N events.
=============================================================================*/

SET NOCOUNT ON;

DECLARE @DepartmentID VARCHAR(20) = '034-5038';  -- <-- change this
DECLARE @TopN INT = 200;                         -- <-- adjust as needed

SELECT TOP (@TopN)
    AuditDtmUtc,
    RunId,
    ActionType,
    DepartmentID,

    -- Focus fields (before/after)
    OldOrganization, NewOrganization,
    OldLevel1, NewLevel1,
    OldLevel2, NewLevel2,
    OldLevel3, NewLevel3,
    OldLevel4, NewLevel4,
    OldLevel5, NewLevel5,

    OldIsActive, NewIsActive
FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
WHERE DepartmentID = @DepartmentID
ORDER BY AuditDtmUtc DESC;