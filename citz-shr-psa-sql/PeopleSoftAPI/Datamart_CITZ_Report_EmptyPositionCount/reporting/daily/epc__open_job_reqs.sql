-- epc__open_job_reqs.sql
-- Empty positions with an open job requisition (JobReqStatus IS NOT NULL).

SELECT
    e.Position,
    e.PositionTitle,
    e.DeptId,
    e.DeptIdDesc,
    e.EmptyEffDt,
    e.YearsEmpty,
    e.JobCode,
    e.JobCodeDesc,
    e.ClassificationGroup,
    e.JobReqStatus,
    e.JobReqOpenDate,
    e.Program,
    e.ProgramBranch,
    e.DevelopmentRegion,
    e.City,
    e.ReportsTo,
    e.Supervisor
FROM dbo.Peoplesoft_EPC AS e
WHERE e.IsActive        = 1
  AND e.JobReqStatus    IS NOT NULL
ORDER BY e.JobReqOpenDate ASC, e.DeptIdDesc;
