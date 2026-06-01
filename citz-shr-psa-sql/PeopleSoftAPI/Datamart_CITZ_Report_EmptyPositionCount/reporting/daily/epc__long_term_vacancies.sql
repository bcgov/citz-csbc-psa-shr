-- epc__long_term_vacancies.sql
-- Positions empty for more than one year (PositionEmptyGt1Year = 'YES').
-- Ordered by years vacant descending to surface the longest vacancies first.

SELECT
    e.Position,
    e.PositionTitle,
    e.DeptId,
    e.DeptIdDesc,
    e.EmptyEffDt,
    e.YearsEmpty,
    e.ClassificationGroup,
    e.JobCode,
    e.JobCodeDesc,
    e.Program,
    e.ProgramBranch,
    e.DevelopmentRegion,
    e.City,
    e.Location,
    e.LastIncumbents,
    e.JobReqStatus,
    e.JobReqOpenDate,
    e.ReportsTo,
    e.Supervisor
FROM dbo.Peoplesoft_EPC AS e
WHERE e.IsActive              = 1
  AND e.PositionEmptyGt1Year  = 'YES'
ORDER BY e.YearsEmpty DESC;
