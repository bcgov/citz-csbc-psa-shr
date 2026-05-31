-- tip__reactivated_records.sql
-- Records reactivated in the most recent MERGE run
-- (previously soft-deleted, now returned by the API again).
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
    a.NewOrganization           AS Organization,
    a.NewLevel1                 AS Level1,
    a.NewDeptId                 AS DeptId,
    a.NewCurrentOrHistorical    AS CurrentOrHistorical,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_TIP_Audit a
INNER JOIN latest_run r ON a.RunId = r.RunId
WHERE a.ActionType = 'REACTIVATE'
ORDER BY a.AuditDtmUtc DESC;
