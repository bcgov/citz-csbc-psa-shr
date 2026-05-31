-- hc__new_records.sql
-- Employees added in the most recent ETL run (ActionType = 'INSERT').

;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SHR010HRORG_Audit
)
SELECT
    a.EmplId,
    t.Name,
    t.EmplStatus,
    t.EmplCtg,
    t.SalAdminPlan,
    t.Grade,
    t.DeptDescr,
    t.Level1,
    t.Level2,
    t.LocationCity,
    t.HireDt,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_SHR010HRORG_Audit  a
JOIN latest_run                        lr ON a.RunId = lr.RunId
JOIN dbo.Peoplesoft_SHR010HRORG        t  ON a.EmplId = t.EmplId
WHERE a.ActionType = 'INSERT'
ORDER BY t.Name;
