-- hc__updated_records.sql
-- Employees whose records changed in the most recent ETL run (ActionType = 'UPDATE').
-- Shows old vs new values for the most commonly changing fields.

;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SHR010HRORG_Audit
)
SELECT
    a.EmplId,
    a.NewName                                       AS Name,
    -- Employment status change
    CASE WHEN a.OldEmplStatus <> a.NewEmplStatus
         THEN a.OldEmplStatus END                   AS OldEmplStatus,
    CASE WHEN a.OldEmplStatus <> a.NewEmplStatus
         THEN a.NewEmplStatus END                   AS NewEmplStatus,
    -- Classification change
    CASE WHEN ISNULL(a.OldSalAdminPlan,'') <> ISNULL(a.NewSalAdminPlan,'')
              OR ISNULL(a.OldGrade,'') <> ISNULL(a.NewGrade,'')
         THEN CONCAT(a.OldSalAdminPlan, ' ', a.OldGrade) END AS OldClassification,
    CASE WHEN ISNULL(a.OldSalAdminPlan,'') <> ISNULL(a.NewSalAdminPlan,'')
              OR ISNULL(a.OldGrade,'') <> ISNULL(a.NewGrade,'')
         THEN CONCAT(a.NewSalAdminPlan, ' ', a.NewGrade) END AS NewClassification,
    -- Department change
    CASE WHEN ISNULL(a.OldDeptId,'') <> ISNULL(a.NewDeptId,'')
         THEN a.OldDeptDescr END                    AS OldDeptDescr,
    CASE WHEN ISNULL(a.OldDeptId,'') <> ISNULL(a.NewDeptId,'')
         THEN a.NewDeptDescr END                    AS NewDeptDescr,
    -- Compensation change
    CASE WHEN ISNULL(a.OldAnnualRt,-1) <> ISNULL(a.NewAnnualRt,-1)
         THEN a.OldAnnualRt END                     AS OldAnnualRt,
    CASE WHEN ISNULL(a.OldAnnualRt,-1) <> ISNULL(a.NewAnnualRt,-1)
         THEN a.NewAnnualRt END                     AS NewAnnualRt,
    a.AuditDtmUtc
FROM dbo.Peoplesoft_SHR010HRORG_Audit  a
JOIN latest_run                        lr ON a.RunId = lr.RunId
WHERE a.ActionType = 'UPDATE'
ORDER BY a.NewName;
