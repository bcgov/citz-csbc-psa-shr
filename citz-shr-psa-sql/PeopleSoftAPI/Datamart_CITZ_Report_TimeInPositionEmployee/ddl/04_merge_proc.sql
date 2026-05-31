-- =============================================================================
-- 04_merge_proc.sql
-- MERGE procedure: Datamart_CITZ_Report_TimeInPositionEmployee
-- Proc name: dbo.usp_Merge_PeopleSoft_TIP
-- 55 columns — individual column comparisons in WHEN MATCHED (no RowHash needed).
-- Guardrails: staging empty, NULL key, rowcount variance, soft-delete spike.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_Merge_PeopleSoft_TIP
    @MinPctOfTarget     DECIMAL(5, 4) = 0.80,
    @MaxPctOfTarget     DECIMAL(5, 4) = 1.20,
    @MaxSoftDeletePct   DECIMAL(5, 4) = 0.10
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- =========================================================================
    -- Guardrail 1: Staging must not be empty
    -- =========================================================================
    DECLARE @StagingRows  INT = (SELECT COUNT(*) FROM dbo.Stg_Peoplesoft_TIP);
    DECLARE @TargetRows   INT = (SELECT COUNT(*) FROM dbo.Peoplesoft_TIP);

    IF @StagingRows = 0
        THROW 51000, 'Staging table Stg_Peoplesoft_TIP is empty. MERGE aborted.', 1;

    -- =========================================================================
    -- Guardrail 2: No NULL business key columns in staging
    -- =========================================================================
    IF EXISTS (
        SELECT 1
        FROM dbo.Stg_Peoplesoft_TIP
        WHERE EmployeeId IS NULL
           OR EmployeeId = ''
           OR Position   IS NULL
           OR Position   = ''
           OR EntryDate  IS NULL
           OR EntrySeq   IS NULL
    )
        THROW 51001, 'NULL or blank business key detected in Stg_Peoplesoft_TIP. MERGE aborted.', 1;

    -- =========================================================================
    -- Guardrail 3: Rowcount variance check (only when target already populated)
    -- =========================================================================
    IF @TargetRows > 0
    BEGIN
        DECLARE @Ratio DECIMAL(10, 4) = CAST(@StagingRows AS DECIMAL(10, 4))
                                      / CAST(@TargetRows  AS DECIMAL(10, 4));
        IF @Ratio < @MinPctOfTarget OR @Ratio > @MaxPctOfTarget
            THROW 51002, 'Staging row count is outside the expected range relative to target. MERGE aborted.', 1;
    END;

    -- =========================================================================
    -- Guardrail 4: Soft-delete spike check (only when target already populated)
    -- =========================================================================
    IF @TargetRows > 0
    BEGIN
        DECLARE @ActiveRows    INT = (SELECT COUNT(*) FROM dbo.Peoplesoft_TIP WHERE IsActive = 1);
        DECLARE @ToSoftDelete  INT = (
            SELECT COUNT(*)
            FROM dbo.Peoplesoft_TIP tgt
            WHERE tgt.IsActive = 1
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.Stg_Peoplesoft_TIP src
                  WHERE src.EmployeeId = tgt.EmployeeId
                    AND src.Position   = tgt.Position
                    AND src.EntryDate  = tgt.EntryDate
                    AND src.EntrySeq   = tgt.EntrySeq
              )
        );
        IF @ActiveRows > 0
           AND CAST(@ToSoftDelete AS DECIMAL(10, 4)) / CAST(@ActiveRows AS DECIMAL(10, 4)) > @MaxSoftDeletePct
            THROW 51003, 'Soft-delete rate exceeds threshold in Peoplesoft_TIP. MERGE aborted.', 1;
    END;

    -- =========================================================================
    -- MERGE
    -- =========================================================================
    DECLARE @RunId UNIQUEIDENTIFIER = NEWID();

    MERGE dbo.Peoplesoft_TIP WITH (HOLDLOCK) AS tgt
    USING (
        SELECT
            EmployeeId, Position, EntryDate, EntrySeq,
            EmployeeName, EmployeeRcd, Birthdate,
            EntryAction, EntryReason, EntryReasonDescr, EntryRownumber, EntryStdHours,
            FirstDateInPosition, IncumbentCountAfterEntry,
            ExitAction, ExitDate, ExitReason, ExitReasonDescr, ExitSeq, ExitStdHours,
            DaysInPosition, YearsInPosition, AccumulatedYearsInPositions,
            AgeAtEntry, AgeAtExit,
            ClassificationGroupAtEntry, JobCodeAtEntry, JobCodeDescAtEntry,
            JobCodeDescGroupAtEntry,
            CurrentApptStat, CurrentBase, CurrentDeptDescr, CurrentDeptId,
            CurrentJobFunction, CurrentJobcode, CurrentJobcodeDescr,
            CurrentOrHistorical, CurrentOrganization, CurrentPosition,
            CurrentProgram, CurrentProgramBranch, CurrentProgramDivision,
            CurrentStatus,
            PositionCurrentClassificationGroup, PositionCurrentJobCode,
            PositionCurrentJobCodeDesc, PositionCurrentJobCodeDescGroup,
            PositionTitle,
            Department, DeptId, Organization, Level1, Level2, Level3,
            Core
        FROM dbo.Stg_Peoplesoft_TIP
    ) AS src
    ON  tgt.EmployeeId = src.EmployeeId
    AND tgt.Position   = src.Position
    AND tgt.EntryDate  = src.EntryDate
    AND tgt.EntrySeq   = src.EntrySeq

    -- -----------------------------------------------------------------------
    -- UPDATE: record has changed OR was previously soft-deleted (reactivate)
    -- -----------------------------------------------------------------------
    WHEN MATCHED AND (
        tgt.IsActive = 0
        OR ISNULL(tgt.EmployeeName, '')                    <> ISNULL(src.EmployeeName, '')
        OR ISNULL(tgt.EmployeeRcd, -1)                     <> ISNULL(src.EmployeeRcd, -1)
        OR ISNULL(CONVERT(NVARCHAR(10), tgt.Birthdate, 23), '')
                                                           <> ISNULL(CONVERT(NVARCHAR(10), src.Birthdate, 23), '')
        OR ISNULL(tgt.EntryAction, '')                     <> ISNULL(src.EntryAction, '')
        OR ISNULL(tgt.EntryReason, '')                     <> ISNULL(src.EntryReason, '')
        OR ISNULL(tgt.EntryReasonDescr, '')                <> ISNULL(src.EntryReasonDescr, '')
        OR ISNULL(tgt.EntryRownumber, -1)                  <> ISNULL(src.EntryRownumber, -1)
        OR ISNULL(tgt.EntryStdHours, -1)                   <> ISNULL(src.EntryStdHours, -1)
        OR ISNULL(CONVERT(NVARCHAR(10), tgt.FirstDateInPosition, 23), '')
                                                           <> ISNULL(CONVERT(NVARCHAR(10), src.FirstDateInPosition, 23), '')
        OR ISNULL(tgt.IncumbentCountAfterEntry, -1)        <> ISNULL(src.IncumbentCountAfterEntry, -1)
        OR ISNULL(tgt.ExitAction, '')                      <> ISNULL(src.ExitAction, '')
        OR ISNULL(CONVERT(NVARCHAR(10), tgt.ExitDate, 23), '')
                                                           <> ISNULL(CONVERT(NVARCHAR(10), src.ExitDate, 23), '')
        OR ISNULL(tgt.ExitReason, '')                      <> ISNULL(src.ExitReason, '')
        OR ISNULL(tgt.ExitReasonDescr, '')                 <> ISNULL(src.ExitReasonDescr, '')
        OR ISNULL(tgt.ExitSeq, -1)                         <> ISNULL(src.ExitSeq, -1)
        OR ISNULL(tgt.ExitStdHours, -1)                    <> ISNULL(src.ExitStdHours, -1)
        OR ISNULL(tgt.DaysInPosition, -1)                  <> ISNULL(src.DaysInPosition, -1)
        OR ISNULL(tgt.YearsInPosition, -1)                 <> ISNULL(src.YearsInPosition, -1)
        OR ISNULL(tgt.AccumulatedYearsInPositions, -1)     <> ISNULL(src.AccumulatedYearsInPositions, -1)
        OR ISNULL(tgt.AgeAtEntry, -1)                      <> ISNULL(src.AgeAtEntry, -1)
        OR ISNULL(tgt.AgeAtExit, -1)                       <> ISNULL(src.AgeAtExit, -1)
        OR ISNULL(tgt.ClassificationGroupAtEntry, '')      <> ISNULL(src.ClassificationGroupAtEntry, '')
        OR ISNULL(tgt.JobCodeAtEntry, '')                  <> ISNULL(src.JobCodeAtEntry, '')
        OR ISNULL(tgt.JobCodeDescAtEntry, '')              <> ISNULL(src.JobCodeDescAtEntry, '')
        OR ISNULL(tgt.JobCodeDescGroupAtEntry, '')         <> ISNULL(src.JobCodeDescGroupAtEntry, '')
        OR ISNULL(tgt.CurrentApptStat, '')                 <> ISNULL(src.CurrentApptStat, '')
        OR ISNULL(tgt.CurrentBase, '')                     <> ISNULL(src.CurrentBase, '')
        OR ISNULL(tgt.CurrentDeptDescr, '')                <> ISNULL(src.CurrentDeptDescr, '')
        OR ISNULL(tgt.CurrentDeptId, '')                   <> ISNULL(src.CurrentDeptId, '')
        OR ISNULL(tgt.CurrentJobFunction, '')              <> ISNULL(src.CurrentJobFunction, '')
        OR ISNULL(tgt.CurrentJobcode, '')                  <> ISNULL(src.CurrentJobcode, '')
        OR ISNULL(tgt.CurrentJobcodeDescr, '')             <> ISNULL(src.CurrentJobcodeDescr, '')
        OR ISNULL(tgt.CurrentOrHistorical, '')             <> ISNULL(src.CurrentOrHistorical, '')
        OR ISNULL(tgt.CurrentOrganization, '')             <> ISNULL(src.CurrentOrganization, '')
        OR ISNULL(tgt.CurrentPosition, '')                 <> ISNULL(src.CurrentPosition, '')
        OR ISNULL(tgt.CurrentProgram, '')                  <> ISNULL(src.CurrentProgram, '')
        OR ISNULL(tgt.CurrentProgramBranch, '')            <> ISNULL(src.CurrentProgramBranch, '')
        OR ISNULL(tgt.CurrentProgramDivision, '')          <> ISNULL(src.CurrentProgramDivision, '')
        OR ISNULL(tgt.CurrentStatus, '')                   <> ISNULL(src.CurrentStatus, '')
        OR ISNULL(tgt.PositionCurrentClassificationGroup, '') <> ISNULL(src.PositionCurrentClassificationGroup, '')
        OR ISNULL(tgt.PositionCurrentJobCode, '')          <> ISNULL(src.PositionCurrentJobCode, '')
        OR ISNULL(tgt.PositionCurrentJobCodeDesc, '')      <> ISNULL(src.PositionCurrentJobCodeDesc, '')
        OR ISNULL(tgt.PositionCurrentJobCodeDescGroup, '') <> ISNULL(src.PositionCurrentJobCodeDescGroup, '')
        OR ISNULL(tgt.PositionTitle, '')                   <> ISNULL(src.PositionTitle, '')
        OR ISNULL(tgt.Department, '')                      <> ISNULL(src.Department, '')
        OR ISNULL(tgt.DeptId, '')                          <> ISNULL(src.DeptId, '')
        OR ISNULL(tgt.Organization, '')                    <> ISNULL(src.Organization, '')
        OR ISNULL(tgt.Level1, '')                          <> ISNULL(src.Level1, '')
        OR ISNULL(tgt.Level2, '')                          <> ISNULL(src.Level2, '')
        OR ISNULL(tgt.Level3, '')                          <> ISNULL(src.Level3, '')
        OR ISNULL(tgt.Core, '')                            <> ISNULL(src.Core, '')
    )
    THEN UPDATE SET
        tgt.EmployeeName                        = src.EmployeeName,
        tgt.EmployeeRcd                         = src.EmployeeRcd,
        tgt.Birthdate                           = src.Birthdate,
        tgt.EntryAction                         = src.EntryAction,
        tgt.EntryReason                         = src.EntryReason,
        tgt.EntryReasonDescr                    = src.EntryReasonDescr,
        tgt.EntryRownumber                      = src.EntryRownumber,
        tgt.EntryStdHours                       = src.EntryStdHours,
        tgt.FirstDateInPosition                 = src.FirstDateInPosition,
        tgt.IncumbentCountAfterEntry            = src.IncumbentCountAfterEntry,
        tgt.ExitAction                          = src.ExitAction,
        tgt.ExitDate                            = src.ExitDate,
        tgt.ExitReason                          = src.ExitReason,
        tgt.ExitReasonDescr                     = src.ExitReasonDescr,
        tgt.ExitSeq                             = src.ExitSeq,
        tgt.ExitStdHours                        = src.ExitStdHours,
        tgt.DaysInPosition                      = src.DaysInPosition,
        tgt.YearsInPosition                     = src.YearsInPosition,
        tgt.AccumulatedYearsInPositions         = src.AccumulatedYearsInPositions,
        tgt.AgeAtEntry                          = src.AgeAtEntry,
        tgt.AgeAtExit                           = src.AgeAtExit,
        tgt.ClassificationGroupAtEntry          = src.ClassificationGroupAtEntry,
        tgt.JobCodeAtEntry                      = src.JobCodeAtEntry,
        tgt.JobCodeDescAtEntry                  = src.JobCodeDescAtEntry,
        tgt.JobCodeDescGroupAtEntry             = src.JobCodeDescGroupAtEntry,
        tgt.CurrentApptStat                     = src.CurrentApptStat,
        tgt.CurrentBase                         = src.CurrentBase,
        tgt.CurrentDeptDescr                    = src.CurrentDeptDescr,
        tgt.CurrentDeptId                       = src.CurrentDeptId,
        tgt.CurrentJobFunction                  = src.CurrentJobFunction,
        tgt.CurrentJobcode                      = src.CurrentJobcode,
        tgt.CurrentJobcodeDescr                 = src.CurrentJobcodeDescr,
        tgt.CurrentOrHistorical                 = src.CurrentOrHistorical,
        tgt.CurrentOrganization                 = src.CurrentOrganization,
        tgt.CurrentPosition                     = src.CurrentPosition,
        tgt.CurrentProgram                      = src.CurrentProgram,
        tgt.CurrentProgramBranch                = src.CurrentProgramBranch,
        tgt.CurrentProgramDivision              = src.CurrentProgramDivision,
        tgt.CurrentStatus                       = src.CurrentStatus,
        tgt.PositionCurrentClassificationGroup  = src.PositionCurrentClassificationGroup,
        tgt.PositionCurrentJobCode              = src.PositionCurrentJobCode,
        tgt.PositionCurrentJobCodeDesc          = src.PositionCurrentJobCodeDesc,
        tgt.PositionCurrentJobCodeDescGroup     = src.PositionCurrentJobCodeDescGroup,
        tgt.PositionTitle                       = src.PositionTitle,
        tgt.Department                          = src.Department,
        tgt.DeptId                              = src.DeptId,
        tgt.Organization                        = src.Organization,
        tgt.Level1                              = src.Level1,
        tgt.Level2                              = src.Level2,
        tgt.Level3                              = src.Level3,
        tgt.Core                                = src.Core,
        tgt.IsActive                            = 1,
        tgt.LastUpdatedUtc                      = SYSUTCDATETIME()

    -- -----------------------------------------------------------------------
    -- INSERT: new record
    -- -----------------------------------------------------------------------
    WHEN NOT MATCHED BY TARGET
    THEN INSERT (
        EmployeeId, Position, EntryDate, EntrySeq,
        EmployeeName, EmployeeRcd, Birthdate,
        EntryAction, EntryReason, EntryReasonDescr, EntryRownumber, EntryStdHours,
        FirstDateInPosition, IncumbentCountAfterEntry,
        ExitAction, ExitDate, ExitReason, ExitReasonDescr, ExitSeq, ExitStdHours,
        DaysInPosition, YearsInPosition, AccumulatedYearsInPositions, AgeAtEntry, AgeAtExit,
        ClassificationGroupAtEntry, JobCodeAtEntry, JobCodeDescAtEntry, JobCodeDescGroupAtEntry,
        CurrentApptStat, CurrentBase, CurrentDeptDescr, CurrentDeptId,
        CurrentJobFunction, CurrentJobcode, CurrentJobcodeDescr,
        CurrentOrHistorical, CurrentOrganization, CurrentPosition,
        CurrentProgram, CurrentProgramBranch, CurrentProgramDivision, CurrentStatus,
        PositionCurrentClassificationGroup, PositionCurrentJobCode,
        PositionCurrentJobCodeDesc, PositionCurrentJobCodeDescGroup, PositionTitle,
        Department, DeptId, Organization, Level1, Level2, Level3, Core,
        IsActive, CreatedUtc, LastUpdatedUtc
    ) VALUES (
        src.EmployeeId, src.Position, src.EntryDate, src.EntrySeq,
        src.EmployeeName, src.EmployeeRcd, src.Birthdate,
        src.EntryAction, src.EntryReason, src.EntryReasonDescr, src.EntryRownumber, src.EntryStdHours,
        src.FirstDateInPosition, src.IncumbentCountAfterEntry,
        src.ExitAction, src.ExitDate, src.ExitReason, src.ExitReasonDescr, src.ExitSeq, src.ExitStdHours,
        src.DaysInPosition, src.YearsInPosition, src.AccumulatedYearsInPositions, src.AgeAtEntry, src.AgeAtExit,
        src.ClassificationGroupAtEntry, src.JobCodeAtEntry, src.JobCodeDescAtEntry, src.JobCodeDescGroupAtEntry,
        src.CurrentApptStat, src.CurrentBase, src.CurrentDeptDescr, src.CurrentDeptId,
        src.CurrentJobFunction, src.CurrentJobcode, src.CurrentJobcodeDescr,
        src.CurrentOrHistorical, src.CurrentOrganization, src.CurrentPosition,
        src.CurrentProgram, src.CurrentProgramBranch, src.CurrentProgramDivision, src.CurrentStatus,
        src.PositionCurrentClassificationGroup, src.PositionCurrentJobCode,
        src.PositionCurrentJobCodeDesc, src.PositionCurrentJobCodeDescGroup, src.PositionTitle,
        src.Department, src.DeptId, src.Organization, src.Level1, src.Level2, src.Level3, src.Core,
        1, SYSUTCDATETIME(), SYSUTCDATETIME()
    )

    -- -----------------------------------------------------------------------
    -- SOFT DELETE: record no longer returned by API
    -- -----------------------------------------------------------------------
    WHEN NOT MATCHED BY SOURCE AND tgt.IsActive = 1
    THEN UPDATE SET
        tgt.IsActive        = 0,
        tgt.LastUpdatedUtc  = SYSUTCDATETIME()

    -- -----------------------------------------------------------------------
    -- Output to audit table
    -- -----------------------------------------------------------------------
    OUTPUT
        @RunId,
        SYSUTCDATETIME(),
        CASE $action
            WHEN 'INSERT' THEN 'INSERT'
            WHEN 'UPDATE' THEN
                CASE
                    WHEN DELETED.IsActive = 0 THEN 'REACTIVATE'
                    WHEN INSERTED.IsActive = 0 THEN 'SOFT_DELETE'
                    ELSE 'UPDATE'
                END
        END,
        COALESCE(INSERTED.EmployeeId, DELETED.EmployeeId),
        COALESCE(INSERTED.Position,   DELETED.Position),
        COALESCE(INSERTED.EntryDate,  DELETED.EntryDate),
        COALESCE(INSERTED.EntrySeq,   DELETED.EntrySeq),
        DELETED.IsActive,
        INSERTED.IsActive,
        DELETED.DaysInPosition,          INSERTED.DaysInPosition,
        DELETED.YearsInPosition,         INSERTED.YearsInPosition,
        DELETED.ExitDate,                INSERTED.ExitDate,
        DELETED.ExitAction,              INSERTED.ExitAction,
        DELETED.ExitReason,              INSERTED.ExitReason,
        DELETED.ExitReasonDescr,         INSERTED.ExitReasonDescr,
        DELETED.Organization,            INSERTED.Organization,
        DELETED.Level1,                  INSERTED.Level1,
        DELETED.Level2,                  INSERTED.Level2,
        DELETED.DeptId,                  INSERTED.DeptId,
        DELETED.ClassificationGroupAtEntry, INSERTED.ClassificationGroupAtEntry,
        DELETED.JobCodeAtEntry,          INSERTED.JobCodeAtEntry,
        DELETED.CurrentOrHistorical,     INSERTED.CurrentOrHistorical,
        DELETED.CurrentStatus,           INSERTED.CurrentStatus,
        DELETED.CurrentOrganization,     INSERTED.CurrentOrganization,
        DELETED.CurrentDeptId,           INSERTED.CurrentDeptId
    INTO dbo.Peoplesoft_TIP_Audit (
        RunId, AuditDtmUtc, ActionType,
        EmployeeId, Position, EntryDate, EntrySeq,
        OldIsActive, NewIsActive,
        OldDaysInPosition,       NewDaysInPosition,
        OldYearsInPosition,      NewYearsInPosition,
        OldExitDate,             NewExitDate,
        OldExitAction,           NewExitAction,
        OldExitReason,           NewExitReason,
        OldExitReasonDescr,      NewExitReasonDescr,
        OldOrganization,         NewOrganization,
        OldLevel1,               NewLevel1,
        OldLevel2,               NewLevel2,
        OldDeptId,               NewDeptId,
        OldClassificationGroupAtEntry, NewClassificationGroupAtEntry,
        OldJobCodeAtEntry,       NewJobCodeAtEntry,
        OldCurrentOrHistorical,  NewCurrentOrHistorical,
        OldCurrentStatus,        NewCurrentStatus,
        OldCurrentOrganization,  NewCurrentOrganization,
        OldCurrentDeptId,        NewCurrentDeptId
    );

END;
GO
