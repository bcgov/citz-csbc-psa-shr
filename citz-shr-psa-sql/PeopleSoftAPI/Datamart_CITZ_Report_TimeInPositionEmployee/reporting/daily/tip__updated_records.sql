-- tip__updated_records.sql
-- Records updated in the most recent MERGE run with before/after key values.
SET NOCOUNT ON;

;WITH latest_run AS (
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_TIP_Audit
)
SELECT
    a.EmployeeId,
    a.Position,
    a.EntryDate,
    a.EntrySeq,
    a.OldDaysInPosition,
    a.NewDaysInPosition,
    a.OldYearsInPosition,
    a.NewYearsInPosition,
    a.OldExitDate,
    a.NewExitDate,
    a.OldExitReason,
    a.NewExitReason,
    a.OldOrganization,
    a.NewOrganization,
    a.OldCurrentOrHistorical,
    a.NewCurrentOrHistorical,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_TIP_Audit a
INNER JOIN latest_run r ON a.RunId = r.RunId
WHERE a.ActionType = 'UPDATE'
ORDER BY a.AuditDtmUtc DESC;
