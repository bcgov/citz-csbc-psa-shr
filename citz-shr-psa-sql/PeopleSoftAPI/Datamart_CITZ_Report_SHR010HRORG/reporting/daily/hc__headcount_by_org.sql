-- hc__headcount_by_org.sql
-- Active employee headcount rolled up through the organizational hierarchy.
-- Provides Level1 -> Level2 -> Department breakdown.

SELECT
    Level1,
    Level2,
    DeptId,
    DeptDescr,
    COUNT(*)                        AS HeadCount
FROM dbo.Peoplesoft_SHR010HRORG
WHERE IsActive = 1
GROUP BY
    Level1,
    Level2,
    DeptId,
    DeptDescr
ORDER BY
    Level1,
    Level2,
    DeptDescr;
