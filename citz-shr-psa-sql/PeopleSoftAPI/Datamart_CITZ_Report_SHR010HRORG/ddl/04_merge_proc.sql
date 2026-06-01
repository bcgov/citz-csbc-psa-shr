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

            CAST(deleted.IsActive  AS NVARCHAR(255)) AS OldIsActive,
            CAST(inserted.IsActive AS NVARCHAR(255)) AS NewIsActive,

            -- Old values (all CAST to NVARCHAR(255))
            CAST(deleted.Name                         AS NVARCHAR(255)) AS OldName,
            CAST(deleted.Idir                         AS NVARCHAR(255)) AS OldIdir,
            CAST(deleted.EmailId                      AS NVARCHAR(255)) AS OldEmailId,
            CAST(deleted.EmplStatus                   AS NVARCHAR(255)) AS OldEmplStatus,
            CAST(deleted.EmplType                     AS NVARCHAR(255)) AS OldEmplType,
            CAST(deleted.EmplCtg                      AS NVARCHAR(255)) AS OldEmplCtg,
            CAST(deleted.EmplCtgL1                    AS NVARCHAR(255)) AS OldEmplCtgL1,
            CAST(deleted.EmplRcd                      AS NVARCHAR(255)) AS OldEmplRcd,
            CAST(deleted.ApptStatus                   AS NVARCHAR(255)) AS OldApptStatus,
            CAST(deleted.ApptStatusCode               AS NVARCHAR(255)) AS OldApptStatusCode,
            CONVERT(NVARCHAR(255), deleted.Birthdate,                23) AS OldBirthdate,
            CONVERT(NVARCHAR(255), deleted.HireDt,                   23) AS OldHireDt,
            CONVERT(NVARCHAR(255), deleted.LastHireDt,               23) AS OldLastHireDt,
            CONVERT(NVARCHAR(255), deleted.MostHistoricDate,         23) AS OldMostHistoricDate,
            CONVERT(NVARCHAR(255), deleted.FirstDateInOrganization,  23) AS OldFirstDateInOrganization,
            CONVERT(NVARCHAR(255), deleted.FirstDateInPosition,      23) AS OldFirstDateInPosition,
            CONVERT(NVARCHAR(255), deleted.FutureReturnDate,         23) AS OldFutureReturnDate,
            CAST(deleted.PositionNbr                  AS NVARCHAR(255)) AS OldPositionNbr,
            CAST(deleted.TgbBasePosition              AS NVARCHAR(255)) AS OldTgbBasePosition,
            CAST(deleted.PositionDataDescr            AS NVARCHAR(255)) AS OldPositionDataDescr,
            CAST(deleted.JobCode                      AS NVARCHAR(255)) AS OldJobCode,
            CAST(deleted.JobCodeDescr                 AS NVARCHAR(255)) AS OldJobCodeDescr,
            CAST(deleted.JobFunction                  AS NVARCHAR(255)) AS OldJobFunction,
            CAST(deleted.SalAdminPlan                 AS NVARCHAR(255)) AS OldSalAdminPlan,
            CAST(deleted.Grade                        AS NVARCHAR(255)) AS OldGrade,
            CAST(deleted.Step                         AS NVARCHAR(255)) AS OldStep,
            CAST(deleted.StdHours                     AS NVARCHAR(255)) AS OldStdHours,
            CAST(deleted.AnnualRt                     AS NVARCHAR(255)) AS OldAnnualRt,
            CAST(deleted.CompRate                     AS NVARCHAR(255)) AS OldCompRate,
            CAST(deleted.HourlyRt                     AS NVARCHAR(255)) AS OldHourlyRt,
            CAST(deleted.Organization                 AS NVARCHAR(255)) AS OldOrganization,
            CAST(deleted.BusinessUnit                 AS NVARCHAR(255)) AS OldBusinessUnit,
            CAST(deleted.DeptId                       AS NVARCHAR(255)) AS OldDeptId,
            CAST(deleted.DeptDescr                    AS NVARCHAR(255)) AS OldDeptDescr,
            CAST(deleted.Level1                       AS NVARCHAR(255)) AS OldLevel1,
            CAST(deleted.Level2                       AS NVARCHAR(255)) AS OldLevel2,
            CAST(deleted.Level3                       AS NVARCHAR(255)) AS OldLevel3,
            CAST(deleted.Descr                        AS NVARCHAR(255)) AS OldDescr,
            CAST(deleted.Core                         AS NVARCHAR(255)) AS OldCore,
            CAST(deleted.CoreGovernment               AS NVARCHAR(255)) AS OldCoreGovernment,
            CAST(deleted.Sector                       AS NVARCHAR(255)) AS OldSector,
            CAST(deleted.PublicService                AS NVARCHAR(255)) AS OldPublicService,
            CAST(deleted.PublicServiceAct             AS NVARCHAR(255)) AS OldPublicServiceAct,
            CAST(deleted.TreasuryBoard                AS NVARCHAR(255)) AS OldTreasuryBoard,
            CAST(deleted.OfficerCode                  AS NVARCHAR(255)) AS OldOfficerCode,
            CAST(deleted.NocCode                      AS NVARCHAR(255)) AS OldNocCode,
            CAST(deleted.NocCodeDescr                 AS NVARCHAR(255)) AS OldNocCodeDescr,
            CAST(deleted.ReportsTo                    AS NVARCHAR(255)) AS OldReportsTo,
            CAST(deleted.Location                     AS NVARCHAR(255)) AS OldLocation,
            CAST(deleted.LocationCity                 AS NVARCHAR(255)) AS OldLocationCity,
            CAST(deleted.AgeGroup1                    AS NVARCHAR(255)) AS OldAgeGroup1,
            CAST(deleted.AgeGroup2                    AS NVARCHAR(255)) AS OldAgeGroup2,
            CAST(deleted.Age                          AS NVARCHAR(255)) AS OldAge,
            CAST(deleted.Generation                   AS NVARCHAR(255)) AS OldGeneration,
            CAST(deleted.EligibleForPension           AS NVARCHAR(255)) AS OldEligibleForPension,
            CAST(deleted.EligibleForUnreducedPension  AS NVARCHAR(255)) AS OldEligibleForUnreducedPension,
            CAST(deleted.Supervisor                   AS NVARCHAR(255)) AS OldSupervisor,
            CAST(deleted.SupervEmail                  AS NVARCHAR(255)) AS OldSupervEmail,
            CAST(deleted.SupervSalPlan                AS NVARCHAR(255)) AS OldSupervSalPlan,
            CAST(deleted.SupervisorStatus             AS NVARCHAR(255)) AS OldSupervisorStatus,
            CAST(deleted.LayoffLeaveStopPayReason     AS NVARCHAR(255)) AS OldLayoffLeaveStopPayReason,
            CONVERT(NVARCHAR(255), deleted.LayoffLeaveStopPayStartDate, 23) AS OldLayoffLeaveStopPayStartDate,

            -- New values (all CAST to NVARCHAR(255))
            CAST(inserted.Name                         AS NVARCHAR(255)) AS NewName,
            CAST(inserted.Idir                         AS NVARCHAR(255)) AS NewIdir,
            CAST(inserted.EmailId                      AS NVARCHAR(255)) AS NewEmailId,
            CAST(inserted.EmplStatus                   AS NVARCHAR(255)) AS NewEmplStatus,
            CAST(inserted.EmplType                     AS NVARCHAR(255)) AS NewEmplType,
            CAST(inserted.EmplCtg                      AS NVARCHAR(255)) AS NewEmplCtg,
            CAST(inserted.EmplCtgL1                    AS NVARCHAR(255)) AS NewEmplCtgL1,
            CAST(inserted.EmplRcd                      AS NVARCHAR(255)) AS NewEmplRcd,
            CAST(inserted.ApptStatus                   AS NVARCHAR(255)) AS NewApptStatus,
            CAST(inserted.ApptStatusCode               AS NVARCHAR(255)) AS NewApptStatusCode,
            CONVERT(NVARCHAR(255), inserted.Birthdate,                23) AS NewBirthdate,
            CONVERT(NVARCHAR(255), inserted.HireDt,                   23) AS NewHireDt,
            CONVERT(NVARCHAR(255), inserted.LastHireDt,               23) AS NewLastHireDt,
            CONVERT(NVARCHAR(255), inserted.MostHistoricDate,         23) AS NewMostHistoricDate,
            CONVERT(NVARCHAR(255), inserted.FirstDateInOrganization,  23) AS NewFirstDateInOrganization,
            CONVERT(NVARCHAR(255), inserted.FirstDateInPosition,      23) AS NewFirstDateInPosition,
            CONVERT(NVARCHAR(255), inserted.FutureReturnDate,         23) AS NewFutureReturnDate,
            CAST(inserted.PositionNbr                  AS NVARCHAR(255)) AS NewPositionNbr,
            CAST(inserted.TgbBasePosition              AS NVARCHAR(255)) AS NewTgbBasePosition,
            CAST(inserted.PositionDataDescr            AS NVARCHAR(255)) AS NewPositionDataDescr,
            CAST(inserted.JobCode                      AS NVARCHAR(255)) AS NewJobCode,
            CAST(inserted.JobCodeDescr                 AS NVARCHAR(255)) AS NewJobCodeDescr,
            CAST(inserted.JobFunction                  AS NVARCHAR(255)) AS NewJobFunction,
            CAST(inserted.SalAdminPlan                 AS NVARCHAR(255)) AS NewSalAdminPlan,
            CAST(inserted.Grade                        AS NVARCHAR(255)) AS NewGrade,
            CAST(inserted.Step                         AS NVARCHAR(255)) AS NewStep,
            CAST(inserted.StdHours                     AS NVARCHAR(255)) AS NewStdHours,
            CAST(inserted.AnnualRt                     AS NVARCHAR(255)) AS NewAnnualRt,
            CAST(inserted.CompRate                     AS NVARCHAR(255)) AS NewCompRate,
            CAST(inserted.HourlyRt                     AS NVARCHAR(255)) AS NewHourlyRt,
            CAST(inserted.Organization                 AS NVARCHAR(255)) AS NewOrganization,
            CAST(inserted.BusinessUnit                 AS NVARCHAR(255)) AS NewBusinessUnit,
            CAST(inserted.DeptId                       AS NVARCHAR(255)) AS NewDeptId,
            CAST(inserted.DeptDescr                    AS NVARCHAR(255)) AS NewDeptDescr,
            CAST(inserted.Level1                       AS NVARCHAR(255)) AS NewLevel1,
            CAST(inserted.Level2                       AS NVARCHAR(255)) AS NewLevel2,
            CAST(inserted.Level3                       AS NVARCHAR(255)) AS NewLevel3,
            CAST(inserted.Descr                        AS NVARCHAR(255)) AS NewDescr,
            CAST(inserted.Core                         AS NVARCHAR(255)) AS NewCore,
            CAST(inserted.CoreGovernment               AS NVARCHAR(255)) AS NewCoreGovernment,
            CAST(inserted.Sector                       AS NVARCHAR(255)) AS NewSector,
            CAST(inserted.PublicService                AS NVARCHAR(255)) AS NewPublicService,
            CAST(inserted.PublicServiceAct             AS NVARCHAR(255)) AS NewPublicServiceAct,
            CAST(inserted.TreasuryBoard                AS NVARCHAR(255)) AS NewTreasuryBoard,
            CAST(inserted.OfficerCode                  AS NVARCHAR(255)) AS NewOfficerCode,
            CAST(inserted.NocCode                      AS NVARCHAR(255)) AS NewNocCode,
            CAST(inserted.NocCodeDescr                 AS NVARCHAR(255)) AS NewNocCodeDescr,
            CAST(inserted.ReportsTo                    AS NVARCHAR(255)) AS NewReportsTo,
            CAST(inserted.Location                     AS NVARCHAR(255)) AS NewLocation,
            CAST(inserted.LocationCity                 AS NVARCHAR(255)) AS NewLocationCity,
            CAST(inserted.AgeGroup1                    AS NVARCHAR(255)) AS NewAgeGroup1,
            CAST(inserted.AgeGroup2                    AS NVARCHAR(255)) AS NewAgeGroup2,
            CAST(inserted.Age                          AS NVARCHAR(255)) AS NewAge,
            CAST(inserted.Generation                   AS NVARCHAR(255)) AS NewGeneration,
            CAST(inserted.EligibleForPension           AS NVARCHAR(255)) AS NewEligibleForPension,
            CAST(inserted.EligibleForUnreducedPension  AS NVARCHAR(255)) AS NewEligibleForUnreducedPension,
            CAST(inserted.Supervisor                   AS NVARCHAR(255)) AS NewSupervisor,
            CAST(inserted.SupervEmail                  AS NVARCHAR(255)) AS NewSupervEmail,
            CAST(inserted.SupervSalPlan                AS NVARCHAR(255)) AS NewSupervSalPlan,
            CAST(inserted.SupervisorStatus             AS NVARCHAR(255)) AS NewSupervisorStatus,
            CAST(inserted.LayoffLeaveStopPayReason     AS NVARCHAR(255)) AS NewLayoffLeaveStopPayReason,
            CONVERT(NVARCHAR(255), inserted.LayoffLeaveStopPayStartDate, 23) AS NewLayoffLeaveStopPayStartDate

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
