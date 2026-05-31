/*=============================================================================
Report: Organizations Data Quality Check
=============================================================================*/

SELECT
    CASE 
        WHEN Organization IS NULL OR LTRIM(RTRIM(Organization)) = '' 
        THEN 'Missing Organization'
        ELSE 'Valid Organization'
    END AS OrganizationStatus,
    COUNT(*) AS CountRecords
FROM dbo.PeopleSoft_Dept_Org_Levels
WHERE IsActive = 1
GROUP BY 
    CASE 
        WHEN Organization IS NULL OR LTRIM(RTRIM(Organization)) = '' 
        THEN 'Missing Organization'
        ELSE 'Valid Organization'
    END;