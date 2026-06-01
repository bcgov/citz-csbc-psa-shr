-- epc__empty_by_program.sql
-- Empty position count by program, branch, and division.

SELECT
    e.Program,
    e.ProgramBranch,
    e.ProgramDivision,
    COUNT(*)                                        AS TotalPositions,
    SUM(CASE WHEN e.EmptyPosition = 'YES' THEN 1 ELSE 0 END) AS EmptyCount,
    CAST(
        SUM(CASE WHEN e.EmptyPosition = 'YES' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,2))                                AS EmptyPct
FROM dbo.Peoplesoft_EPC AS e
WHERE e.IsActive = 1
GROUP BY
    e.Program,
    e.ProgramBranch,
    e.ProgramDivision
ORDER BY
    e.Program,
    e.ProgramBranch,
    EmptyCount DESC;
