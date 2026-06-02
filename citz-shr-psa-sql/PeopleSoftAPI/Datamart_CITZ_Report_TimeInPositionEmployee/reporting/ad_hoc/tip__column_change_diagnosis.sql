-- =============================================================================
-- tip__column_change_diagnosis.sql
-- PURPOSE:  Identify which WHEN MATCHED columns are driving false UPDATEs.
--
-- BACKGROUND:
--   Run 2 (2026-06-02) produced 2,784 UPDATEs after only 25 INSERTs.
--   ~15% false UPDATE rate indicates one or more continuously-computed columns
--   remain in the WHEN MATCHED clause.
--
-- PRIMARY SUSPECTS:
--   1. AgeAtExit       -- DECIMAL(10,4). For active entries (ExitDate IS NULL)
--                         the API likely computes this as age at AsOfDate.
--                         Changes every run for all ~ExitDate-NULL rows.
--   2. EntryRownumber  -- INT. If the API computes this as a descending rank
--                         (most-recent = 1), all existing entries for an
--                         employee get renumbered when a new position is added.
--                         25 new INSERTs × avg prior entries ~= 2,784.
--
-- COLUMNS THAT CANNOT BE DIAGNOSED FROM AUDIT (not tracked):
--   AgeAtEntry, AgeAtExit, EntryRownumber, IncumbentCountAfterEntry,
--   EmployeeName, EmployeeRcd, Birthdate, EntryAction, EntryReason,
--   EntryReasonDescr, EntryStdHours, FirstDateInPosition, ExitSeq, ExitStdHours,
--   CurrentApptStat, CurrentBase, CurrentDeptDescr, CurrentJobFunction,
--   CurrentJobcode, CurrentJobcodeDescr, CurrentPosition, CurrentProgram,
--   CurrentProgramBranch, CurrentProgramDivision,
--   PositionCurrentClassificationGroup, PositionCurrentJobCode,
--   PositionCurrentJobCodeDesc, PositionCurrentJobCodeDescGroup,
--   PositionTitle, Department, Level3, Core
--
-- HOW TO RUN:
--   Load staging first (run the R ETL script), then run this script BEFORE the
--   next MERGE execution so staging reflects the same data as the last run.
--   OR re-run without loading staging to use Part A (audit-only) for the
--   tracked columns.
--
-- =============================================================================


-- =============================================================================
-- PART A: Audit-based column change counts
--         Covers only the 16 non-key columns tracked in Peoplesoft_TIP_Audit.
--         Run any time (no staging required).
-- =============================================================================

DECLARE @LatestUpdateRun UNIQUEIDENTIFIER = (
    SELECT TOP 1 RunId
    FROM dbo.Peoplesoft_TIP_Audit
    WHERE ActionType = 'UPDATE'
    GROUP BY RunId
    ORDER BY MAX(AuditDtmUtc) DESC
);

SELECT
    @LatestUpdateRun                                                         AS RunId,
    COUNT(*)                                                                 AS TotalUpdateRows,

    -- Duration columns (excluded from WHEN MATCHED but still in UPDATE SET)
    SUM(CASE WHEN ISNULL(OldDaysInPosition,  '')  <> ISNULL(NewDaysInPosition,  '')  THEN 1 ELSE 0 END)  AS DaysInPosition_Changed,
    SUM(CASE WHEN ISNULL(OldYearsInPosition, '')  <> ISNULL(NewYearsInPosition, '')  THEN 1 ELSE 0 END)  AS YearsInPosition_Changed,

    -- Exit event columns
    SUM(CASE WHEN ISNULL(OldExitDate,         '') <> ISNULL(NewExitDate,         '') THEN 1 ELSE 0 END)  AS ExitDate_Changed,
    SUM(CASE WHEN ISNULL(OldExitAction,       '') <> ISNULL(NewExitAction,       '') THEN 1 ELSE 0 END)  AS ExitAction_Changed,
    SUM(CASE WHEN ISNULL(OldExitReason,       '') <> ISNULL(NewExitReason,       '') THEN 1 ELSE 0 END)  AS ExitReason_Changed,
    SUM(CASE WHEN ISNULL(OldExitReasonDescr,  '') <> ISNULL(NewExitReasonDescr,  '') THEN 1 ELSE 0 END)  AS ExitReasonDescr_Changed,

    -- Org hierarchy columns
    SUM(CASE WHEN ISNULL(OldOrganization,     '') <> ISNULL(NewOrganization,     '') THEN 1 ELSE 0 END)  AS Organization_Changed,
    SUM(CASE WHEN ISNULL(OldLevel1,           '') <> ISNULL(NewLevel1,           '') THEN 1 ELSE 0 END)  AS Level1_Changed,
    SUM(CASE WHEN ISNULL(OldLevel2,           '') <> ISNULL(NewLevel2,           '') THEN 1 ELSE 0 END)  AS Level2_Changed,
    SUM(CASE WHEN ISNULL(OldDeptId,           '') <> ISNULL(NewDeptId,           '') THEN 1 ELSE 0 END)  AS DeptId_Changed,

    -- Classification at entry
    SUM(CASE WHEN ISNULL(OldClassificationGroupAtEntry, '') <> ISNULL(NewClassificationGroupAtEntry, '') THEN 1 ELSE 0 END) AS ClassificationGroupAtEntry_Changed,
    SUM(CASE WHEN ISNULL(OldJobCodeAtEntry,   '') <> ISNULL(NewJobCodeAtEntry,   '') THEN 1 ELSE 0 END)  AS JobCodeAtEntry_Changed,

    -- Current snapshot columns (legitimately change as employee moves)
    SUM(CASE WHEN ISNULL(OldCurrentOrHistorical,  '') <> ISNULL(NewCurrentOrHistorical,  '') THEN 1 ELSE 0 END) AS CurrentOrHistorical_Changed,
    SUM(CASE WHEN ISNULL(OldCurrentStatus,        '') <> ISNULL(NewCurrentStatus,        '') THEN 1 ELSE 0 END) AS CurrentStatus_Changed,
    SUM(CASE WHEN ISNULL(OldCurrentOrganization,  '') <> ISNULL(NewCurrentOrganization,  '') THEN 1 ELSE 0 END) AS CurrentOrganization_Changed,
    SUM(CASE WHEN ISNULL(OldCurrentDeptId,        '') <> ISNULL(NewCurrentDeptId,        '') THEN 1 ELSE 0 END) AS CurrentDeptId_Changed

FROM dbo.Peoplesoft_TIP_Audit
WHERE RunId = @LatestUpdateRun
  AND ActionType = 'UPDATE';


-- =============================================================================
-- PART B: Staging-vs-target comparison for UNTRACKED WHEN MATCHED columns
--         REQUIRES STAGING to be loaded (run R ETL before executing this).
--         Run BEFORE the next MERGE so staging matches the most recent API pull.
--
--         This reveals the suspects that Part A cannot see.
-- =============================================================================

-- Suspect 1: AgeAtExit
-- If non-zero, the API computes AgeAtExit as age at AsOfDate for active entries.
-- Fix: exclude AgeAtExit from WHEN MATCHED (keep in UPDATE SET).
SELECT
    'AgeAtExit'                                                              AS ColumnName,
    COUNT(*)                                                                 AS RowsWithDiff,
    SUM(CASE WHEN tgt.ExitDate IS NULL THEN 1 ELSE 0 END)                   AS OfWhichExitDateIsNull,
    SUM(CASE WHEN tgt.ExitDate IS NOT NULL THEN 1 ELSE 0 END)               AS OfWhichExitDateIsNotNull,
    MIN(CAST(tgt.AgeAtExit AS NVARCHAR(30)))                                AS TargetAgeAtExit_Min,
    MAX(CAST(tgt.AgeAtExit AS NVARCHAR(30)))                                AS TargetAgeAtExit_Max,
    MIN(CAST(src.AgeAtExit AS NVARCHAR(30)))                                AS StagingAgeAtExit_Min,
    MAX(CAST(src.AgeAtExit AS NVARCHAR(30)))                                AS StagingAgeAtExit_Max
FROM dbo.Peoplesoft_TIP tgt
JOIN dbo.Stg_Peoplesoft_TIP src
    ON  src.EmployeeId = tgt.EmployeeId
    AND src.Position   = tgt.Position
    AND src.EntryDate  = tgt.EntryDate
    AND src.EntrySeq   = tgt.EntrySeq
WHERE ISNULL(tgt.AgeAtExit, -1) <> ISNULL(src.AgeAtExit, -1);

-- Suspect 2: EntryRownumber
-- If non-zero AND OfWhichExitDateIsNull is near zero, EntryRownumber is the
-- likely cause. The API recomputes it (e.g. descending rank) when new entries
-- are added, renumbering all prior entries for the same employee.
-- Fix: exclude EntryRownumber from WHEN MATCHED (keep in UPDATE SET).
SELECT
    'EntryRownumber'                                                         AS ColumnName,
    COUNT(*)                                                                 AS RowsWithDiff,
    SUM(CASE WHEN tgt.ExitDate IS NULL THEN 1 ELSE 0 END)                   AS OfWhichExitDateIsNull,
    SUM(CASE WHEN tgt.ExitDate IS NOT NULL THEN 1 ELSE 0 END)               AS OfWhichExitDateIsNotNull,
    MIN(CAST(tgt.EntryRownumber AS NVARCHAR(30)))                           AS TargetEntryRownumber_Min,
    MAX(CAST(tgt.EntryRownumber AS NVARCHAR(30)))                           AS TargetEntryRownumber_Max
FROM dbo.Peoplesoft_TIP tgt
JOIN dbo.Stg_Peoplesoft_TIP src
    ON  src.EmployeeId = tgt.EmployeeId
    AND src.Position   = tgt.Position
    AND src.EntryDate  = tgt.EntryDate
    AND src.EntrySeq   = tgt.EntrySeq
WHERE ISNULL(tgt.EntryRownumber, -1) <> ISNULL(src.EntryRownumber, -1);

-- Suspect 3: AgeAtEntry (lower probability — Birthdate and EntryDate are fixed)
SELECT
    'AgeAtEntry'                                                             AS ColumnName,
    COUNT(*)                                                                 AS RowsWithDiff
FROM dbo.Peoplesoft_TIP tgt
JOIN dbo.Stg_Peoplesoft_TIP src
    ON  src.EmployeeId = tgt.EmployeeId
    AND src.Position   = tgt.Position
    AND src.EntryDate  = tgt.EntryDate
    AND src.EntrySeq   = tgt.EntrySeq
WHERE ISNULL(tgt.AgeAtEntry, -1) <> ISNULL(src.AgeAtEntry, -1);

-- Suspect 4: IncumbentCountAfterEntry (could change if new entries added to same Position)
SELECT
    'IncumbentCountAfterEntry'                                               AS ColumnName,
    COUNT(*)                                                                 AS RowsWithDiff
FROM dbo.Peoplesoft_TIP tgt
JOIN dbo.Stg_Peoplesoft_TIP src
    ON  src.EmployeeId = tgt.EmployeeId
    AND src.Position   = tgt.Position
    AND src.EntryDate  = tgt.EntryDate
    AND src.EntrySeq   = tgt.EntrySeq
WHERE ISNULL(tgt.IncumbentCountAfterEntry, -1) <> ISNULL(src.IncumbentCountAfterEntry, -1);

-- Suspect 5: AccumulatedYearsInPositions (should already be excluded, verify)
SELECT
    'AccumulatedYearsInPositions'                                            AS ColumnName,
    COUNT(*)                                                                 AS RowsWithDiff
FROM dbo.Peoplesoft_TIP tgt
JOIN dbo.Stg_Peoplesoft_TIP src
    ON  src.EmployeeId = tgt.EmployeeId
    AND src.Position   = tgt.Position
    AND src.EntryDate  = tgt.EntryDate
    AND src.EntrySeq   = tgt.EntrySeq
WHERE ISNULL(tgt.AccumulatedYearsInPositions, -1) <> ISNULL(src.AccumulatedYearsInPositions, -1);


-- =============================================================================
-- PART C: Full untracked-column sweep
--         Returns one row per untracked WHEN MATCHED column with row counts.
--         Use this as a single-query replacement for Part B above.
-- =============================================================================

SELECT col, COUNT(*) AS RowsWithDiff
FROM (
    SELECT
        tgt.EmployeeId, tgt.Position, tgt.EntryDate, tgt.EntrySeq,
        -- Enumerate every untracked column as a separate row via CROSS APPLY
        v.col
    FROM dbo.Peoplesoft_TIP tgt
    JOIN dbo.Stg_Peoplesoft_TIP src
        ON  src.EmployeeId = tgt.EmployeeId
        AND src.Position   = tgt.Position
        AND src.EntryDate  = tgt.EntryDate
        AND src.EntrySeq   = tgt.EntrySeq
    CROSS APPLY (VALUES
        ('EmployeeName',                      CASE WHEN ISNULL(tgt.EmployeeName, '')                      <> ISNULL(src.EmployeeName, '')                      THEN 1 END),
        ('EmployeeRcd',                       CASE WHEN ISNULL(tgt.EmployeeRcd, -1)                       <> ISNULL(src.EmployeeRcd, -1)                       THEN 1 END),
        ('EntryAction',                       CASE WHEN ISNULL(tgt.EntryAction, '')                       <> ISNULL(src.EntryAction, '')                       THEN 1 END),
        ('EntryReason',                       CASE WHEN ISNULL(tgt.EntryReason, '')                       <> ISNULL(src.EntryReason, '')                       THEN 1 END),
        ('EntryReasonDescr',                  CASE WHEN ISNULL(tgt.EntryReasonDescr, '')                  <> ISNULL(src.EntryReasonDescr, '')                  THEN 1 END),
        ('EntryRownumber',                    CASE WHEN ISNULL(tgt.EntryRownumber, -1)                    <> ISNULL(src.EntryRownumber, -1)                    THEN 1 END),
        ('EntryStdHours',                     CASE WHEN ISNULL(tgt.EntryStdHours, -1)                     <> ISNULL(src.EntryStdHours, -1)                     THEN 1 END),
        ('FirstDateInPosition',               CASE WHEN ISNULL(CONVERT(NVARCHAR(10), tgt.FirstDateInPosition, 23), '') <> ISNULL(CONVERT(NVARCHAR(10), src.FirstDateInPosition, 23), '') THEN 1 END),
        ('IncumbentCountAfterEntry',          CASE WHEN ISNULL(tgt.IncumbentCountAfterEntry, -1)          <> ISNULL(src.IncumbentCountAfterEntry, -1)          THEN 1 END),
        ('ExitSeq',                           CASE WHEN ISNULL(tgt.ExitSeq, -1)                           <> ISNULL(src.ExitSeq, -1)                           THEN 1 END),
        ('ExitStdHours',                      CASE WHEN ISNULL(tgt.ExitStdHours, -1)                      <> ISNULL(src.ExitStdHours, -1)                      THEN 1 END),
        ('AgeAtEntry',                        CASE WHEN ISNULL(tgt.AgeAtEntry, -1)                        <> ISNULL(src.AgeAtEntry, -1)                        THEN 1 END),
        ('AgeAtExit',                         CASE WHEN ISNULL(tgt.AgeAtExit, -1)                         <> ISNULL(src.AgeAtExit, -1)                         THEN 1 END),
        ('JobCodeDescAtEntry',                CASE WHEN ISNULL(tgt.JobCodeDescAtEntry, '')                <> ISNULL(src.JobCodeDescAtEntry, '')                THEN 1 END),
        ('JobCodeDescGroupAtEntry',           CASE WHEN ISNULL(tgt.JobCodeDescGroupAtEntry, '')           <> ISNULL(src.JobCodeDescGroupAtEntry, '')           THEN 1 END),
        ('CurrentApptStat',                   CASE WHEN ISNULL(tgt.CurrentApptStat, '')                   <> ISNULL(src.CurrentApptStat, '')                   THEN 1 END),
        ('CurrentBase',                       CASE WHEN ISNULL(tgt.CurrentBase, '')                       <> ISNULL(src.CurrentBase, '')                       THEN 1 END),
        ('CurrentDeptDescr',                  CASE WHEN ISNULL(tgt.CurrentDeptDescr, '')                  <> ISNULL(src.CurrentDeptDescr, '')                  THEN 1 END),
        ('CurrentJobFunction',                CASE WHEN ISNULL(tgt.CurrentJobFunction, '')                <> ISNULL(src.CurrentJobFunction, '')                THEN 1 END),
        ('CurrentJobcode',                    CASE WHEN ISNULL(tgt.CurrentJobcode, '')                    <> ISNULL(src.CurrentJobcode, '')                    THEN 1 END),
        ('CurrentJobcodeDescr',               CASE WHEN ISNULL(tgt.CurrentJobcodeDescr, '')               <> ISNULL(src.CurrentJobcodeDescr, '')               THEN 1 END),
        ('CurrentPosition',                   CASE WHEN ISNULL(tgt.CurrentPosition, '')                   <> ISNULL(src.CurrentPosition, '')                   THEN 1 END),
        ('CurrentProgram',                    CASE WHEN ISNULL(tgt.CurrentProgram, '')                    <> ISNULL(src.CurrentProgram, '')                    THEN 1 END),
        ('CurrentProgramBranch',              CASE WHEN ISNULL(tgt.CurrentProgramBranch, '')              <> ISNULL(src.CurrentProgramBranch, '')              THEN 1 END),
        ('CurrentProgramDivision',            CASE WHEN ISNULL(tgt.CurrentProgramDivision, '')            <> ISNULL(src.CurrentProgramDivision, '')            THEN 1 END),
        ('PositionCurrentClassificationGroup',CASE WHEN ISNULL(tgt.PositionCurrentClassificationGroup, '') <> ISNULL(src.PositionCurrentClassificationGroup, '') THEN 1 END),
        ('PositionCurrentJobCode',            CASE WHEN ISNULL(tgt.PositionCurrentJobCode, '')            <> ISNULL(src.PositionCurrentJobCode, '')            THEN 1 END),
        ('PositionCurrentJobCodeDesc',        CASE WHEN ISNULL(tgt.PositionCurrentJobCodeDesc, '')        <> ISNULL(src.PositionCurrentJobCodeDesc, '')        THEN 1 END),
        ('PositionCurrentJobCodeDescGroup',   CASE WHEN ISNULL(tgt.PositionCurrentJobCodeDescGroup, '')   <> ISNULL(src.PositionCurrentJobCodeDescGroup, '')   THEN 1 END),
        ('PositionTitle',                     CASE WHEN ISNULL(tgt.PositionTitle, '')                     <> ISNULL(src.PositionTitle, '')                     THEN 1 END),
        ('Department',                        CASE WHEN ISNULL(tgt.Department, '')                        <> ISNULL(src.Department, '')                        THEN 1 END),
        ('Level3',                            CASE WHEN ISNULL(tgt.Level3, '')                            <> ISNULL(src.Level3, '')                            THEN 1 END),
        ('Core',                              CASE WHEN ISNULL(tgt.Core, '')                              <> ISNULL(src.Core, '')                              THEN 1 END),
        ('AccumulatedYearsInPositions',       CASE WHEN ISNULL(CAST(tgt.AccumulatedYearsInPositions AS NVARCHAR(30)), '') <> ISNULL(CAST(src.AccumulatedYearsInPositions AS NVARCHAR(30)), '') THEN 1 END)
    ) AS v(col, diff_flag)
    WHERE v.diff_flag = 1
) AS diffs
GROUP BY col
ORDER BY RowsWithDiff DESC;
