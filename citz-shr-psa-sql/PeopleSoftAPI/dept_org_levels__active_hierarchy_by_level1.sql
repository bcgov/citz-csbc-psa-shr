/*=============================================================================
Report: Active Organizations by Level1
=============================================================================*/

SELECT
	Organization,
    Level1,
    COUNT(DISTINCT Organization) AS OrganizationCount,
    COUNT(*) AS DepartmentCount
FROM dbo.PeopleSoft_Dept_Org_Levels
WHERE IsActive = 1
GROUP BY Organization, Level1
ORDER BY DepartmentCount DESC;