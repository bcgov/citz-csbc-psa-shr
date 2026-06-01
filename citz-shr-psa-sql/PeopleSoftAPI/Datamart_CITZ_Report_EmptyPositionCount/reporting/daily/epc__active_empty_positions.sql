-- epc__active_empty_positions.sql
-- Active empty positions: all positions currently flagged as empty and active.

SELECT
    e.Position,
    e.PositionTitle,
    e.DeptId,
    e.DeptIdDesc,
    e.EmptyPosition,
    e.EmptyEffDt,
    e.YearsEmpty,
    e.PositionEmptyGt1Year,
    e.ClassificationGroup,
    e.JobCode,
    e.JobCodeDesc,
    e.Program,
    e.ProgramBranch,
    e.ProgramDivision,
    e.DevelopmentRegion,
    e.ProvincialQuadrant,
    e.City,
    e.Location,
    e.LastIncumbents,
    e.RegOrTempDescr,
    e.ExcludedOrIncluded,
    e.PosStatusDescr,
    e.ReportsTo
FROM dbo.Peoplesoft_EPC AS e
WHERE e.IsActive    = 1
  AND e.EmptyPosition = 'YES'
ORDER BY
    e.DeptIdDesc,
    e.YearsEmpty DESC;
