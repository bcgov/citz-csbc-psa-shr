/*=============================================================================
Report: Active Organization Trend by Run
=============================================================================*/

SELECT
    a.RunId,
    MIN(a.AuditDtmUtc) AS RunTime,
    COUNT(DISTINCT t.Organization) AS ActiveOrganizations
FROM dbo.PeopleSoft_Dept_Org_Levels t
JOIN (
    SELECT DISTINCT RunId, AuditDtmUtc
    FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
) a ON 1 = 1
WHERE t.IsActive = 1
GROUP BY a.RunId
ORDER BY RunTime DESC;