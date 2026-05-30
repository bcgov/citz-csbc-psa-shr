/*=============================================================================
Report: Active Organizations Count
Purpose: Count distinct active organizations in target table
=============================================================================*/

SELECT
    COUNT(DISTINCT Organization) AS ActiveOrganizationCount
FROM dbo.PeopleSoft_Dept_Org_Levels
WHERE IsActive = 1;