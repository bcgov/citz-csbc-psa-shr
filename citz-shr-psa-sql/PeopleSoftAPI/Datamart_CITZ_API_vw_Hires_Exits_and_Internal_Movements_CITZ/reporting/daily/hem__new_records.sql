-- hem__new_records.sql
-- Movement event records inserted in the most recent MERGE run.
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
    a.NewNewAction               AS NewAction,
    a.NewNewActionReasonDescr    AS ActionReasonDescr,
    a.NewNewDeptId               AS NewDeptId,
    a.NewNewLevel1               AS NewLevel1,
    a.NewNewOrganization         AS NewOrganization,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_HEM_Audit a
INNER JOIN latest_run r ON a.RunId = r.RunId
WHERE a.ActionType = 'INSERT'
ORDER BY a.EffDt DESC;
