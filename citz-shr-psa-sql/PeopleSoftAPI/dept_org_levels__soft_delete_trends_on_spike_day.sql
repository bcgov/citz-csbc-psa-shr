DECLARE @AuditDate date = CAST(SYSUTCDATETIME() AS date); -- set to specific spike date

SELECT
    DepartmentID,
    OldOrganization,
    OldLevel1, OldLevel2, OldLevel3,
    AuditDtmUtc,
    RunId
FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
WHERE ActionType = 'SOFT_DELETE'
  AND CAST(AuditDtmUtc AS date) = @AuditDate
ORDER BY AuditDtmUtc DESC, DepartmentID;