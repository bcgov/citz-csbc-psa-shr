-- vacancy_rate_by_noc.sql
-- Vacancy rate by National Occupational Classification (NOC) code.
-- Useful for workforce planning and supply/demand analysis by occupation.

SELECT
    e.NocCode,
    e.NocCodeDescr,
    COUNT(*)                                        AS TotalPositions,
    SUM(CASE WHEN e.EmptyPosition = 'YES' THEN 1 ELSE 0 END) AS EmptyCount,
    SUM(CASE WHEN e.PositionEmptyGt1Year = 'YES' THEN 1 ELSE 0 END)
                                                    AS LongTermVacancyCount,
    CAST(
        SUM(CASE WHEN e.EmptyPosition = 'YES' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,2))                                AS VacancyRatePct,
    AVG(CASE WHEN e.EmptyPosition = 'YES' THEN e.YearsEmpty END)
                                                    AS AvgYearsEmptyForVacant
FROM dbo.Peoplesoft_EPC AS e
WHERE e.IsActive = 1
  AND e.NocCode  IS NOT NULL
GROUP BY
    e.NocCode,
    e.NocCodeDescr
ORDER BY VacancyRatePct DESC, TotalPositions DESC;
