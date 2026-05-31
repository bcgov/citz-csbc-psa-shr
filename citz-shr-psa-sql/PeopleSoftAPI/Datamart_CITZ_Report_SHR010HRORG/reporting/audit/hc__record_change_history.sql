-- hc__record_change_history.sql
-- Full audit trail for a single employee across all ETL runs.
-- Set @EmplId to the employee ID you want to investigate.

DECLARE @EmplId NVARCHAR(20) = '';   -- <-- set EmplId here

SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.ActionType,
    a.OldEmplStatus,
    a.NewEmplStatus,
    a.OldSalAdminPlan,
    a.NewSalAdminPlan,
    a.OldGrade,
    a.NewGrade,
    a.OldStep,
    a.NewStep,
    a.OldAnnualRt,
    a.NewAnnualRt,
    a.OldDeptId,
    a.NewDeptId,
    a.OldDeptDescr,
    a.NewDeptDescr,
    a.OldLevel1,
    a.NewLevel1,
    a.OldLevel2,
    a.NewLevel2,
    a.OldLocationCity,
    a.NewLocationCity,
    a.OldIsActive,
    a.NewIsActive,
    a.OldRowHash,
    a.NewRowHash
FROM dbo.Peoplesoft_SHR010HRORG_Audit a
WHERE a.EmplId = @EmplId
ORDER BY a.AuditDtmUtc DESC;
