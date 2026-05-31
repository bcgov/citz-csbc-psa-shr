-- tip__update_history.sql
-- All UPDATE and REACTIVATE records showing before/after duration and exit state.
-- Uncomment the WHERE clause to filter to a specific employee.
SET NOCOUNT ON;

SELECT
    a.EmployeeId,
    a.Position,
    a.EntryDate,
    a.EntrySeq,
    a.ActionType,
    a.AuditDtmUtc,
    a.OldDaysInPosition,
    a.NewDaysInPosition,
    a.OldYearsInPosition,
    a.NewYearsInPosition,
    a.OldExitDate,
    a.NewExitDate,
    a.OldExitAction,
    a.NewExitAction,
    a.OldExitReason,
    a.NewExitReason,
    a.OldOrganization,
    a.NewOrganization,
    a.OldCurrentOrHistorical,
    a.NewCurrentOrHistorical,
    a.OldIsActive,
    a.NewIsActive
FROM dbo.Peoplesoft_TIP_Audit a
WHERE a.ActionType IN ('UPDATE', 'REACTIVATE')
-- Uncomment to filter to a specific employee:
-- AND a.EmployeeId = '123456'
ORDER BY a.EmployeeId, a.EntryDate, a.AuditDtmUtc DESC;
