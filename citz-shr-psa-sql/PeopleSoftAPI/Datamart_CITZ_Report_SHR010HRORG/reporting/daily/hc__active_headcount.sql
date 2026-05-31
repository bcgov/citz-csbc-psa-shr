-- hc__active_headcount.sql
-- Active employee headcount by employment category and status.
-- Use for operational dashboards showing current workforce composition.

SELECT
    EmplCtg                         AS EmploymentCategory,
    EmplCtgL1                       AS EmploymentCategoryL1,
    EmplStatus                      AS EmploymentStatus,
    EmplType                        AS EmploymentType,
    COUNT(*)                        AS HeadCount
FROM dbo.Peoplesoft_SHR010HRORG
WHERE IsActive = 1
GROUP BY
    EmplCtg,
    EmplCtgL1,
    EmplStatus,
    EmplType
ORDER BY
    EmplCtg,
    EmplCtgL1,
    EmplStatus,
    EmplType;
