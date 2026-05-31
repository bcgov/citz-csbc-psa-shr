-- hem__reactivated_records.sql
-- Movement event records reactivated in the most recent MERGE run
-- (previously soft-deleted, now returned by the API again).
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
    a.NewMoveType                AS MoveType,
    a.NewCompChange              AS CompChange,
    a.NewNewDeptId               AS DeptId,
    a.NewNewOrganization         AS Organization,
    a.NewNewLevel1               AS Level1,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_HEM_Audit a
INNER JOIN latest_run r ON a.RunId = r.RunId
WHERE a.ActionType = 'REACTIVATE'
ORDER BY a.AuditDtmUtc DESC;
