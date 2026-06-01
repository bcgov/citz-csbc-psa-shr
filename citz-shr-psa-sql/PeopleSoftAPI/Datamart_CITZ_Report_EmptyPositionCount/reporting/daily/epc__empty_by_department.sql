-- epc__empty_by_department.sql
-- Empty position count by department, sorted by most vacancies first.

SELECT
    e.DeptId,
    e.DeptIdDesc,
    COUNT(*)                                        AS TotalPositions,
    SUM(CASE WHEN e.EmptyPosition = 'YES' THEN 1 ELSE 0 END) AS EmptyCount,
    SUM(CASE WHEN e.EmptyPosition = 'NO'  THEN 1 ELSE 0 END) AS FilledCount,
    CAST(
        SUM(CASE WHEN e.EmptyPosition = 'YES' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,2))                                AS EmptyPct
FROM dbo.Peoplesoft_EPC AS e
WHERE e.IsActive = 1
GROUP BY
    e.DeptId,
    e.DeptIdDesc
ORDER BY EmptyCount DESC, e.DeptIdDesc;
