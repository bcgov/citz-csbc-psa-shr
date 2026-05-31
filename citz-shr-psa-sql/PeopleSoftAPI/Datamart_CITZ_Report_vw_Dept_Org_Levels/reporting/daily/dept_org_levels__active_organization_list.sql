/*=============================================================================
Report: Active Organizations List
=============================================================================*/

SELECT DISTINCT
    Organization
FROM dbo.PeopleSoft_Dept_Org_Levels
WHERE IsActive = 1
ORDER BY Organization;