/*=============================================================================
Report: Active Organizations Breakdown
Purpose: Number of active departments per organization
=============================================================================*/

SELECT
    Organization,
    COUNT(*) AS ActiveDepartmentCount
FROM dbo.PeopleSoft_Dept_Org_Levels
WHERE IsActive = 1
GROUP BY Organization
ORDER BY ActiveDepartmentCount DESC;