-- hc__headcount_by_classification.sql
-- Active employee headcount grouped by salary plan, grade, and step.
-- Use for compensation band analysis and classification reporting.

SELECT
    SalAdminPlan                    AS SalaryPlan,
    Grade,
    Step,
    COUNT(*)                        AS HeadCount,
    AVG(AnnualRt)                   AS AvgAnnualRate,
    MIN(AnnualRt)                   AS MinAnnualRate,
    MAX(AnnualRt)                   AS MaxAnnualRate
FROM dbo.Peoplesoft_SHR010HRORG
WHERE IsActive = 1
GROUP BY
    SalAdminPlan,
    Grade,
    Step
ORDER BY
    SalAdminPlan,
    Grade,
    Step;
