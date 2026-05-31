-- hc__headcount_summary.sql
-- Top-level active headcount summary broken out by key dimensions.
-- Suitable for daily briefing reports.

-- Total active headcount
SELECT
    COUNT(*)                        AS TotalActive
FROM dbo.Peoplesoft_SHR010HRORG
WHERE IsActive = 1;

-- By employment category
SELECT
    EmplCtg                         AS EmploymentCategory,
    COUNT(*)                        AS HeadCount
FROM dbo.Peoplesoft_SHR010HRORG
WHERE IsActive = 1
GROUP BY EmplCtg
ORDER BY HeadCount DESC;

-- By location city
SELECT
    ISNULL(LocationCity, '(Unknown)') AS LocationCity,
    COUNT(*)                           AS HeadCount
FROM dbo.Peoplesoft_SHR010HRORG
WHERE IsActive = 1
GROUP BY LocationCity
ORDER BY HeadCount DESC;

-- By appointment status
SELECT
    ISNULL(ApptStatus, '(Unknown)')    AS ApptStatus,
    COUNT(*)                           AS HeadCount
FROM dbo.Peoplesoft_SHR010HRORG
WHERE IsActive = 1
GROUP BY ApptStatus
ORDER BY HeadCount DESC;
