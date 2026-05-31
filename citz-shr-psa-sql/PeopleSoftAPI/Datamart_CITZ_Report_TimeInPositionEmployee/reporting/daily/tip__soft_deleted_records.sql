-- tip__soft_deleted_records.sql
-- Records soft-deleted in the most recent MERGE run
-- (no longer returned by the API).
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
    a.OldOrganization           AS LastOrganization,
    a.OldLevel1                 AS LastLevel1,
    a.OldDeptId                 AS LastDeptId,
    a.OldYearsInPosition        AS YearsInPosition,
    a.OldCurrentOrHistorical    AS CurrentOrHistorical,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_TIP_Audit a
INNER JOIN latest_run r ON a.RunId = r.RunId
WHERE a.ActionType = 'SOFT_DELETE'
ORDER BY a.OldOrganization, a.EmployeeId;
