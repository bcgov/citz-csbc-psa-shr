-- tip__new_records.sql
-- Records inserted in the most recent MERGE run.
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
    a.NewClassificationGroupAtEntry AS ClassificationGroupAtEntry,
    a.NewCurrentOrHistorical    AS CurrentOrHistorical,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_TIP_Audit a
INNER JOIN latest_run r ON a.RunId = r.RunId
WHERE a.ActionType = 'INSERT'
ORDER BY a.EntryDate DESC;
