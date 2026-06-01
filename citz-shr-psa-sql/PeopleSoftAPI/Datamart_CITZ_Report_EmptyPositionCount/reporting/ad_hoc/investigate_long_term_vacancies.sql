-- investigate_long_term_vacancies.sql
-- Deep dive on positions empty for more than 1 year: grouped by department
-- and classification for SHR workforce planning analysis.

SELECT
    e.DeptId,
    e.DeptIdDesc,
    e.ClassificationGroup,
    e.JobCode,
    e.JobCodeDesc,
    COUNT(*)                                        AS LongTermVacancyCount,
    AVG(e.YearsEmpty)                               AS AvgYearsEmpty,
    MAX(e.YearsEmpty)                               AS MaxYearsEmpty,
    MIN(e.EmptyEffDt)                               AS EarliestEmptyDate,
    SUM(CASE WHEN e.JobReqStatus IS NOT NULL THEN 1 ELSE 0 END)
                                                    AS WithOpenJobReq
FROM dbo.Peoplesoft_EPC AS e
WHERE e.IsActive             = 1
  AND e.PositionEmptyGt1Year = 'YES'
GROUP BY
    e.DeptId,
    e.DeptIdDesc,
    e.ClassificationGroup,
    e.JobCode,
    e.JobCodeDesc
ORDER BY LongTermVacancyCount DESC, e.DeptIdDesc;
