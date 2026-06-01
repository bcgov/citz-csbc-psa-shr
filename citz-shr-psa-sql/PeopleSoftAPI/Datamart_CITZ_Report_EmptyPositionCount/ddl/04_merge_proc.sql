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
            OR ISNULL(tgt.YearsEmpty,                -1)          <> ISNULL(src.YearsEmpty,                -1)
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
                COALESCE(deleted.Supervisor,                    ''),
                COALESCE(CONVERT(NVARCHAR(30), deleted.YearsEmpty), '')
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
                COALESCE(inserted.Supervisor,                   ''),
                COALESCE(CONVERT(NVARCHAR(30), inserted.YearsEmpty), '')
            ) AS NVARCHAR(MAX))) AS NewRowHash,

            deleted.IsActive    AS OldIsActive,
            inserted.IsActive   AS NewIsActive,

            deleted.BaseIncumbents              AS OldBaseIncumbents,
            deleted.BusinessUnitDescr           AS OldBusinessUnitDescr,
            deleted.City                        AS OldCity,
            deleted.ClassificationGroup         AS OldClassificationGroup,
            deleted.Core                        AS OldCore,
            deleted.CreateEffDt                 AS OldCreateEffDt,
            deleted.DeptId                      AS OldDeptId,
            deleted.DeptIdDesc                  AS OldDeptIdDesc,
            deleted.DevelopmentRegion           AS OldDevelopmentRegion,
            deleted.EmptyEffDt                  AS OldEmptyEffDt,
            deleted.EmptyPosition               AS OldEmptyPosition,
            deleted.ExcludedOrIncluded          AS OldExcludedOrIncluded,
            deleted.IncumbentCount              AS OldIncumbentCount,
            deleted.Incumbents                  AS OldIncumbents,
            deleted.JobCode                     AS OldJobCode,
            deleted.JobCodeDesc                 AS OldJobCodeDesc,
            deleted.JobFunc                     AS OldJobFunc,
            deleted.JobReqOpenDate              AS OldJobReqOpenDate,
            deleted.JobReqStatus                AS OldJobReqStatus,
            deleted.LastIncumbents              AS OldLastIncumbents,
            deleted.Location                    AS OldLocation,
            deleted.NocCode                     AS OldNocCode,
            deleted.NocCodeDescr                AS OldNocCodeDescr,
            deleted.Organization                AS OldOrganization,
            deleted.PosStatusDescr              AS OldPosStatusDescr,
            deleted.PositionEmptyGt1Year        AS OldPositionEmptyGt1Year,
            deleted.PositionHasBaseIncumbent    AS OldPositionHasBaseIncumbent,
            deleted.PositionTitle               AS OldPositionTitle,
            deleted.Program                     AS OldProgram,
            deleted.ProgramBranch               AS OldProgramBranch,
            deleted.ProgramDivision             AS OldProgramDivision,
            deleted.ProvincialQuadrant          AS OldProvincialQuadrant,
            deleted.RegDistrictDesc             AS OldRegDistrictDesc,
            deleted.RegOrTempDescr              AS OldRegOrTempDescr,
            deleted.ReportsTo                   AS OldReportsTo,
            deleted.Supervisor                  AS OldSupervisor,
            deleted.YearsEmpty                  AS OldYearsEmpty,

            inserted.BaseIncumbents             AS NewBaseIncumbents,
            inserted.BusinessUnitDescr          AS NewBusinessUnitDescr,
            inserted.City                       AS NewCity,
            inserted.ClassificationGroup        AS NewClassificationGroup,
            inserted.Core                       AS NewCore,
            inserted.CreateEffDt                AS NewCreateEffDt,
            inserted.DeptId                     AS NewDeptId,
            inserted.DeptIdDesc                 AS NewDeptIdDesc,
            inserted.DevelopmentRegion          AS NewDevelopmentRegion,
            inserted.EmptyEffDt                 AS NewEmptyEffDt,
            inserted.EmptyPosition              AS NewEmptyPosition,
            inserted.ExcludedOrIncluded         AS NewExcludedOrIncluded,
            inserted.IncumbentCount             AS NewIncumbentCount,
            inserted.Incumbents                 AS NewIncumbents,
            inserted.JobCode                    AS NewJobCode,
            inserted.JobCodeDesc                AS NewJobCodeDesc,
            inserted.JobFunc                    AS NewJobFunc,
            inserted.JobReqOpenDate             AS NewJobReqOpenDate,
            inserted.JobReqStatus               AS NewJobReqStatus,
            inserted.LastIncumbents             AS NewLastIncumbents,
            inserted.Location                   AS NewLocation,
            inserted.NocCode                    AS NewNocCode,
            inserted.NocCodeDescr               AS NewNocCodeDescr,
            inserted.Organization               AS NewOrganization,
            inserted.PosStatusDescr             AS NewPosStatusDescr,
            inserted.PositionEmptyGt1Year       AS NewPositionEmptyGt1Year,
            inserted.PositionHasBaseIncumbent   AS NewPositionHasBaseIncumbent,
            inserted.PositionTitle              AS NewPositionTitle,
            inserted.Program                    AS NewProgram,
            inserted.ProgramBranch              AS NewProgramBranch,
            inserted.ProgramDivision            AS NewProgramDivision,
            inserted.ProvincialQuadrant         AS NewProvincialQuadrant,
            inserted.RegDistrictDesc            AS NewRegDistrictDesc,
            inserted.RegOrTempDescr             AS NewRegOrTempDescr,
            inserted.ReportsTo                  AS NewReportsTo,
            inserted.Supervisor                 AS NewSupervisor,
            inserted.YearsEmpty                 AS NewYearsEmpty

        INTO dbo.Peoplesoft_EPC_Audit
        (
            RunId, ActionType, Position,
            OldRowHash, NewRowHash,
            OldIsActive, NewIsActive,
            OldBaseIncumbents,          NewBaseIncumbents,
            OldBusinessUnitDescr,       NewBusinessUnitDescr,
            OldCity,                    NewCity,
            OldClassificationGroup,     NewClassificationGroup,
            OldCore,                    NewCore,
            OldCreateEffDt,             NewCreateEffDt,
            OldDeptId,                  NewDeptId,
            OldDeptIdDesc,              NewDeptIdDesc,
            OldDevelopmentRegion,       NewDevelopmentRegion,
            OldEmptyEffDt,              NewEmptyEffDt,
            OldEmptyPosition,           NewEmptyPosition,
            OldExcludedOrIncluded,      NewExcludedOrIncluded,
            OldIncumbentCount,          NewIncumbentCount,
            OldIncumbents,              NewIncumbents,
            OldJobCode,                 NewJobCode,
            OldJobCodeDesc,             NewJobCodeDesc,
            OldJobFunc,                 NewJobFunc,
            OldJobReqOpenDate,          NewJobReqOpenDate,
            OldJobReqStatus,            NewJobReqStatus,
            OldLastIncumbents,          NewLastIncumbents,
            OldLocation,               NewLocation,
            OldNocCode,                 NewNocCode,
            OldNocCodeDescr,            NewNocCodeDescr,
            OldOrganization,            NewOrganization,
            OldPosStatusDescr,          NewPosStatusDescr,
            OldPositionEmptyGt1Year,    NewPositionEmptyGt1Year,
            OldPositionHasBaseIncumbent, NewPositionHasBaseIncumbent,
            OldPositionTitle,           NewPositionTitle,
            OldProgram,                 NewProgram,
            OldProgramBranch,           NewProgramBranch,
            OldProgramDivision,         NewProgramDivision,
            OldProvincialQuadrant,      NewProvincialQuadrant,
            OldRegDistrictDesc,         NewRegDistrictDesc,
            OldRegOrTempDescr,          NewRegOrTempDescr,
            OldReportsTo,              NewReportsTo,
            OldSupervisor,              NewSupervisor,
            OldYearsEmpty,              NewYearsEmpty
        );

        COMMIT TRAN;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
