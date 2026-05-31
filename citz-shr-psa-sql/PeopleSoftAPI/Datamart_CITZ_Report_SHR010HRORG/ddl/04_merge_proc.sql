SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_Merge_PeopleSoft_SHR010HRORG
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

    -- Row counts
    SELECT @StgCnt = COUNT(*) FROM dbo.Stg_Peoplesoft_SHR010HRORG;
    SELECT @TgtCnt = COUNT(*) FROM dbo.Peoplesoft_SHR010HRORG;

    ------------------------------------------------------------------------
    -- Guardrail 0: staging must not be empty unless forced
    ------------------------------------------------------------------------
    IF (@StgCnt = 0 AND @Force = 0)
        THROW 51000, 'MERGE aborted: staging table is empty (possible API failure). Use @Force=1 to override.', 1;

    ------------------------------------------------------------------------
    -- Guardrail 0b: business key must not be NULL or blank
    ------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM dbo.Stg_Peoplesoft_SHR010HRORG WHERE EmplId IS NULL OR EmplId = '')
        THROW 51001, 'MERGE aborted: staging contains NULL or blank EmplId.', 1;

    ------------------------------------------------------------------------
    -- Guardrail 1: rowcount variance (skip on first ever load)
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
        -- Guardrail 2: preview soft deletes (how many ACTIVE target rows are missing from source)
        --------------------------------------------------------------------
        DECLARE @WouldSoftDelete INT = 0;

        IF (@TgtCnt > 0)
        BEGIN
            SELECT @WouldSoftDelete = COUNT(*)
            FROM dbo.Peoplesoft_SHR010HRORG tgt
            LEFT JOIN dbo.Stg_Peoplesoft_SHR010HRORG src
                ON tgt.EmplId = src.EmplId
            WHERE src.EmplId IS NULL
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
        -- AsOfDate is excluded from all comparisons and HASHBYTES —
        -- it is identical for all rows per run and would cause false daily UPDATEs.
        --------------------------------------------------------------------
        ;MERGE dbo.Peoplesoft_SHR010HRORG WITH (HOLDLOCK) AS tgt
        USING dbo.Stg_Peoplesoft_SHR010HRORG AS src
            ON tgt.EmplId = src.EmplId

        -- UPDATE or REACTIVATE when matched and any data column differs
        WHEN MATCHED AND (
               tgt.IsActive = 0
            -- Employee identity
            OR ISNULL(tgt.Name,          '') <> ISNULL(src.Name,          '')
            OR ISNULL(tgt.Idir,          '') <> ISNULL(src.Idir,          '')
            OR ISNULL(tgt.EmailId,       '') <> ISNULL(src.EmailId,       '')
            OR ISNULL(tgt.EmplStatus,    '') <> ISNULL(src.EmplStatus,    '')
            OR ISNULL(tgt.EmplType,      '') <> ISNULL(src.EmplType,      '')
            OR ISNULL(tgt.EmplCtg,       '') <> ISNULL(src.EmplCtg,       '')
            OR ISNULL(tgt.EmplCtgL1,     '') <> ISNULL(src.EmplCtgL1,     '')
            OR ISNULL(tgt.EmplRcd,       -1) <> ISNULL(src.EmplRcd,       -1)
            OR ISNULL(tgt.ApptStatus,    '') <> ISNULL(src.ApptStatus,    '')
            OR ISNULL(tgt.ApptStatusCode,'') <> ISNULL(src.ApptStatusCode,'')
            -- Dates (NOT NULL columns: direct compare; nullable: CONVERT-based)
            OR tgt.Birthdate                <> src.Birthdate
            OR tgt.HireDt                   <> src.HireDt
            OR ISNULL(CONVERT(NVARCHAR(10), tgt.LastHireDt,              23), '') <> ISNULL(CONVERT(NVARCHAR(10), src.LastHireDt,              23), '')
            OR tgt.MostHistoricDate         <> src.MostHistoricDate
            OR tgt.FirstDateInOrganization  <> src.FirstDateInOrganization
            OR tgt.FirstDateInPosition      <> src.FirstDateInPosition
            OR ISNULL(CONVERT(NVARCHAR(10), tgt.FutureReturnDate,         23), '') <> ISNULL(CONVERT(NVARCHAR(10), src.FutureReturnDate,         23), '')
            -- Position / job
            OR ISNULL(tgt.PositionNbr,      '') <> ISNULL(src.PositionNbr,      '')
            OR ISNULL(tgt.TgbBasePosition,  '') <> ISNULL(src.TgbBasePosition,  '')
            OR ISNULL(tgt.PositionDataDescr,'') <> ISNULL(src.PositionDataDescr,'')
            OR ISNULL(tgt.JobCode,          '') <> ISNULL(src.JobCode,          '')
            OR ISNULL(tgt.JobCodeDescr,     '') <> ISNULL(src.JobCodeDescr,     '')
            OR ISNULL(tgt.JobFunction,      '') <> ISNULL(src.JobFunction,      '')
            OR ISNULL(tgt.SalAdminPlan,     '') <> ISNULL(src.SalAdminPlan,     '')
            OR ISNULL(tgt.Grade,            '') <> ISNULL(src.Grade,            '')
            OR ISNULL(tgt.Step,             -1) <> ISNULL(src.Step,             -1)
            OR ISNULL(tgt.StdHours,         -1) <> ISNULL(src.StdHours,         -1)
            -- Compensation
            OR ISNULL(tgt.AnnualRt,         -1) <> ISNULL(src.AnnualRt,         -1)
            OR ISNULL(tgt.CompRate,         -1) <> ISNULL(src.CompRate,         -1)
            OR ISNULL(tgt.HourlyRt,         -1) <> ISNULL(src.HourlyRt,         -1)
            -- Organization
            OR ISNULL(tgt.Organization,     '') <> ISNULL(src.Organization,     '')
            OR ISNULL(tgt.BusinessUnit,     '') <> ISNULL(src.BusinessUnit,     '')
            OR ISNULL(tgt.DeptId,           '') <> ISNULL(src.DeptId,           '')
            OR ISNULL(tgt.DeptDescr,        '') <> ISNULL(src.DeptDescr,        '')
            OR ISNULL(tgt.Level1,           '') <> ISNULL(src.Level1,           '')
            OR ISNULL(tgt.Level2,           '') <> ISNULL(src.Level2,           '')
            OR ISNULL(tgt.Level3,           '') <> ISNULL(src.Level3,           '')
            OR ISNULL(tgt.Descr,            '') <> ISNULL(src.Descr,            '')
            OR ISNULL(tgt.Core,             '') <> ISNULL(src.Core,             '')
            OR ISNULL(tgt.CoreGovernment,   '') <> ISNULL(src.CoreGovernment,   '')
            OR ISNULL(tgt.Sector,           '') <> ISNULL(src.Sector,           '')
            OR ISNULL(tgt.PublicService,    '') <> ISNULL(src.PublicService,    '')
            OR ISNULL(tgt.PublicServiceAct, '') <> ISNULL(src.PublicServiceAct, '')
            OR ISNULL(tgt.TreasuryBoard,    '') <> ISNULL(src.TreasuryBoard,    '')
            OR ISNULL(tgt.OfficerCode,      '') <> ISNULL(src.OfficerCode,      '')
            OR ISNULL(tgt.NocCode,          '') <> ISNULL(src.NocCode,          '')
            OR ISNULL(tgt.NocCodeDescr,     '') <> ISNULL(src.NocCodeDescr,     '')
            OR ISNULL(tgt.ReportsTo,        '') <> ISNULL(src.ReportsTo,        '')
            -- Location
            OR ISNULL(tgt.Location,         '') <> ISNULL(src.Location,         '')
            OR ISNULL(tgt.LocationCity,     '') <> ISNULL(src.LocationCity,     '')
            -- Demographics
            OR ISNULL(tgt.AgeGroup1,        '') <> ISNULL(src.AgeGroup1,        '')
            OR ISNULL(tgt.AgeGroup2,        '') <> ISNULL(src.AgeGroup2,        '')
            OR ISNULL(tgt.Age,              -1) <> ISNULL(src.Age,              -1)
            OR ISNULL(tgt.Generation,       '') <> ISNULL(src.Generation,       '')
            OR ISNULL(tgt.EligibleForPension,          '') <> ISNULL(src.EligibleForPension,          '')
            OR ISNULL(tgt.EligibleForUnreducedPension, '') <> ISNULL(src.EligibleForUnreducedPension, '')
            -- Supervisor
            OR ISNULL(tgt.Supervisor,       '') <> ISNULL(src.Supervisor,       '')
            OR ISNULL(tgt.SupervEmail,      '') <> ISNULL(src.SupervEmail,      '')
            OR ISNULL(tgt.SupervSalPlan,    '') <> ISNULL(src.SupervSalPlan,    '')
            OR ISNULL(tgt.SupervisorStatus, '') <> ISNULL(src.SupervisorStatus, '')
            -- Leave / layoff
            OR ISNULL(tgt.LayoffLeaveStopPayReason,    '') <> ISNULL(src.LayoffLeaveStopPayReason,    '')
            OR ISNULL(CONVERT(NVARCHAR(10), tgt.LayoffLeaveStopPayStartDate, 23), '') <> ISNULL(CONVERT(NVARCHAR(10), src.LayoffLeaveStopPayStartDate, 23), '')
        )
        THEN UPDATE SET
            Name                         = src.Name,
            Idir                         = src.Idir,
            EmailId                      = src.EmailId,
            EmplStatus                   = src.EmplStatus,
            EmplType                     = src.EmplType,
            EmplCtg                      = src.EmplCtg,
            EmplCtgL1                    = src.EmplCtgL1,
            EmplRcd                      = src.EmplRcd,
            ApptStatus                   = src.ApptStatus,
            ApptStatusCode               = src.ApptStatusCode,
            Birthdate                    = src.Birthdate,
            HireDt                       = src.HireDt,
            LastHireDt                   = src.LastHireDt,
            MostHistoricDate             = src.MostHistoricDate,
            FirstDateInOrganization      = src.FirstDateInOrganization,
            FirstDateInPosition          = src.FirstDateInPosition,
            FutureReturnDate             = src.FutureReturnDate,
            PositionNbr                  = src.PositionNbr,
            TgbBasePosition              = src.TgbBasePosition,
            PositionDataDescr            = src.PositionDataDescr,
            JobCode                      = src.JobCode,
            JobCodeDescr                 = src.JobCodeDescr,
            JobFunction                  = src.JobFunction,
            SalAdminPlan                 = src.SalAdminPlan,
            Grade                        = src.Grade,
            Step                         = src.Step,
            StdHours                     = src.StdHours,
            AnnualRt                     = src.AnnualRt,
            CompRate                     = src.CompRate,
            HourlyRt                     = src.HourlyRt,
            Organization                 = src.Organization,
            BusinessUnit                 = src.BusinessUnit,
            DeptId                       = src.DeptId,
            DeptDescr                    = src.DeptDescr,
            Level1                       = src.Level1,
            Level2                       = src.Level2,
            Level3                       = src.Level3,
            Descr                        = src.Descr,
            Core                         = src.Core,
            CoreGovernment               = src.CoreGovernment,
            Sector                       = src.Sector,
            PublicService                = src.PublicService,
            PublicServiceAct             = src.PublicServiceAct,
            TreasuryBoard                = src.TreasuryBoard,
            OfficerCode                  = src.OfficerCode,
            NocCode                      = src.NocCode,
            NocCodeDescr                 = src.NocCodeDescr,
            ReportsTo                    = src.ReportsTo,
            Location                     = src.Location,
            LocationCity                 = src.LocationCity,
            AgeGroup1                    = src.AgeGroup1,
            AgeGroup2                    = src.AgeGroup2,
            Age                          = src.Age,
            Generation                   = src.Generation,
            EligibleForPension           = src.EligibleForPension,
            EligibleForUnreducedPension  = src.EligibleForUnreducedPension,
            Supervisor                   = src.Supervisor,
            SupervEmail                  = src.SupervEmail,
            SupervSalPlan                = src.SupervSalPlan,
            SupervisorStatus             = src.SupervisorStatus,
            LayoffLeaveStopPayReason     = src.LayoffLeaveStopPayReason,
            LayoffLeaveStopPayStartDate  = src.LayoffLeaveStopPayStartDate,
            IsActive                     = 1,
            LastUpdatedUtc               = SYSUTCDATETIME()

        -- INSERT new employees
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            EmplId,
            Name, Idir, EmailId, EmplStatus, EmplType, EmplCtg, EmplCtgL1, EmplRcd,
            ApptStatus, ApptStatusCode,
            Birthdate, HireDt, LastHireDt, MostHistoricDate,
            FirstDateInOrganization, FirstDateInPosition, FutureReturnDate,
            PositionNbr, TgbBasePosition, PositionDataDescr,
            JobCode, JobCodeDescr, JobFunction, SalAdminPlan, Grade, Step, StdHours,
            AnnualRt, CompRate, HourlyRt,
            Organization, BusinessUnit, DeptId, DeptDescr,
            Level1, Level2, Level3, Descr, Core, CoreGovernment,
            Sector, PublicService, PublicServiceAct, TreasuryBoard,
            OfficerCode, NocCode, NocCodeDescr, ReportsTo,
            Location, LocationCity,
            AgeGroup1, AgeGroup2, Age, Generation,
            EligibleForPension, EligibleForUnreducedPension,
            Supervisor, SupervEmail, SupervSalPlan, SupervisorStatus,
            LayoffLeaveStopPayReason, LayoffLeaveStopPayStartDate,
            IsActive, CreatedUtc, LastUpdatedUtc
        )
        VALUES (
            src.EmplId,
            src.Name, src.Idir, src.EmailId, src.EmplStatus, src.EmplType,
            src.EmplCtg, src.EmplCtgL1, src.EmplRcd,
            src.ApptStatus, src.ApptStatusCode,
            src.Birthdate, src.HireDt, src.LastHireDt, src.MostHistoricDate,
            src.FirstDateInOrganization, src.FirstDateInPosition, src.FutureReturnDate,
            src.PositionNbr, src.TgbBasePosition, src.PositionDataDescr,
            src.JobCode, src.JobCodeDescr, src.JobFunction,
            src.SalAdminPlan, src.Grade, src.Step, src.StdHours,
            src.AnnualRt, src.CompRate, src.HourlyRt,
            src.Organization, src.BusinessUnit, src.DeptId, src.DeptDescr,
            src.Level1, src.Level2, src.Level3, src.Descr, src.Core, src.CoreGovernment,
            src.Sector, src.PublicService, src.PublicServiceAct, src.TreasuryBoard,
            src.OfficerCode, src.NocCode, src.NocCodeDescr, src.ReportsTo,
            src.Location, src.LocationCity,
            src.AgeGroup1, src.AgeGroup2, src.Age, src.Generation,
            src.EligibleForPension, src.EligibleForUnreducedPension,
            src.Supervisor, src.SupervEmail, src.SupervSalPlan, src.SupervisorStatus,
            src.LayoffLeaveStopPayReason, src.LayoffLeaveStopPayStartDate,
            1, SYSUTCDATETIME(), SYSUTCDATETIME()
        )

        -- SOFT DELETE: employee no longer in source
        WHEN NOT MATCHED BY SOURCE AND tgt.IsActive = 1
        THEN UPDATE SET
            IsActive       = 0,
            LastUpdatedUtc = SYSUTCDATETIME()

        OUTPUT
            @RunId AS RunId,
            CASE
                WHEN $action = 'UPDATE' AND deleted.IsActive = 1 AND inserted.IsActive = 0 THEN 'SOFT_DELETE'
                WHEN $action = 'UPDATE' AND deleted.IsActive = 0 AND inserted.IsActive = 1 THEN 'REACTIVATE'
                ELSE $action
            END AS ActionType,
            COALESCE(inserted.EmplId, deleted.EmplId) AS EmplId,

            -- Old row hash (62 data columns; AsOfDate excluded)
            HASHBYTES('SHA2_256', CONCAT_WS('|',
                COALESCE(deleted.Name,          ''), COALESCE(deleted.Idir,          ''),
                COALESCE(deleted.EmailId,       ''), COALESCE(deleted.EmplStatus,    ''),
                COALESCE(deleted.EmplType,      ''), COALESCE(deleted.EmplCtg,       ''),
                COALESCE(deleted.EmplCtgL1,     ''),
                COALESCE(CONVERT(NVARCHAR(20), deleted.EmplRcd),  ''),
                COALESCE(deleted.ApptStatus,    ''), COALESCE(deleted.ApptStatusCode,''),
                CONVERT(NVARCHAR(10), deleted.Birthdate,               23),
                CONVERT(NVARCHAR(10), deleted.HireDt,                  23),
                COALESCE(CONVERT(NVARCHAR(10), deleted.LastHireDt,     23), ''),
                CONVERT(NVARCHAR(10), deleted.MostHistoricDate,         23),
                CONVERT(NVARCHAR(10), deleted.FirstDateInOrganization,  23),
                CONVERT(NVARCHAR(10), deleted.FirstDateInPosition,      23),
                COALESCE(CONVERT(NVARCHAR(10), deleted.FutureReturnDate,23), ''),
                COALESCE(deleted.PositionNbr,       ''), COALESCE(deleted.TgbBasePosition,  ''),
                COALESCE(deleted.PositionDataDescr, ''), COALESCE(deleted.JobCode,          ''),
                COALESCE(deleted.JobCodeDescr,      ''), COALESCE(deleted.JobFunction,      ''),
                COALESCE(deleted.SalAdminPlan,      ''), COALESCE(deleted.Grade,            ''),
                COALESCE(CONVERT(NVARCHAR(20), deleted.Step),     ''),
                COALESCE(CONVERT(NVARCHAR(20), deleted.StdHours), ''),
                COALESCE(CONVERT(NVARCHAR(30), deleted.AnnualRt), ''),
                COALESCE(CONVERT(NVARCHAR(30), deleted.CompRate),  ''),
                COALESCE(CONVERT(NVARCHAR(30), deleted.HourlyRt),  ''),
                COALESCE(deleted.Organization,  ''), COALESCE(deleted.BusinessUnit,    ''),
                COALESCE(deleted.DeptId,        ''), COALESCE(deleted.DeptDescr,       ''),
                COALESCE(deleted.Level1,        ''), COALESCE(deleted.Level2,          ''),
                COALESCE(deleted.Level3,        ''), COALESCE(deleted.Descr,           ''),
                COALESCE(deleted.Core,          ''), COALESCE(deleted.CoreGovernment,  ''),
                COALESCE(deleted.Sector,        ''), COALESCE(deleted.PublicService,   ''),
                COALESCE(deleted.PublicServiceAct,''), COALESCE(deleted.TreasuryBoard, ''),
                COALESCE(deleted.OfficerCode,   ''), COALESCE(deleted.NocCode,         ''),
                COALESCE(deleted.NocCodeDescr,  ''), COALESCE(deleted.ReportsTo,       ''),
                COALESCE(deleted.Location,      ''), COALESCE(deleted.LocationCity,    ''),
                COALESCE(deleted.AgeGroup1,     ''), COALESCE(deleted.AgeGroup2,       ''),
                COALESCE(CONVERT(NVARCHAR(20), deleted.Age), ''),
                COALESCE(deleted.Generation,    ''),
                COALESCE(deleted.EligibleForPension,          ''),
                COALESCE(deleted.EligibleForUnreducedPension, ''),
                COALESCE(deleted.Supervisor,    ''), COALESCE(deleted.SupervEmail,     ''),
                COALESCE(deleted.SupervSalPlan, ''), COALESCE(deleted.SupervisorStatus,''),
                COALESCE(deleted.LayoffLeaveStopPayReason,    ''),
                COALESCE(CONVERT(NVARCHAR(10), deleted.LayoffLeaveStopPayStartDate, 23), ''),
                COALESCE(CONVERT(NVARCHAR(1), deleted.IsActive), '')
            )) AS OldRowHash,

            -- New row hash (same columns)
            HASHBYTES('SHA2_256', CONCAT_WS('|',
                COALESCE(inserted.Name,          ''), COALESCE(inserted.Idir,          ''),
                COALESCE(inserted.EmailId,       ''), COALESCE(inserted.EmplStatus,    ''),
                COALESCE(inserted.EmplType,      ''), COALESCE(inserted.EmplCtg,       ''),
                COALESCE(inserted.EmplCtgL1,     ''),
                COALESCE(CONVERT(NVARCHAR(20), inserted.EmplRcd),  ''),
                COALESCE(inserted.ApptStatus,    ''), COALESCE(inserted.ApptStatusCode,''),
                CONVERT(NVARCHAR(10), inserted.Birthdate,               23),
                CONVERT(NVARCHAR(10), inserted.HireDt,                  23),
                COALESCE(CONVERT(NVARCHAR(10), inserted.LastHireDt,     23), ''),
                CONVERT(NVARCHAR(10), inserted.MostHistoricDate,         23),
                CONVERT(NVARCHAR(10), inserted.FirstDateInOrganization,  23),
                CONVERT(NVARCHAR(10), inserted.FirstDateInPosition,      23),
                COALESCE(CONVERT(NVARCHAR(10), inserted.FutureReturnDate,23), ''),
                COALESCE(inserted.PositionNbr,       ''), COALESCE(inserted.TgbBasePosition,  ''),
                COALESCE(inserted.PositionDataDescr, ''), COALESCE(inserted.JobCode,          ''),
                COALESCE(inserted.JobCodeDescr,      ''), COALESCE(inserted.JobFunction,      ''),
                COALESCE(inserted.SalAdminPlan,      ''), COALESCE(inserted.Grade,            ''),
                COALESCE(CONVERT(NVARCHAR(20), inserted.Step),     ''),
                COALESCE(CONVERT(NVARCHAR(20), inserted.StdHours), ''),
                COALESCE(CONVERT(NVARCHAR(30), inserted.AnnualRt), ''),
                COALESCE(CONVERT(NVARCHAR(30), inserted.CompRate),  ''),
                COALESCE(CONVERT(NVARCHAR(30), inserted.HourlyRt),  ''),
                COALESCE(inserted.Organization,  ''), COALESCE(inserted.BusinessUnit,    ''),
                COALESCE(inserted.DeptId,        ''), COALESCE(inserted.DeptDescr,       ''),
                COALESCE(inserted.Level1,        ''), COALESCE(inserted.Level2,          ''),
                COALESCE(inserted.Level3,        ''), COALESCE(inserted.Descr,           ''),
                COALESCE(inserted.Core,          ''), COALESCE(inserted.CoreGovernment,  ''),
                COALESCE(inserted.Sector,        ''), COALESCE(inserted.PublicService,   ''),
                COALESCE(inserted.PublicServiceAct,''), COALESCE(inserted.TreasuryBoard, ''),
                COALESCE(inserted.OfficerCode,   ''), COALESCE(inserted.NocCode,         ''),
                COALESCE(inserted.NocCodeDescr,  ''), COALESCE(inserted.ReportsTo,       ''),
                COALESCE(inserted.Location,      ''), COALESCE(inserted.LocationCity,    ''),
                COALESCE(inserted.AgeGroup1,     ''), COALESCE(inserted.AgeGroup2,       ''),
                COALESCE(CONVERT(NVARCHAR(20), inserted.Age), ''),
                COALESCE(inserted.Generation,    ''),
                COALESCE(inserted.EligibleForPension,          ''),
                COALESCE(inserted.EligibleForUnreducedPension, ''),
                COALESCE(inserted.Supervisor,    ''), COALESCE(inserted.SupervEmail,     ''),
                COALESCE(inserted.SupervSalPlan, ''), COALESCE(inserted.SupervisorStatus,''),
                COALESCE(inserted.LayoffLeaveStopPayReason,    ''),
                COALESCE(CONVERT(NVARCHAR(10), inserted.LayoffLeaveStopPayStartDate, 23), ''),
                COALESCE(CONVERT(NVARCHAR(1), inserted.IsActive), '')
            )) AS NewRowHash,

            deleted.IsActive  AS OldIsActive,
            inserted.IsActive AS NewIsActive,

            -- Old values
            deleted.Name                         AS OldName,
            deleted.Idir                         AS OldIdir,
            deleted.EmailId                      AS OldEmailId,
            deleted.EmplStatus                   AS OldEmplStatus,
            deleted.EmplType                     AS OldEmplType,
            deleted.EmplCtg                      AS OldEmplCtg,
            deleted.EmplCtgL1                    AS OldEmplCtgL1,
            deleted.EmplRcd                      AS OldEmplRcd,
            deleted.ApptStatus                   AS OldApptStatus,
            deleted.ApptStatusCode               AS OldApptStatusCode,
            deleted.Birthdate                    AS OldBirthdate,
            deleted.HireDt                       AS OldHireDt,
            deleted.LastHireDt                   AS OldLastHireDt,
            deleted.MostHistoricDate             AS OldMostHistoricDate,
            deleted.FirstDateInOrganization      AS OldFirstDateInOrganization,
            deleted.FirstDateInPosition          AS OldFirstDateInPosition,
            deleted.FutureReturnDate             AS OldFutureReturnDate,
            deleted.PositionNbr                  AS OldPositionNbr,
            deleted.TgbBasePosition              AS OldTgbBasePosition,
            deleted.PositionDataDescr            AS OldPositionDataDescr,
            deleted.JobCode                      AS OldJobCode,
            deleted.JobCodeDescr                 AS OldJobCodeDescr,
            deleted.JobFunction                  AS OldJobFunction,
            deleted.SalAdminPlan                 AS OldSalAdminPlan,
            deleted.Grade                        AS OldGrade,
            deleted.Step                         AS OldStep,
            deleted.StdHours                     AS OldStdHours,
            deleted.AnnualRt                     AS OldAnnualRt,
            deleted.CompRate                     AS OldCompRate,
            deleted.HourlyRt                     AS OldHourlyRt,
            deleted.Organization                 AS OldOrganization,
            deleted.BusinessUnit                 AS OldBusinessUnit,
            deleted.DeptId                       AS OldDeptId,
            deleted.DeptDescr                    AS OldDeptDescr,
            deleted.Level1                       AS OldLevel1,
            deleted.Level2                       AS OldLevel2,
            deleted.Level3                       AS OldLevel3,
            deleted.Descr                        AS OldDescr,
            deleted.Core                         AS OldCore,
            deleted.CoreGovernment               AS OldCoreGovernment,
            deleted.Sector                       AS OldSector,
            deleted.PublicService                AS OldPublicService,
            deleted.PublicServiceAct             AS OldPublicServiceAct,
            deleted.TreasuryBoard                AS OldTreasuryBoard,
            deleted.OfficerCode                  AS OldOfficerCode,
            deleted.NocCode                      AS OldNocCode,
            deleted.NocCodeDescr                 AS OldNocCodeDescr,
            deleted.ReportsTo                    AS OldReportsTo,
            deleted.Location                     AS OldLocation,
            deleted.LocationCity                 AS OldLocationCity,
            deleted.AgeGroup1                    AS OldAgeGroup1,
            deleted.AgeGroup2                    AS OldAgeGroup2,
            deleted.Age                          AS OldAge,
            deleted.Generation                   AS OldGeneration,
            deleted.EligibleForPension           AS OldEligibleForPension,
            deleted.EligibleForUnreducedPension  AS OldEligibleForUnreducedPension,
            deleted.Supervisor                   AS OldSupervisor,
            deleted.SupervEmail                  AS OldSupervEmail,
            deleted.SupervSalPlan                AS OldSupervSalPlan,
            deleted.SupervisorStatus             AS OldSupervisorStatus,
            deleted.LayoffLeaveStopPayReason     AS OldLayoffLeaveStopPayReason,
            deleted.LayoffLeaveStopPayStartDate  AS OldLayoffLeaveStopPayStartDate,

            -- New values
            inserted.Name                         AS NewName,
            inserted.Idir                         AS NewIdir,
            inserted.EmailId                      AS NewEmailId,
            inserted.EmplStatus                   AS NewEmplStatus,
            inserted.EmplType                     AS NewEmplType,
            inserted.EmplCtg                      AS NewEmplCtg,
            inserted.EmplCtgL1                    AS NewEmplCtgL1,
            inserted.EmplRcd                      AS NewEmplRcd,
            inserted.ApptStatus                   AS NewApptStatus,
            inserted.ApptStatusCode               AS NewApptStatusCode,
            inserted.Birthdate                    AS NewBirthdate,
            inserted.HireDt                       AS NewHireDt,
            inserted.LastHireDt                   AS NewLastHireDt,
            inserted.MostHistoricDate             AS NewMostHistoricDate,
            inserted.FirstDateInOrganization      AS NewFirstDateInOrganization,
            inserted.FirstDateInPosition          AS NewFirstDateInPosition,
            inserted.FutureReturnDate             AS NewFutureReturnDate,
            inserted.PositionNbr                  AS NewPositionNbr,
            inserted.TgbBasePosition              AS NewTgbBasePosition,
            inserted.PositionDataDescr            AS NewPositionDataDescr,
            inserted.JobCode                      AS NewJobCode,
            inserted.JobCodeDescr                 AS NewJobCodeDescr,
            inserted.JobFunction                  AS NewJobFunction,
            inserted.SalAdminPlan                 AS NewSalAdminPlan,
            inserted.Grade                        AS NewGrade,
            inserted.Step                         AS NewStep,
            inserted.StdHours                     AS NewStdHours,
            inserted.AnnualRt                     AS NewAnnualRt,
            inserted.CompRate                     AS NewCompRate,
            inserted.HourlyRt                     AS NewHourlyRt,
            inserted.Organization                 AS NewOrganization,
            inserted.BusinessUnit                 AS NewBusinessUnit,
            inserted.DeptId                       AS NewDeptId,
            inserted.DeptDescr                    AS NewDeptDescr,
            inserted.Level1                       AS NewLevel1,
            inserted.Level2                       AS NewLevel2,
            inserted.Level3                       AS NewLevel3,
            inserted.Descr                        AS NewDescr,
            inserted.Core                         AS NewCore,
            inserted.CoreGovernment               AS NewCoreGovernment,
            inserted.Sector                       AS NewSector,
            inserted.PublicService                AS NewPublicService,
            inserted.PublicServiceAct             AS NewPublicServiceAct,
            inserted.TreasuryBoard                AS NewTreasuryBoard,
            inserted.OfficerCode                  AS NewOfficerCode,
            inserted.NocCode                      AS NewNocCode,
            inserted.NocCodeDescr                 AS NewNocCodeDescr,
            inserted.ReportsTo                    AS NewReportsTo,
            inserted.Location                     AS NewLocation,
            inserted.LocationCity                 AS NewLocationCity,
            inserted.AgeGroup1                    AS NewAgeGroup1,
            inserted.AgeGroup2                    AS NewAgeGroup2,
            inserted.Age                          AS NewAge,
            inserted.Generation                   AS NewGeneration,
            inserted.EligibleForPension           AS NewEligibleForPension,
            inserted.EligibleForUnreducedPension  AS NewEligibleForUnreducedPension,
            inserted.Supervisor                   AS NewSupervisor,
            inserted.SupervEmail                  AS NewSupervEmail,
            inserted.SupervSalPlan                AS NewSupervSalPlan,
            inserted.SupervisorStatus             AS NewSupervisorStatus,
            inserted.LayoffLeaveStopPayReason     AS NewLayoffLeaveStopPayReason,
            inserted.LayoffLeaveStopPayStartDate  AS NewLayoffLeaveStopPayStartDate

        INTO dbo.Peoplesoft_SHR010HRORG_Audit
        (
            RunId, ActionType, EmplId,
            OldRowHash, NewRowHash,
            OldIsActive, NewIsActive,
            OldName, OldIdir, OldEmailId, OldEmplStatus, OldEmplType,
            OldEmplCtg, OldEmplCtgL1, OldEmplRcd, OldApptStatus, OldApptStatusCode,
            OldBirthdate, OldHireDt, OldLastHireDt, OldMostHistoricDate,
            OldFirstDateInOrganization, OldFirstDateInPosition, OldFutureReturnDate,
            OldPositionNbr, OldTgbBasePosition, OldPositionDataDescr,
            OldJobCode, OldJobCodeDescr, OldJobFunction,
            OldSalAdminPlan, OldGrade, OldStep, OldStdHours,
            OldAnnualRt, OldCompRate, OldHourlyRt,
            OldOrganization, OldBusinessUnit, OldDeptId, OldDeptDescr,
            OldLevel1, OldLevel2, OldLevel3, OldDescr, OldCore, OldCoreGovernment,
            OldSector, OldPublicService, OldPublicServiceAct, OldTreasuryBoard,
            OldOfficerCode, OldNocCode, OldNocCodeDescr, OldReportsTo,
            OldLocation, OldLocationCity,
            OldAgeGroup1, OldAgeGroup2, OldAge, OldGeneration,
            OldEligibleForPension, OldEligibleForUnreducedPension,
            OldSupervisor, OldSupervEmail, OldSupervSalPlan, OldSupervisorStatus,
            OldLayoffLeaveStopPayReason, OldLayoffLeaveStopPayStartDate,
            NewName, NewIdir, NewEmailId, NewEmplStatus, NewEmplType,
            NewEmplCtg, NewEmplCtgL1, NewEmplRcd, NewApptStatus, NewApptStatusCode,
            NewBirthdate, NewHireDt, NewLastHireDt, NewMostHistoricDate,
            NewFirstDateInOrganization, NewFirstDateInPosition, NewFutureReturnDate,
            NewPositionNbr, NewTgbBasePosition, NewPositionDataDescr,
            NewJobCode, NewJobCodeDescr, NewJobFunction,
            NewSalAdminPlan, NewGrade, NewStep, NewStdHours,
            NewAnnualRt, NewCompRate, NewHourlyRt,
            NewOrganization, NewBusinessUnit, NewDeptId, NewDeptDescr,
            NewLevel1, NewLevel2, NewLevel3, NewDescr, NewCore, NewCoreGovernment,
            NewSector, NewPublicService, NewPublicServiceAct, NewTreasuryBoard,
            NewOfficerCode, NewNocCode, NewNocCodeDescr, NewReportsTo,
            NewLocation, NewLocationCity,
            NewAgeGroup1, NewAgeGroup2, NewAge, NewGeneration,
            NewEligibleForPension, NewEligibleForUnreducedPension,
            NewSupervisor, NewSupervEmail, NewSupervSalPlan, NewSupervisorStatus,
            NewLayoffLeaveStopPayReason, NewLayoffLeaveStopPayStartDate
        );

        COMMIT;

        -- Return a concise run summary (handy for R logging)
        SELECT
            @RunId AS RunId,
            @StgCnt AS StagingRows,
            @TgtCnt AS TargetRows_Before,
            @WouldSoftDelete AS WouldSoftDelete_Preview,
            (SELECT COUNT(*) FROM dbo.Peoplesoft_SHR010HRORG) AS TargetRows_After,
            (SELECT COUNT(*) FROM dbo.Peoplesoft_SHR010HRORG_Audit WHERE RunId = @RunId) AS AuditEvents;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO
