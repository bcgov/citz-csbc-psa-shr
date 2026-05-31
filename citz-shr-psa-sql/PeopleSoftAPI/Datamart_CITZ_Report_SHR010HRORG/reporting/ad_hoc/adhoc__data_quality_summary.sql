-- adhoc__data_quality_summary.sql
-- Overall data quality metrics for the SHR010HRORG employee dataset.
-- Run after each load or ad-hoc to assess completeness and anomalies.

SELECT
    -- Completeness
    COUNT(*)                                                        AS TotalActiveRecords,
    COUNT(*) FILTER (WHERE EmailId IS NULL)                        AS MissingEmail,
    COUNT(*) FILTER (WHERE Idir IS NULL)                           AS MissingIdir,
    COUNT(*) FILTER (WHERE Supervisor IS NULL)                     AS MissingSupervisor,
    COUNT(*) FILTER (WHERE DeptId IS NULL OR DeptId = '')          AS MissingDept,
    COUNT(*) FILTER (WHERE Level1 IS NULL OR Level1 = '')          AS MissingLevel1,
    COUNT(*) FILTER (WHERE SalAdminPlan IS NULL OR SalAdminPlan = '') AS MissingSalaryPlan,
    COUNT(*) FILTER (WHERE Grade IS NULL OR Grade = '')            AS MissingGrade,
    -- Leave / special states
    COUNT(*) FILTER (WHERE FutureReturnDate IS NOT NULL)           AS ActiveOnLeave,
    COUNT(*) FILTER (WHERE LayoffLeaveStopPayReason IS NOT NULL)   AS ActiveWithLayoffReason,
    -- Data ranges
    MIN(HireDt)                                                    AS EarliestHireDate,
    MAX(HireDt)                                                    AS LatestHireDate,
    MIN(Birthdate)                                                 AS EarliestBirthdate,
    MAX(Birthdate)                                                 AS LatestBirthdate
FROM dbo.Peoplesoft_SHR010HRORG
WHERE IsActive = 1;
