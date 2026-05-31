-- hem__soft_deleted_records.sql
-- Movement event records soft-deleted in the most recent MERGE run
-- (i.e., no longer returned by the API).
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
    a.OldMoveType                AS MoveType,
    a.OldCompChange              AS CompChange,
    a.OldNewDeptId               AS LastDeptId,
    a.OldNewOrganization         AS LastOrganization,
    a.OldNewLevel1               AS LastLevel1,
    a.OldNewAnnualRt             AS LastAnnualRt,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_HEM_Audit a
INNER JOIN latest_run r ON a.RunId = r.RunId
WHERE a.ActionType = 'SOFT_DELETE'
ORDER BY a.OldMoveType, a.EmplId;
