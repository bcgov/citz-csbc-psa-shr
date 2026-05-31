-- tip__record_change_history.sql
-- Full audit trail for a single employee's position record.
-- Uncomment the WHERE clause and supply key values to narrow the result.
SET NOCOUNT ON;

SELECT
    a.AuditId,
    a.RunId,
    a.AuditDtmUtc,
    a.ActionType,
    a.EmployeeId,
    a.Position,
    a.EntryDate,
    a.EntrySeq,
    a.OldIsActive,                  a.NewIsActive,
    a.OldDaysInPosition,            a.NewDaysInPosition,
    a.OldYearsInPosition,           a.NewYearsInPosition,
    a.OldExitDate,                  a.NewExitDate,
    a.OldExitAction,                a.NewExitAction,
    a.OldExitReason,                a.NewExitReason,
    a.OldExitReasonDescr,           a.NewExitReasonDescr,
    a.OldOrganization,              a.NewOrganization,
    a.OldLevel1,                    a.NewLevel1,
    a.OldLevel2,                    a.NewLevel2,
    a.OldDeptId,                    a.NewDeptId,
    a.OldClassificationGroupAtEntry, a.NewClassificationGroupAtEntry,
    a.OldCurrentOrHistorical,       a.NewCurrentOrHistorical,
    a.OldCurrentStatus,             a.NewCurrentStatus
FROM dbo.Peoplesoft_TIP_Audit a
-- Filter to a specific record:
-- WHERE a.EmployeeId = '123456' AND a.Position = 'P00001' AND a.EntryDate = '2020-04-01'
ORDER BY a.EmployeeId, a.EntryDate, a.AuditDtmUtc DESC;
