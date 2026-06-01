-- epc__empty_by_classification.sql
-- Empty position count by classification group.

SELECT
    e.ClassificationGroup,
    e.JobCode,
    e.JobCodeDesc,
    COUNT(*)                                        AS TotalPositions,
    SUM(CASE WHEN e.EmptyPosition = 'YES' THEN 1 ELSE 0 END) AS EmptyCount,
    CAST(
        SUM(CASE WHEN e.EmptyPosition = 'YES' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,2))                                AS EmptyPct
FROM dbo.Peoplesoft_EPC AS e
WHERE e.IsActive = 1
GROUP BY
    e.ClassificationGroup,
    e.JobCode,
    e.JobCodeDesc
ORDER BY
    e.ClassificationGroup,
    EmptyCount DESC;
