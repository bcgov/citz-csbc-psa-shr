/*=============================================================================
File: pos__active_positions.sql
Purpose: All active position rows with key workforce fields.
Notes:
  - IsActive = 1 filters to current-state rows only.
  - EmplId = '' indicates a vacant position.
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
    SupervisorPos,
    SupervisorName,
    City,
    Status,
    IsActive,
    CreatedUtc,
    LastUpdatedUtc
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
ORDER BY Organization, Level1, Level2, PosPosition;
