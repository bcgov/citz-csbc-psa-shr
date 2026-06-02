SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_Merge_PeopleSoft_EPC
(
      @Force                 BIT = 0
    , @MinPctOfTarget        DECIMAL(5,2) = 0.80  -- staging must be at least 80% of target
    , @MaxPctOfTarget        DECIMAL(5,2) = 1.20  -- staging must be at most 120% of target
    , @MaxSoftDeletePct      DECIMAL(5,2) = 0.10  -- max 10% of target allowed to be soft-deleted per run
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunId UNIQUEIDENTIFIER = NEWID();
    DECLARE @StgCnt INT, @TgtCnt INT;

    SELECT @StgCnt = COUNT(*) FROM dbo.Stg_Peoplesoft_EPC;
    SELECT @TgtCnt = COUNT(*) FROM dbo.Peoplesoft_EPC;

    ------------------------------------------------------------------------
    -- Guardrail 0: staging must not be empty unless forced
    ------------------------------------------------------------------------
    IF (@StgCnt = 0 AND @Force = 0)
        THROW 51000, 'MERGE aborted: staging table is empty (possible API failure). Use @Force=1 to override.', 1;

    ------------------------------------------------------------------------
    -- Guardrail 1: business key must not be NULL
    ------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM dbo.Stg_Peoplesoft_EPC WHERE Position IS NULL)
        THROW 51001, 'MERGE aborted: staging contains NULL Position.', 1;

    ------------------------------------------------------------------------
    -- Guardrail 2: rowcount variance (skip on first ever load)
    ------------------------------------------------------------------------
    IF (@TgtCnt > 0 AND @Force = 0)
    BEGIN
        IF (@StgCnt < CEILING(@TgtCnt * @MinPctOfTarget) OR @StgCnt > CEILING(@TgtCnt * @MaxPctOfTarget))
        BEGIN
            DECLARE @msg NVARCHAR(4000) =
                CONCAT('MERGE aborted: rowcount variance out of bounds. Staging=', @StgCnt,
                       ', Target=', @TgtCnt,
                       ', Bounds=[', @MinPctOfTarget, 'x..', @MaxPctOfTarget, 'x]. Use @Force=1 to override.');
            THROW 51002, @msg, 1;
        END
    END

    BEGIN TRY
        BEGIN TRAN;

        --------------------------------------------------------------------
        -- Guardrail 3: preview soft deletes
        --------------------------------------------------------------------
        DECLARE @WouldSoftDelete INT = 0;

        IF (@TgtCnt > 0)
        BEGIN
            SELECT @WouldSoftDelete = COUNT(*)
            FROM dbo.Peoplesoft_EPC tgt
            LEFT JOIN dbo.Stg_Peoplesoft_EPC src
                ON src.Position = tgt.Position
            WHERE src.Position IS NULL
              AND tgt.IsActive = 1;
        END

        IF (@TgtCnt > 0 AND @Force = 0)
        BEGIN
            IF (@WouldSoftDelete > CEILING(@TgtCnt * @MaxSoftDeletePct))
            BEGIN
                DECLARE @msg2 NVARCHAR(4000) =
                    CONCAT('MERGE aborted: would soft-delete too many rows. WouldSoftDelete=', @WouldSoftDelete,
                           ', Target=', @TgtCnt,
                           ', MaxAllowed=', CEILING(@TgtCnt * @MaxSoftDeletePct),
                           ' (', @MaxSoftDeletePct, ' of target). Use @Force=1 to override.');
                THROW 51003, @msg2, 1;
            END
        END

        --------------------------------------------------------------------
        -- MERGE (UPSERT) + SOFT DELETE + AUDIT OUTPUT
        --------------------------------------------------------------------
        ;MERGE dbo.Peoplesoft_EPC WITH (HOLDLOCK) AS tgt
        USING dbo.Stg_Peoplesoft_EPC AS src
            ON tgt.Position = src.Position

        -- UPDATE or REACTIVATE when matched and data has changed
        WHEN MATCHED AND (
               tgt.IsActive = 0
            OR ISNULL(tgt.BaseIncumbents,           '')          <> ISNULL(src.BaseIncumbents,           '')
            OR ISNULL(tgt.BusinessUnitDescr,         '')          <> ISNULL(src.BusinessUnitDescr,         '')
            OR ISNULL(tgt.City,                      '')          <> ISNULL(src.City,                      '')
            OR ISNULL(tgt.ClassificationGroup,       '')          <> ISNULL(src.ClassificationGroup,       '')
            OR ISNULL(tgt.Core,                      '')          <> ISNULL(src.Core,                      '')
            OR ISNULL(tgt.CreateEffDt,               '1900-01-01') <> ISNULL(src.CreateEffDt,              '1900-01-01')
            OR ISNULL(tgt.DeptId,                    '')          <> ISNULL(src.DeptId,                    '')
            OR ISNULL(tgt.DeptIdDesc,                '')          <> ISNULL(src.DeptIdDesc,                '')
            OR ISNULL(tgt.DevelopmentRegion,         '')          <> ISNULL(src.DevelopmentRegion,         '')
            OR ISNULL(tgt.EmptyEffDt,                '1900-01-01') <> ISNULL(src.EmptyEffDt,               '1900-01-01')
            OR ISNULL(tgt.EmptyPosition,             '')          <> ISNULL(src.EmptyPosition,             '')
            OR ISNULL(tgt.ExcludedOrIncluded,        '')          <> ISNULL(src.ExcludedOrIncluded,        '')
            OR ISNULL(tgt.IncumbentCount,            -1)          <> ISNULL(src.IncumbentCount,            -1)
            OR ISNULL(tgt.Incumbents,                '')          <> ISNULL(src.Incumbents,                '')
            OR ISNULL(tgt.JobCode,                   '')          <> ISNULL(src.JobCode,                   '')
            OR ISNULL(tgt.JobCodeDesc,               '')          <> ISNULL(src.JobCodeDesc,               '')
            OR ISNULL(tgt.JobFunc,                   '')          <> ISNULL(src.JobFunc,                   '')
            OR ISNULL(tgt.JobReqOpenDate,            '1900-01-01') <> ISNULL(src.JobReqOpenDate,           '1900-01-01')
            OR ISNULL(tgt.JobReqStatus,              '')          <> ISNULL(src.JobReqStatus,              '')
            OR ISNULL(tgt.LastIncumbents,            '')          <> ISNULL(src.LastIncumbents,            '')
            OR ISNULL(tgt.Location,                  '')          <> ISNULL(src.Location,                  '')
            OR ISNULL(tgt.NocCode,                   '')          <> ISNULL(src.NocCode,                   '')
            OR ISNULL(tgt.NocCodeDescr,              '')          <> ISNULL(src.NocCodeDescr,              '')
            OR ISNULL(tgt.Organization,              '')          <> ISNULL(src.Organization,              '')
            OR ISNULL(tgt.PosStatusDescr,            '')          <> ISNULL(src.PosStatusDescr,            '')
            OR ISNULL(tgt.PositionEmptyGt1Year,      '')          <> ISNULL(src.PositionEmptyGt1Year,      '')
            OR ISNULL(tgt.PositionHasBaseIncumbent,  '')          <> ISNULL(src.PositionHasBaseIncumbent,  '')
            OR ISNULL(tgt.PositionTitle,             '')          <> ISNULL(src.PositionTitle,             '')
            OR ISNULL(tgt.Program,                   '')          <> ISNULL(src.Program,                   '')
            OR ISNULL(tgt.ProgramBranch,             '')          <> ISNULL(src.ProgramBranch,             '')
            OR ISNULL(tgt.ProgramDivision,           '')          <> ISNULL(src.ProgramDivision,           '')
            OR ISNULL(tgt.ProvincialQuadrant,        '')          <> ISNULL(src.ProvincialQuadrant,        '')
            OR ISNULL(tgt.RegDistrictDesc,           '')          <> ISNULL(src.RegDistrictDesc,           '')
            OR ISNULL(tgt.RegOrTempDescr,            '')          <> ISNULL(src.RegOrTempDescr,            '')
            OR ISNULL(tgt.ReportsTo,                 '')          <> ISNULL(src.ReportsTo,                 '')
            OR ISNULL(tgt.Supervisor,                '')          <> ISNULL(src.Supervisor,                '')
            -- YearsEmpty excluded — continuously-computed from EmptyEffDt + AsOfDate;
            -- changes daily by ~1/365.25 for every empty position and would produce 100% false UPDATEs.
        )
        THEN UPDATE SET
            BaseIncumbents              = src.BaseIncumbents,
            BusinessUnitDescr           = src.BusinessUnitDescr,
            City                        = src.City,
            ClassificationGroup         = src.ClassificationGroup,
            Core                        = src.Core,
            CreateEffDt                 = src.CreateEffDt,
            DeptId                      = src.DeptId,
            DeptIdDesc                  = src.DeptIdDesc,
            DevelopmentRegion           = src.DevelopmentRegion,
            EmptyEffDt                  = src.EmptyEffDt,
            EmptyPosition               = src.EmptyPosition,
            ExcludedOrIncluded          = src.ExcludedOrIncluded,
            IncumbentCount              = src.IncumbentCount,
            Incumbents                  = src.Incumbents,
            JobCode                     = src.JobCode,
            JobCodeDesc                 = src.JobCodeDesc,
            JobFunc                     = src.JobFunc,
            JobReqOpenDate              = src.JobReqOpenDate,
            JobReqStatus                = src.JobReqStatus,
            LastIncumbents              = src.LastIncumbents,
            Location                    = src.Location,
            NocCode                     = src.NocCode,
            NocCodeDescr                = src.NocCodeDescr,
            Organization                = src.Organization,
            PosStatusDescr              = src.PosStatusDescr,
            PositionEmptyGt1Year        = src.PositionEmptyGt1Year,
            PositionHasBaseIncumbent    = src.PositionHasBaseIncumbent,
            PositionTitle               = src.PositionTitle,
            Program                     = src.Program,
            ProgramBranch               = src.ProgramBranch,
            ProgramDivision             = src.ProgramDivision,
            ProvincialQuadrant          = src.ProvincialQuadrant,
            RegDistrictDesc             = src.RegDistrictDesc,
            RegOrTempDescr              = src.RegOrTempDescr,
            ReportsTo                   = src.ReportsTo,
            Supervisor                  = src.Supervisor,
            YearsEmpty                  = src.YearsEmpty,
            IsActive                    = 1,
            LastUpdatedUtc              = SYSUTCDATETIME()

        -- INSERT new positions
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            Position,
            BaseIncumbents, BusinessUnitDescr, City, ClassificationGroup,
            Core, CreateEffDt, DeptId, DeptIdDesc, DevelopmentRegion,
            EmptyEffDt, EmptyPosition, ExcludedOrIncluded, IncumbentCount, Incumbents,
            JobCode, JobCodeDesc, JobFunc, JobReqOpenDate, JobReqStatus,
            LastIncumbents, Location, NocCode, NocCodeDescr, Organization,
            PosStatusDescr, PositionEmptyGt1Year, PositionHasBaseIncumbent, PositionTitle,
            Program, ProgramBranch, ProgramDivision, ProvincialQuadrant,
            RegDistrictDesc, RegOrTempDescr, ReportsTo, Supervisor, YearsEmpty,
            IsActive, CreatedUtc, LastUpdatedUtc
        )
        VALUES (
            src.Position,
            src.BaseIncumbents, src.BusinessUnitDescr, src.City, src.ClassificationGroup,
            src.Core, src.CreateEffDt, src.DeptId, src.DeptIdDesc, src.DevelopmentRegion,
            src.EmptyEffDt, src.EmptyPosition, src.ExcludedOrIncluded, src.IncumbentCount, src.Incumbents,
            src.JobCode, src.JobCodeDesc, src.JobFunc, src.JobReqOpenDate, src.JobReqStatus,
            src.LastIncumbents, src.Location, src.NocCode, src.NocCodeDescr, src.Organization,
            src.PosStatusDescr, src.PositionEmptyGt1Year, src.PositionHasBaseIncumbent, src.PositionTitle,
            src.Program, src.ProgramBranch, src.ProgramDivision, src.ProvincialQuadrant,
            src.RegDistrictDesc, src.RegOrTempDescr, src.ReportsTo, src.Supervisor, src.YearsEmpty,
            1, SYSUTCDATETIME(), SYSUTCDATETIME()
        )

        -- SOFT DELETE (position no longer returned by API): mark inactive
        WHEN NOT MATCHED BY SOURCE AND tgt.IsActive = 1
        THEN UPDATE SET
            IsActive        = 0,
            LastUpdatedUtc  = SYSUTCDATETIME()

        OUTPUT
            @RunId AS RunId,
            CASE
                WHEN $action = 'UPDATE' AND deleted.IsActive = 1 AND inserted.IsActive = 0 THEN 'SOFT_DELETE'
                WHEN $action = 'UPDATE' AND deleted.IsActive = 0 AND inserted.IsActive = 1 THEN 'REACTIVATE'
                ELSE $action
            END AS ActionType,
            COALESCE(inserted.Position, deleted.Position) AS Position,

            HASHBYTES('SHA2_256', CAST(CONCAT_WS('|',
                COALESCE(deleted.Position,                      ''),
                COALESCE(deleted.BaseIncumbents,                ''),
                COALESCE(deleted.BusinessUnitDescr,             ''),
                COALESCE(deleted.City,                          ''),
                COALESCE(deleted.ClassificationGroup,           ''),
                COALESCE(deleted.Core,                          ''),
                COALESCE(CONVERT(NVARCHAR(10), deleted.CreateEffDt, 23), ''),
                COALESCE(deleted.DeptId,                        ''),
                COALESCE(deleted.DeptIdDesc,                    ''),
                COALESCE(deleted.DevelopmentRegion,             ''),
                COALESCE(CONVERT(NVARCHAR(10), deleted.EmptyEffDt, 23), ''),
                COALESCE(deleted.EmptyPosition,                 ''),
                COALESCE(deleted.ExcludedOrIncluded,            ''),
                COALESCE(CONVERT(NVARCHAR(10), deleted.IncumbentCount), ''),
                COALESCE(deleted.Incumbents,                    ''),
                COALESCE(deleted.JobCode,                       ''),
                COALESCE(deleted.JobCodeDesc,                   ''),
                COALESCE(deleted.JobFunc,                       ''),
                COALESCE(CONVERT(NVARCHAR(10), deleted.JobReqOpenDate, 23), ''),
                COALESCE(deleted.JobReqStatus,                  ''),
                COALESCE(deleted.LastIncumbents,                ''),
                COALESCE(deleted.Location,                      ''),
                COALESCE(deleted.NocCode,                       ''),
                COALESCE(deleted.NocCodeDescr,                  ''),
                COALESCE(deleted.Organization,                  ''),
                COALESCE(deleted.PosStatusDescr,                ''),
                COALESCE(deleted.PositionEmptyGt1Year,          ''),
                COALESCE(deleted.PositionHasBaseIncumbent,      ''),
                COALESCE(deleted.PositionTitle,                 ''),
                COALESCE(deleted.Program,                       ''),
                COALESCE(deleted.ProgramBranch,                 ''),
                COALESCE(deleted.ProgramDivision,               ''),
                COALESCE(deleted.ProvincialQuadrant,            ''),
                COALESCE(deleted.RegDistrictDesc,               ''),
                COALESCE(deleted.RegOrTempDescr,                ''),
                COALESCE(deleted.ReportsTo,                     ''),
                COALESCE(deleted.Supervisor,                    '')
                -- YearsEmpty excluded from hash — continuously-computed; see MERGE WHEN MATCHED note
            ) AS NVARCHAR(MAX))) AS OldRowHash,

            HASHBYTES('SHA2_256', CAST(CONCAT_WS('|',
                COALESCE(inserted.Position,                     ''),
                COALESCE(inserted.BaseIncumbents,               ''),
                COALESCE(inserted.BusinessUnitDescr,            ''),
                COALESCE(inserted.City,                         ''),
                COALESCE(inserted.ClassificationGroup,          ''),
                COALESCE(inserted.Core,                         ''),
                COALESCE(CONVERT(NVARCHAR(10), inserted.CreateEffDt, 23), ''),
                COALESCE(inserted.DeptId,                       ''),
                COALESCE(inserted.DeptIdDesc,                   ''),
                COALESCE(inserted.DevelopmentRegion,            ''),
                COALESCE(CONVERT(NVARCHAR(10), inserted.EmptyEffDt, 23), ''),
                COALESCE(inserted.EmptyPosition,                ''),
                COALESCE(inserted.ExcludedOrIncluded,           ''),
                COALESCE(CONVERT(NVARCHAR(10), inserted.IncumbentCount), ''),
                COALESCE(inserted.Incumbents,                   ''),
                COALESCE(inserted.JobCode,                      ''),
                COALESCE(inserted.JobCodeDesc,                  ''),
                COALESCE(inserted.JobFunc,                      ''),
                COALESCE(CONVERT(NVARCHAR(10), inserted.JobReqOpenDate, 23), ''),
                COALESCE(inserted.JobReqStatus,                 ''),
                COALESCE(inserted.LastIncumbents,               ''),
                COALESCE(inserted.Location,                     ''),
                COALESCE(inserted.NocCode,                      ''),
                COALESCE(inserted.NocCodeDescr,                 ''),
                COALESCE(inserted.Organization,                 ''),
                COALESCE(inserted.PosStatusDescr,               ''),
                COALESCE(inserted.PositionEmptyGt1Year,         ''),
                COALESCE(inserted.PositionHasBaseIncumbent,     ''),
                COALESCE(inserted.PositionTitle,                ''),
                COALESCE(inserted.Program,                      ''),
                COALESCE(inserted.ProgramBranch,                ''),
                COALESCE(inserted.ProgramDivision,              ''),
                COALESCE(inserted.ProvincialQuadrant,           ''),
                COALESCE(inserted.RegDistrictDesc,              ''),
                COALESCE(inserted.RegOrTempDescr,               ''),
                COALESCE(inserted.ReportsTo,                    ''),
                COALESCE(inserted.Supervisor,                   '')
                -- YearsEmpty excluded from hash — continuously-computed; see MERGE WHEN MATCHED note
            ) AS NVARCHAR(MAX))) AS NewRowHash,

            CAST(deleted.IsActive  AS NVARCHAR(255))                       AS OldIsActive,
            CAST(inserted.IsActive AS NVARCHAR(255))                       AS NewIsActive,

            CAST(deleted.BaseIncumbents              AS NVARCHAR(255))     AS OldBaseIncumbents,
            CAST(deleted.BusinessUnitDescr           AS NVARCHAR(255))     AS OldBusinessUnitDescr,
            CAST(deleted.City                        AS NVARCHAR(255))     AS OldCity,
            CAST(deleted.ClassificationGroup         AS NVARCHAR(255))     AS OldClassificationGroup,
            CAST(deleted.Core                        AS NVARCHAR(255))     AS OldCore,
            CONVERT(NVARCHAR(255), deleted.CreateEffDt, 23)                AS OldCreateEffDt,
            CAST(deleted.DeptId                      AS NVARCHAR(255))     AS OldDeptId,
            CAST(deleted.DeptIdDesc                  AS NVARCHAR(255))     AS OldDeptIdDesc,
            CAST(deleted.DevelopmentRegion           AS NVARCHAR(255))     AS OldDevelopmentRegion,
            CONVERT(NVARCHAR(255), deleted.EmptyEffDt, 23)                 AS OldEmptyEffDt,
            CAST(deleted.EmptyPosition               AS NVARCHAR(255))     AS OldEmptyPosition,
            CAST(deleted.ExcludedOrIncluded          AS NVARCHAR(255))     AS OldExcludedOrIncluded,
            CAST(deleted.IncumbentCount              AS NVARCHAR(255))     AS OldIncumbentCount,
            CAST(deleted.Incumbents                  AS NVARCHAR(255))     AS OldIncumbents,
            CAST(deleted.JobCode                     AS NVARCHAR(255))     AS OldJobCode,
            CAST(deleted.JobCodeDesc                 AS NVARCHAR(255))     AS OldJobCodeDesc,
            CAST(deleted.JobFunc                     AS NVARCHAR(255))     AS OldJobFunc,
            CONVERT(NVARCHAR(255), deleted.JobReqOpenDate, 23)             AS OldJobReqOpenDate,
            CAST(deleted.JobReqStatus                AS NVARCHAR(255))     AS OldJobReqStatus,
            CAST(deleted.LastIncumbents              AS NVARCHAR(255))     AS OldLastIncumbents,
            CAST(deleted.Location                    AS NVARCHAR(255))     AS OldLocation,
            CAST(deleted.NocCode                     AS NVARCHAR(255))     AS OldNocCode,
            CAST(deleted.NocCodeDescr                AS NVARCHAR(255))     AS OldNocCodeDescr,
            CAST(deleted.Organization                AS NVARCHAR(255))     AS OldOrganization,
            CAST(deleted.PosStatusDescr              AS NVARCHAR(255))     AS OldPosStatusDescr,
            CAST(deleted.PositionEmptyGt1Year        AS NVARCHAR(255))     AS OldPositionEmptyGt1Year,
            CAST(deleted.PositionHasBaseIncumbent    AS NVARCHAR(255))     AS OldPositionHasBaseIncumbent,
            CAST(deleted.PositionTitle               AS NVARCHAR(255))     AS OldPositionTitle,
            CAST(deleted.Program                     AS NVARCHAR(255))     AS OldProgram,
            CAST(deleted.ProgramBranch               AS NVARCHAR(255))     AS OldProgramBranch,
            CAST(deleted.ProgramDivision             AS NVARCHAR(255))     AS OldProgramDivision,
            CAST(deleted.ProvincialQuadrant          AS NVARCHAR(255))     AS OldProvincialQuadrant,
            CAST(deleted.RegDistrictDesc             AS NVARCHAR(255))     AS OldRegDistrictDesc,
            CAST(deleted.RegOrTempDescr              AS NVARCHAR(255))     AS OldRegOrTempDescr,
            CAST(deleted.ReportsTo                   AS NVARCHAR(255))     AS OldReportsTo,
            CAST(deleted.Supervisor                  AS NVARCHAR(255))     AS OldSupervisor,
            CAST(deleted.YearsEmpty                  AS NVARCHAR(255))     AS OldYearsEmpty,

            CAST(inserted.BaseIncumbents             AS NVARCHAR(255))     AS NewBaseIncumbents,
            CAST(inserted.BusinessUnitDescr          AS NVARCHAR(255))     AS NewBusinessUnitDescr,
            CAST(inserted.City                       AS NVARCHAR(255))     AS NewCity,
            CAST(inserted.ClassificationGroup        AS NVARCHAR(255))     AS NewClassificationGroup,
            CAST(inserted.Core                       AS NVARCHAR(255))     AS NewCore,
            CONVERT(NVARCHAR(255), inserted.CreateEffDt, 23)               AS NewCreateEffDt,
            CAST(inserted.DeptId                     AS NVARCHAR(255))     AS NewDeptId,
            CAST(inserted.DeptIdDesc                 AS NVARCHAR(255))     AS NewDeptIdDesc,
            CAST(inserted.DevelopmentRegion          AS NVARCHAR(255))     AS NewDevelopmentRegion,
            CONVERT(NVARCHAR(255), inserted.EmptyEffDt, 23)                AS NewEmptyEffDt,
            CAST(inserted.EmptyPosition              AS NVARCHAR(255))     AS NewEmptyPosition,
            CAST(inserted.ExcludedOrIncluded         AS NVARCHAR(255))     AS NewExcludedOrIncluded,
            CAST(inserted.IncumbentCount             AS NVARCHAR(255))     AS NewIncumbentCount,
            CAST(inserted.Incumbents                 AS NVARCHAR(255))     AS NewIncumbents,
            CAST(inserted.JobCode                    AS NVARCHAR(255))     AS NewJobCode,
            CAST(inserted.JobCodeDesc                AS NVARCHAR(255))     AS NewJobCodeDesc,
            CAST(inserted.JobFunc                    AS NVARCHAR(255))     AS NewJobFunc,
            CONVERT(NVARCHAR(255), inserted.JobReqOpenDate, 23)            AS NewJobReqOpenDate,
            CAST(inserted.JobReqStatus               AS NVARCHAR(255))     AS NewJobReqStatus,
            CAST(inserted.LastIncumbents             AS NVARCHAR(255))     AS NewLastIncumbents,
            CAST(inserted.Location                   AS NVARCHAR(255))     AS NewLocation,
            CAST(inserted.NocCode                    AS NVARCHAR(255))     AS NewNocCode,
            CAST(inserted.NocCodeDescr               AS NVARCHAR(255))     AS NewNocCodeDescr,
            CAST(inserted.Organization               AS NVARCHAR(255))     AS NewOrganization,
            CAST(inserted.PosStatusDescr             AS NVARCHAR(255))     AS NewPosStatusDescr,
            CAST(inserted.PositionEmptyGt1Year       AS NVARCHAR(255))     AS NewPositionEmptyGt1Year,
            CAST(inserted.PositionHasBaseIncumbent   AS NVARCHAR(255))     AS NewPositionHasBaseIncumbent,
            CAST(inserted.PositionTitle              AS NVARCHAR(255))     AS NewPositionTitle,
            CAST(inserted.Program                    AS NVARCHAR(255))     AS NewProgram,
            CAST(inserted.ProgramBranch              AS NVARCHAR(255))     AS NewProgramBranch,
            CAST(inserted.ProgramDivision            AS NVARCHAR(255))     AS NewProgramDivision,
            CAST(inserted.ProvincialQuadrant         AS NVARCHAR(255))     AS NewProvincialQuadrant,
            CAST(inserted.RegDistrictDesc            AS NVARCHAR(255))     AS NewRegDistrictDesc,
            CAST(inserted.RegOrTempDescr             AS NVARCHAR(255))     AS NewRegOrTempDescr,
            CAST(inserted.ReportsTo                  AS NVARCHAR(255))     AS NewReportsTo,
            CAST(inserted.Supervisor                 AS NVARCHAR(255))     AS NewSupervisor,
            CAST(inserted.YearsEmpty                 AS NVARCHAR(255))     AS NewYearsEmpty

        -- ALIGNMENT NOTE: INTO column order MUST match OUTPUT expression order exactly.
        -- OUTPUT produces: all Old columns (sequential), then all New columns (sequential).
        -- INTO must list them in the same sequential order — NOT interleaved pairs.
        INTO dbo.Peoplesoft_EPC_Audit
        (
            RunId, ActionType, Position,
            OldRowHash, NewRowHash,
            OldIsActive, NewIsActive,
            OldBaseIncumbents, OldBusinessUnitDescr, OldCity, OldClassificationGroup,
            OldCore, OldCreateEffDt, OldDeptId, OldDeptIdDesc, OldDevelopmentRegion,
            OldEmptyEffDt, OldEmptyPosition, OldExcludedOrIncluded, OldIncumbentCount, OldIncumbents,
            OldJobCode, OldJobCodeDesc, OldJobFunc, OldJobReqOpenDate, OldJobReqStatus,
            OldLastIncumbents, OldLocation, OldNocCode, OldNocCodeDescr, OldOrganization,
            OldPosStatusDescr, OldPositionEmptyGt1Year, OldPositionHasBaseIncumbent, OldPositionTitle,
            OldProgram, OldProgramBranch, OldProgramDivision, OldProvincialQuadrant,
            OldRegDistrictDesc, OldRegOrTempDescr, OldReportsTo, OldSupervisor, OldYearsEmpty,
            NewBaseIncumbents, NewBusinessUnitDescr, NewCity, NewClassificationGroup,
            NewCore, NewCreateEffDt, NewDeptId, NewDeptIdDesc, NewDevelopmentRegion,
            NewEmptyEffDt, NewEmptyPosition, NewExcludedOrIncluded, NewIncumbentCount, NewIncumbents,
            NewJobCode, NewJobCodeDesc, NewJobFunc, NewJobReqOpenDate, NewJobReqStatus,
            NewLastIncumbents, NewLocation, NewNocCode, NewNocCodeDescr, NewOrganization,
            NewPosStatusDescr, NewPositionEmptyGt1Year, NewPositionHasBaseIncumbent, NewPositionTitle,
            NewProgram, NewProgramBranch, NewProgramDivision, NewProvincialQuadrant,
            NewRegDistrictDesc, NewRegOrTempDescr, NewReportsTo, NewSupervisor, NewYearsEmpty
        );

        COMMIT TRAN;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
