-- hem__reactivation_trends.sql
-- Trend of reactivation events (soft-deleted records returned by API).
SET NOCOUNT ON;

SELECT
    CAST(a.AuditDtmUtc AS DATE)   AS AuditDate,
    a.RunId,
    a.EmplId,
    a.EffDt,
    a.NewMoveType                  AS MoveType,
    a.NewNewDeptId                 AS DeptId,
    a.NewNewOrganization           AS Organization
FROM dbo.Peoplesoft_HEM_Audit a
WHERE a.ActionType = 'REACTIVATE'
ORDER BY AuditDate DESC, a.EmplId;
