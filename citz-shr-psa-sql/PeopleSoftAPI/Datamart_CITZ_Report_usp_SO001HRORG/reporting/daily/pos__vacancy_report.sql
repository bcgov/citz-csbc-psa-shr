/*=============================================================================
File: pos__vacancy_report.sql
Purpose: Active positions that are currently vacant (no incumbent assigned).
Notes:
  - EmplId = '' identifies vacant positions (normalized in R before staging load).
  - Report excludes soft-deleted rows.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    PosPosition,
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
    LastFilled,
    TrueVacancy,
    LastUpdatedUtc
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
  AND EmplId = ''
ORDER BY Organization, Level1, Level2, PosPosition;
