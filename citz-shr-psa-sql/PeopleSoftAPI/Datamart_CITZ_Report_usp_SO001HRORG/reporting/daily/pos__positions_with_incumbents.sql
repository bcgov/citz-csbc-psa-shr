/*=============================================================================
File: pos__positions_with_incumbents.sql
Purpose: Active positions that have a named incumbent (filled positions).
Notes:
  - EmplId <> '' identifies filled positions.
  - Report excludes soft-deleted and vacant rows.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    PosPosition,
    EmplId,
    Name,
    Title,
    Organization,
    Level1,
    Level2,
    Level3,
    PosDepartment,
    PosDeptId,
    PosBusinessUnit,
    PosBU,
    PosRole,
    PosClassification,
    EmplBU,
    EmplDeptId,
    EmplJobCode,
    EmplClassification,
    EmplStatus,
    Appt,
    Grade,
    Step,
    SalaryType,
    SupervisorPos,
    SupervisorName,
    City,
    Status,
    LastUpdatedUtc
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
  AND EmplId <> ''
ORDER BY Organization, Level1, Level2, PosPosition;
