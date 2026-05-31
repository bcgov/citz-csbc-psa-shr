-- hc__reactivated_records.sql
-- Employees who reappeared in the API feed after previously being soft-deleted.

;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SHR010HRORG_Audit
)
SELECT
    a.EmplId,
    a.NewName                       AS Name,
    a.NewEmplStatus                 AS EmplStatus,
    a.NewEmplCtg                    AS EmplCtg,
    a.NewSalAdminPlan               AS SalAdminPlan,
    a.NewGrade                      AS Grade,
    a.NewDeptDescr                  AS DeptDescr,
    a.NewLevel1                     AS Level1,
    a.NewLevel2                     AS Level2,
    a.NewLocationCity               AS LocationCity,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_SHR010HRORG_Audit  a
JOIN latest_run                        lr ON a.RunId = lr.RunId
WHERE a.ActionType = 'REACTIVATE'
ORDER BY a.NewName;
