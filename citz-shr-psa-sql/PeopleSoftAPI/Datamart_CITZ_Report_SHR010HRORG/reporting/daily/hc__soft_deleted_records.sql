-- hc__soft_deleted_records.sql
-- Employees soft-deleted in the most recent ETL run (no longer in the API feed).
-- Soft delete means IsActive was set to 0; no hard delete occurs.

;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SHR010HRORG_Audit
)
SELECT
    a.EmplId,
    a.OldName                       AS Name,
    a.OldEmplStatus                 AS LastEmplStatus,
    a.OldEmplCtg                    AS LastEmplCtg,
    a.OldSalAdminPlan               AS LastSalAdminPlan,
    a.OldGrade                      AS LastGrade,
    a.OldDeptDescr                  AS LastDeptDescr,
    a.OldLevel1                     AS LastLevel1,
    a.OldLevel2                     AS LastLevel2,
    a.OldLocationCity               AS LastLocationCity,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_SHR010HRORG_Audit  a
JOIN latest_run                        lr ON a.RunId = lr.RunId
WHERE a.ActionType = 'SOFT_DELETE'
ORDER BY a.OldName;
