-- hem__updated_records.sql
-- Movement event records updated (corrected) in the most recent MERGE run.
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
    a.OldRowHash,
    a.NewRowHash,
    a.OldNewEmplStatus,
    a.NewNewEmplStatus,
    a.OldNewDeptId,
    a.NewNewDeptId,
    a.OldNewLevel1,
    a.NewNewLevel1,
    a.OldNewAnnualRt,
    a.NewNewAnnualRt,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_HEM_Audit a
INNER JOIN latest_run r ON a.RunId = r.RunId
WHERE a.ActionType = 'UPDATE'
ORDER BY a.AuditDtmUtc DESC;
