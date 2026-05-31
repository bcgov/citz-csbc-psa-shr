-- hc__update_history.sql
-- All UPDATE audit events ordered most recent first.
-- Use to investigate when and how individual employee records changed.

SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.EmplId,
    a.OldName,
    a.NewName,
    a.OldEmplStatus,
    a.NewEmplStatus,
    a.OldSalAdminPlan,
    a.NewSalAdminPlan,
    a.OldGrade,
    a.NewGrade,
    a.OldDeptId,
    a.NewDeptId,
    a.OldDeptDescr,
    a.NewDeptDescr,
    a.OldLevel1,
    a.NewLevel1,
    a.OldLevel2,
    a.NewLevel2,
    a.OldAnnualRt,
    a.NewAnnualRt,
    a.OldRowHash,
    a.NewRowHash
FROM dbo.Peoplesoft_SHR010HRORG_Audit a
WHERE a.ActionType = 'UPDATE'
ORDER BY a.AuditDtmUtc DESC;
