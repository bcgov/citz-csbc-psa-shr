-- epc__newly_empty_positions.sql
-- Positions that became active (IsActive toggled from 0 to 1) in the most
-- recent MERGE run (REACTIVATE action), or positions first seen as empty.
-- Use the audit table for new empty positions that appeared this run.

SELECT
    a.Position,
    e.PositionTitle,
    e.DeptId,
    e.DeptIdDesc,
    a.AuditDtmUtc                                  AS DetectedUtc,
    a.ActionType,
    e.EmptyPosition,
    e.EmptyEffDt,
    e.YearsEmpty,
    e.ClassificationGroup,
    e.JobCode,
    e.Program,
    e.DevelopmentRegion,
    e.City
FROM dbo.Peoplesoft_EPC_Audit AS a
JOIN dbo.Peoplesoft_EPC       AS e ON e.Position = a.Position
WHERE a.RunId = (
    SELECT TOP 1 RunId
    FROM dbo.Peoplesoft_EPC_Audit
    ORDER BY AuditDtmUtc DESC
)
  AND a.ActionType IN ('INSERT', 'REACTIVATE')
ORDER BY a.AuditDtmUtc DESC;
