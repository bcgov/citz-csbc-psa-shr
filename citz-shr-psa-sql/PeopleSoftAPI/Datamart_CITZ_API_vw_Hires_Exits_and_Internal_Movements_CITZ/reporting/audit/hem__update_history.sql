-- hem__update_history.sql
-- Full history of UPDATE actions for a specific employee's movement events.
-- Filter by EmplId to investigate corrections.
SET NOCOUNT ON;

;WITH latest_run AS (
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_HEM_Audit
)
SELECT
    a.EmplId,
    a.EffDt,
    a.EffSeq,
    a.EmplRcd,
    a.ActionType,
    a.AuditDtmUtc,
    a.OldNewDeptId,
    a.NewNewDeptId,
    a.OldNewEmplStatus,
    a.NewNewEmplStatus,
    a.OldNewLevel1,
    a.NewNewLevel1,
    a.OldNewOrganization,
    a.NewNewOrganization,
    a.OldNewAnnualRt,
    a.NewNewAnnualRt,
    a.OldRowHash,
    a.NewRowHash
FROM dbo.Peoplesoft_HEM_Audit a
WHERE a.ActionType IN ('UPDATE', 'REACTIVATE')
-- Uncomment to filter to a specific employee:
-- AND a.EmplId = '123456'
ORDER BY a.EmplId, a.EffDt, a.AuditDtmUtc DESC;
