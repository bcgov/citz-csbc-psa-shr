SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_Merge_PeopleSoft_SO001HRORG
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
    SELECT @StgCnt = COUNT(*) FROM dbo.Stg_Peoplesoft_SO001HRORG;
    SELECT @TgtCnt = COUNT(*) FROM dbo.Peoplesoft_SO001HRORG;

    ------------------------------------------------------------------------
    -- Guardrail 0: staging must not be empty unless forced
    ------------------------------------------------------------------------
    IF (@StgCnt = 0 AND @Force = 0)
        THROW 51000, 'MERGE aborted: staging table is empty (possible API failure). Use @Force=1 to override.', 1;

    ------------------------------------------------------------------------
    -- Guardrail 0b: business key must not be NULL
    ------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM dbo.Stg_Peoplesoft_SO001HRORG WHERE PosPosition IS NULL)
        THROW 51001, 'MERGE aborted: staging contains NULL PosPosition.', 1;

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
            FROM dbo.Peoplesoft_SO001HRORG tgt
            LEFT JOIN dbo.Stg_Peoplesoft_SO001HRORG src
                ON  src.PosPosition         = tgt.PosPosition
                AND ISNULL(src.EmplId, '') = ISNULL(tgt.EmplId, '')
            WHERE src.PosPosition IS NULL
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
        ;MERGE dbo.Peoplesoft_SO001HRORG WITH (HOLDLOCK) AS tgt
        USING dbo.Stg_Peoplesoft_SO001HRORG AS src
            ON  tgt.PosPosition         = src.PosPosition
            AND ISNULL(tgt.EmplId, '') = ISNULL(src.EmplId, '')

        -- UPDATE or REACTIVATE when matched and any data column differs
        WHEN MATCHED AND (
               tgt.IsActive = 0
            OR ISNULL(tgt.Organization,        '') <> ISNULL(src.Organization,        '')
            OR ISNULL(tgt.Level1,              '') <> ISNULL(src.Level1,              '')
            OR ISNULL(tgt.Level2,              '') <> ISNULL(src.Level2,              '')
            OR ISNULL(tgt.Level3,              '') <> ISNULL(src.Level3,              '')
            OR ISNULL(tgt.PosBusinessUnit,     '') <> ISNULL(src.PosBusinessUnit,     '')
            OR ISNULL(tgt.PosBU,               '') <> ISNULL(src.PosBU,               '')
            OR ISNULL(tgt.PosDepartment,       '') <> ISNULL(src.PosDepartment,       '')
            OR ISNULL(tgt.PosDeptId,           '') <> ISNULL(src.PosDeptId,           '')
            OR ISNULL(tgt.Title,               '') <> ISNULL(src.Title,               '')
            OR ISNULL(tgt.PosRole,             '') <> ISNULL(src.PosRole,             '')
            OR ISNULL(tgt.PosJobCode,          '') <> ISNULL(src.PosJobCode,          '')
            OR ISNULL(tgt.PosClassification,   '') <> ISNULL(src.PosClassification,   '')
            OR ISNULL(tgt.SupervisorPos,       '') <> ISNULL(src.SupervisorPos,       '')
            OR ISNULL(tgt.SupervisorName,      '') <> ISNULL(src.SupervisorName,      '')
            OR ISNULL(tgt.Direct,              -1) <> ISNULL(src.Direct,              -1)
            OR ISNULL(tgt.Indirect,            -1) <> ISNULL(src.Indirect,            -1)
            OR ISNULL(tgt.City,                '') <> ISNULL(src.City,                '')
            OR ISNULL(tgt.Status,              '') <> ISNULL(src.Status,              '')
            OR ISNULL(tgt.RT,                  '') <> ISNULL(src.RT,                  '')
            OR ISNULL(tgt.FP,                  '') <> ISNULL(src.FP,                  '')
            OR ISNULL(tgt.Budgetted,           '') <> ISNULL(src.Budgetted,           '')
            OR ISNULL(tgt.Empty,               '') <> ISNULL(src.Empty,               '')
            OR ISNULL(tgt.Vacant,              '') <> ISNULL(src.Vacant,              '')
            OR ISNULL(tgt.TrueVacancy,         '') <> ISNULL(src.TrueVacancy,         '')
            OR ISNULL(tgt.Future,              '') <> ISNULL(src.Future,              '')
            OR ISNULL(tgt.LastFilled,          '') <> ISNULL(src.LastFilled,          '')
            OR ISNULL(tgt.LastFilledB,         '') <> ISNULL(src.LastFilledB,         '')
            OR ISNULL(tgt.LastFilledBase,      '') <> ISNULL(src.LastFilledBase,      '')
            OR ISNULL(tgt.EmplBU,              '') <> ISNULL(src.EmplBU,              '')
            OR ISNULL(tgt.EmplDeptId,          '') <> ISNULL(src.EmplDeptId,          '')
            OR ISNULL(tgt.JobRole,             '') <> ISNULL(src.JobRole,             '')
            OR ISNULL(tgt.EmplJobCode,         '') <> ISNULL(src.EmplJobCode,         '')
            OR ISNULL(tgt.EmplClassification,  '') <> ISNULL(src.EmplClassification,  '')
            OR ISNULL(tgt.Grade,               '') <> ISNULL(src.Grade,               '')
            OR ISNULL(tgt.Step,                '') <> ISNULL(src.Step,                '')
            OR ISNULL(tgt.SalaryType,          '') <> ISNULL(src.SalaryType,          '')
            OR ISNULL(tgt.Type,                '') <> ISNULL(src.Type,                '')
            OR ISNULL(tgt.StandardHours,       '') <> ISNULL(src.StandardHours,       '')
            OR ISNULL(tgt.Base,                '') <> ISNULL(src.Base,                '')
            OR ISNULL(tgt.Name,                '') <> ISNULL(src.Name,                '')
            OR ISNULL(tgt.EmplId,              '') <> ISNULL(src.EmplId,              '')
            OR ISNULL(tgt.EmplStatus,          '') <> ISNULL(src.EmplStatus,          '')
            OR ISNULL(tgt.Appt,                '') <> ISNULL(src.Appt,                '')
            -- Age excluded — continuously-computed from Birthdate + AsOfDate;
            -- changes on every employee's birthday and would produce false UPDATEs.
            OR ISNULL(tgt.PosClassMax,         '') <> ISNULL(src.PosClassMax,         '')
            OR ISNULL(tgt.JobClassMax,         '') <> ISNULL(src.JobClassMax,         '')
            OR ISNULL(tgt.Annual,              '') <> ISNULL(src.Annual,              '')
            OR ISNULL(tgt.Abbr,                '') <> ISNULL(src.Abbr,                '')
            OR ISNULL(tgt.AdminPlan,           '') <> ISNULL(src.AdminPlan,           '')
            OR ISNULL(tgt.AMA,                 '') <> ISNULL(src.AMA,                 '')
            OR ISNULL(tgt.AMALimit,            '') <> ISNULL(src.AMALimit,            '')
            OR ISNULL(tgt.CAD,                 '') <> ISNULL(src.CAD,                 '')
            OR ISNULL(tgt.CADLimit,            '') <> ISNULL(src.CADLimit,            '')
            OR ISNULL(tgt.SPP,                 '') <> ISNULL(src.SPP,                 '')
            OR ISNULL(tgt.SPPLimit,            '') <> ISNULL(src.SPPLimit,            '')
            OR ISNULL(tgt.TAJ,                 '') <> ISNULL(src.TAJ,                 '')
            OR ISNULL(tgt.TAJLimit,            '') <> ISNULL(src.TAJLimit,            '')
            OR ISNULL(tgt.FutureTermDate,      '') <> ISNULL(src.FutureTermDate,      '')
            OR ISNULL(tgt.FutureTermReason,    '') <> ISNULL(src.FutureTermReason,    '')
            OR ISNULL(tgt.TAStatus,            '') <> ISNULL(src.TAStatus,            '')
            OR ISNULL(tgt.TAStartDate,         '') <> ISNULL(src.TAStartDate,         '')
            OR ISNULL(tgt.TAReturnDate,        '') <> ISNULL(src.TAReturnDate,        '')
            OR ISNULL(tgt.TAReturnTo,          '') <> ISNULL(src.TAReturnTo,          '')
            OR ISNULL(tgt.TAReturnBU,          '') <> ISNULL(src.TAReturnBU,          '')
            OR ISNULL(tgt.TAReturnDeptId,      '') <> ISNULL(src.TAReturnDeptId,      '')
            OR ISNULL(tgt.TAReturnJobCode,     '') <> ISNULL(src.TAReturnJobCode,     '')
            OR ISNULL(tgt.TAReturnGrade,       '') <> ISNULL(src.TAReturnGrade,       '')
            OR ISNULL(tgt.TAReturnPosition,    '') <> ISNULL(src.TAReturnPosition,    '')
            OR ISNULL(tgt.TAReturnSupervisor,  '') <> ISNULL(src.TAReturnSupervisor,  '')
            OR ISNULL(tgt.TAReturnAbbr,        '') <> ISNULL(src.TAReturnAbbr,        '')
            OR ISNULL(tgt.LeaveReason,         '') <> ISNULL(src.LeaveReason,         '')
            OR ISNULL(tgt.LeaveStart,          '') <> ISNULL(src.LeaveStart,          '')
            OR ISNULL(tgt.LeaveReturn,         '') <> ISNULL(src.LeaveReturn,         '')
            OR ISNULL(tgt.Q,                   '') <> ISNULL(src.Q,                   '')
            OR ISNULL(tgt.MaildropCity,        '') <> ISNULL(src.MaildropCity,        '')
        )
        THEN UPDATE SET
            Organization       = src.Organization,
            Level1             = src.Level1,
            Level2             = src.Level2,
            Level3             = src.Level3,
            PosBusinessUnit    = src.PosBusinessUnit,
            PosBU              = src.PosBU,
            PosDepartment      = src.PosDepartment,
            PosDeptId          = src.PosDeptId,
            Title              = src.Title,
            PosRole            = src.PosRole,
            PosJobCode         = src.PosJobCode,
            PosClassification  = src.PosClassification,
            SupervisorPos      = src.SupervisorPos,
            SupervisorName     = src.SupervisorName,
            Direct             = src.Direct,
            Indirect           = src.Indirect,
            City               = src.City,
            Status             = src.Status,
            RT                 = src.RT,
            FP                 = src.FP,
            Budgetted          = src.Budgetted,
            Empty              = src.Empty,
            Vacant             = src.Vacant,
            TrueVacancy        = src.TrueVacancy,
            Future             = src.Future,
            LastFilled         = src.LastFilled,
            LastFilledB        = src.LastFilledB,
            LastFilledBase     = src.LastFilledBase,
            EmplBU             = src.EmplBU,
            EmplDeptId         = src.EmplDeptId,
            JobRole            = src.JobRole,
            EmplJobCode        = src.EmplJobCode,
            EmplClassification = src.EmplClassification,
            Grade              = src.Grade,
            Step               = src.Step,
            SalaryType         = src.SalaryType,
            Type               = src.Type,
            StandardHours      = src.StandardHours,
            Base               = src.Base,
            Name               = src.Name,
            EmplId             = src.EmplId,
            EmplStatus         = src.EmplStatus,
            Appt               = src.Appt,
            Age                = src.Age,
            PosClassMax        = src.PosClassMax,
            JobClassMax        = src.JobClassMax,
            Annual             = src.Annual,
            Abbr               = src.Abbr,
            AdminPlan          = src.AdminPlan,
            AMA                = src.AMA,
            AMALimit           = src.AMALimit,
            CAD                = src.CAD,
            CADLimit           = src.CADLimit,
            SPP                = src.SPP,
            SPPLimit           = src.SPPLimit,
            TAJ                = src.TAJ,
            TAJLimit           = src.TAJLimit,
            FutureTermDate     = src.FutureTermDate,
            FutureTermReason   = src.FutureTermReason,
            TAStatus           = src.TAStatus,
            TAStartDate        = src.TAStartDate,
            TAReturnDate       = src.TAReturnDate,
            TAReturnTo         = src.TAReturnTo,
            TAReturnBU         = src.TAReturnBU,
            TAReturnDeptId     = src.TAReturnDeptId,
            TAReturnJobCode    = src.TAReturnJobCode,
            TAReturnGrade      = src.TAReturnGrade,
            TAReturnPosition   = src.TAReturnPosition,
            TAReturnSupervisor = src.TAReturnSupervisor,
            TAReturnAbbr       = src.TAReturnAbbr,
            LeaveReason        = src.LeaveReason,
            LeaveStart         = src.LeaveStart,
            LeaveReturn        = src.LeaveReturn,
            Q                  = src.Q,
            MaildropCity       = src.MaildropCity,
            IsActive           = 1,
            LastUpdatedUtc     = SYSUTCDATETIME()

        -- INSERT new positions
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            PosPosition,
            Organization, Level1, Level2, Level3,
            PosBusinessUnit, PosBU, PosDepartment, PosDeptId,
            Title, PosRole, PosJobCode, PosClassification,
            SupervisorPos, SupervisorName,
            Direct, Indirect,
            City, Status, RT, FP, Budgetted, Empty, Vacant,
            TrueVacancy, Future, LastFilled, LastFilledB, LastFilledBase,
            EmplBU, EmplDeptId, JobRole, EmplJobCode, EmplClassification,
            Grade, Step, SalaryType, Type, StandardHours, Base,
            Name, EmplId, EmplStatus, Appt, Age,
            PosClassMax, JobClassMax, Annual, Abbr, AdminPlan,
            AMA, AMALimit, CAD, CADLimit, SPP, SPPLimit, TAJ, TAJLimit,
            FutureTermDate, FutureTermReason,
            TAStatus, TAStartDate, TAReturnDate, TAReturnTo,
            TAReturnBU, TAReturnDeptId, TAReturnJobCode, TAReturnGrade,
            TAReturnPosition, TAReturnSupervisor, TAReturnAbbr,
            LeaveReason, LeaveStart, LeaveReturn,
            Q, MaildropCity,
            IsActive, CreatedUtc, LastUpdatedUtc
        )
        VALUES (
            src.PosPosition,
            src.Organization, src.Level1, src.Level2, src.Level3,
            src.PosBusinessUnit, src.PosBU, src.PosDepartment, src.PosDeptId,
            src.Title, src.PosRole, src.PosJobCode, src.PosClassification,
            src.SupervisorPos, src.SupervisorName,
            src.Direct, src.Indirect,
            src.City, src.Status, src.RT, src.FP, src.Budgetted, src.Empty, src.Vacant,
            src.TrueVacancy, src.Future, src.LastFilled, src.LastFilledB, src.LastFilledBase,
            src.EmplBU, src.EmplDeptId, src.JobRole, src.EmplJobCode, src.EmplClassification,
            src.Grade, src.Step, src.SalaryType, src.Type, src.StandardHours, src.Base,
            src.Name, src.EmplId, src.EmplStatus, src.Appt, src.Age,
            src.PosClassMax, src.JobClassMax, src.Annual, src.Abbr, src.AdminPlan,
            src.AMA, src.AMALimit, src.CAD, src.CADLimit, src.SPP, src.SPPLimit, src.TAJ, src.TAJLimit,
            src.FutureTermDate, src.FutureTermReason,
            src.TAStatus, src.TAStartDate, src.TAReturnDate, src.TAReturnTo,
            src.TAReturnBU, src.TAReturnDeptId, src.TAReturnJobCode, src.TAReturnGrade,
            src.TAReturnPosition, src.TAReturnSupervisor, src.TAReturnAbbr,
            src.LeaveReason, src.LeaveStart, src.LeaveReturn,
            src.Q, src.MaildropCity,
            1, SYSUTCDATETIME(), SYSUTCDATETIME()
        )

        -- SOFT DELETE: position no longer in source
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
            COALESCE(inserted.PosPosition, deleted.PosPosition)           AS PosPosition,
            COALESCE(inserted.EmplId,      deleted.EmplId)                AS EmplId,

            -- Old row hash
            HASHBYTES('SHA2_256', CONCAT_WS('|',
                deleted.PosPosition,
                COALESCE(deleted.Organization,        ''), COALESCE(deleted.Level1,              ''),
                COALESCE(deleted.Level2,              ''), COALESCE(deleted.Level3,              ''),
                COALESCE(deleted.PosBusinessUnit,     ''), COALESCE(deleted.PosBU,               ''),
                COALESCE(deleted.PosDepartment,       ''), COALESCE(deleted.PosDeptId,           ''),
                COALESCE(deleted.Title,               ''), COALESCE(deleted.PosRole,             ''),
                COALESCE(deleted.PosJobCode,          ''), COALESCE(deleted.PosClassification,   ''),
                COALESCE(deleted.SupervisorPos,       ''), COALESCE(deleted.SupervisorName,      ''),
                COALESCE(CONVERT(NVARCHAR(20), deleted.Direct),   ''),
                COALESCE(CONVERT(NVARCHAR(20), deleted.Indirect), ''),
                COALESCE(deleted.City,                ''), COALESCE(deleted.Status,              ''),
                COALESCE(deleted.RT,                  ''), COALESCE(deleted.FP,                  ''),
                COALESCE(deleted.Budgetted,           ''), COALESCE(deleted.Empty,               ''),
                COALESCE(deleted.Vacant,              ''), COALESCE(deleted.TrueVacancy,         ''),
                COALESCE(deleted.Future,              ''),
                COALESCE(deleted.LastFilled,          ''), COALESCE(deleted.LastFilledB,         ''),
                COALESCE(deleted.LastFilledBase,      ''),
                COALESCE(deleted.EmplBU,              ''), COALESCE(deleted.EmplDeptId,          ''),
                COALESCE(deleted.JobRole,             ''), COALESCE(deleted.EmplJobCode,         ''),
                COALESCE(deleted.EmplClassification,  ''),
                COALESCE(deleted.Grade,               ''), COALESCE(deleted.Step,                ''),
                COALESCE(deleted.SalaryType,          ''), COALESCE(deleted.Type,                ''),
                COALESCE(deleted.StandardHours,       ''), COALESCE(deleted.Base,                ''),
                COALESCE(deleted.Name,                ''), COALESCE(deleted.EmplId,              ''),
                COALESCE(deleted.EmplStatus,          ''), COALESCE(deleted.Appt,                ''),
                -- Age excluded from hash — continuously-computed; see MERGE WHEN MATCHED note
                COALESCE(deleted.PosClassMax,         ''), COALESCE(deleted.JobClassMax,         ''),
                COALESCE(deleted.Annual,              ''), COALESCE(deleted.Abbr,                ''),
                COALESCE(deleted.AdminPlan,           ''),
                COALESCE(deleted.AMA,                 ''), COALESCE(deleted.AMALimit,            ''),
                COALESCE(deleted.CAD,                 ''), COALESCE(deleted.CADLimit,            ''),
                COALESCE(deleted.SPP,                 ''), COALESCE(deleted.SPPLimit,            ''),
                COALESCE(deleted.TAJ,                 ''), COALESCE(deleted.TAJLimit,            ''),
                COALESCE(deleted.FutureTermDate,      ''), COALESCE(deleted.FutureTermReason,    ''),
                COALESCE(deleted.TAStatus,            ''), COALESCE(deleted.TAStartDate,         ''),
                COALESCE(deleted.TAReturnDate,        ''), COALESCE(deleted.TAReturnTo,          ''),
                COALESCE(deleted.TAReturnBU,          ''), COALESCE(deleted.TAReturnDeptId,      ''),
                COALESCE(deleted.TAReturnJobCode,     ''), COALESCE(deleted.TAReturnGrade,       ''),
                COALESCE(deleted.TAReturnPosition,    ''), COALESCE(deleted.TAReturnSupervisor,  ''),
                COALESCE(deleted.TAReturnAbbr,        ''),
                COALESCE(deleted.LeaveReason,         ''), COALESCE(deleted.LeaveStart,          ''),
                COALESCE(deleted.LeaveReturn,         ''), COALESCE(deleted.Q,                   ''),
                COALESCE(deleted.MaildropCity,        ''),
                COALESCE(CONVERT(NVARCHAR(1), deleted.IsActive), '')
            )) AS OldRowHash,

            -- New row hash
            HASHBYTES('SHA2_256', CONCAT_WS('|',
                inserted.PosPosition,
                COALESCE(inserted.Organization,        ''), COALESCE(inserted.Level1,              ''),
                COALESCE(inserted.Level2,              ''), COALESCE(inserted.Level3,              ''),
                COALESCE(inserted.PosBusinessUnit,     ''), COALESCE(inserted.PosBU,               ''),
                COALESCE(inserted.PosDepartment,       ''), COALESCE(inserted.PosDeptId,           ''),
                COALESCE(inserted.Title,               ''), COALESCE(inserted.PosRole,             ''),
                COALESCE(inserted.PosJobCode,          ''), COALESCE(inserted.PosClassification,   ''),
                COALESCE(inserted.SupervisorPos,       ''), COALESCE(inserted.SupervisorName,      ''),
                COALESCE(CONVERT(NVARCHAR(20), inserted.Direct),   ''),
                COALESCE(CONVERT(NVARCHAR(20), inserted.Indirect), ''),
                COALESCE(inserted.City,                ''), COALESCE(inserted.Status,              ''),
                COALESCE(inserted.RT,                  ''), COALESCE(inserted.FP,                  ''),
                COALESCE(inserted.Budgetted,           ''), COALESCE(inserted.Empty,               ''),
                COALESCE(inserted.Vacant,              ''), COALESCE(inserted.TrueVacancy,         ''),
                COALESCE(inserted.Future,              ''),
                COALESCE(inserted.LastFilled,          ''), COALESCE(inserted.LastFilledB,         ''),
                COALESCE(inserted.LastFilledBase,      ''),
                COALESCE(inserted.EmplBU,              ''), COALESCE(inserted.EmplDeptId,          ''),
                COALESCE(inserted.JobRole,             ''), COALESCE(inserted.EmplJobCode,         ''),
                COALESCE(inserted.EmplClassification,  ''),
                COALESCE(inserted.Grade,               ''), COALESCE(inserted.Step,                ''),
                COALESCE(inserted.SalaryType,          ''), COALESCE(inserted.Type,                ''),
                COALESCE(inserted.StandardHours,       ''), COALESCE(inserted.Base,                ''),
                COALESCE(inserted.Name,                ''), COALESCE(inserted.EmplId,              ''),
                COALESCE(inserted.EmplStatus,          ''), COALESCE(inserted.Appt,                ''),
                -- Age excluded from hash — continuously-computed; see MERGE WHEN MATCHED note
                COALESCE(inserted.PosClassMax,         ''), COALESCE(inserted.JobClassMax,         ''),
                COALESCE(inserted.Annual,              ''), COALESCE(inserted.Abbr,                ''),
                COALESCE(inserted.AdminPlan,           ''),
                COALESCE(inserted.AMA,                 ''), COALESCE(inserted.AMALimit,            ''),
                COALESCE(inserted.CAD,                 ''), COALESCE(inserted.CADLimit,            ''),
                COALESCE(inserted.SPP,                 ''), COALESCE(inserted.SPPLimit,            ''),
                COALESCE(inserted.TAJ,                 ''), COALESCE(inserted.TAJLimit,            ''),
                COALESCE(inserted.FutureTermDate,      ''), COALESCE(inserted.FutureTermReason,    ''),
                COALESCE(inserted.TAStatus,            ''), COALESCE(inserted.TAStartDate,         ''),
                COALESCE(inserted.TAReturnDate,        ''), COALESCE(inserted.TAReturnTo,          ''),
                COALESCE(inserted.TAReturnBU,          ''), COALESCE(inserted.TAReturnDeptId,      ''),
                COALESCE(inserted.TAReturnJobCode,     ''), COALESCE(inserted.TAReturnGrade,       ''),
                COALESCE(inserted.TAReturnPosition,    ''), COALESCE(inserted.TAReturnSupervisor,  ''),
                COALESCE(inserted.TAReturnAbbr,        ''),
                COALESCE(inserted.LeaveReason,         ''), COALESCE(inserted.LeaveStart,          ''),
                COALESCE(inserted.LeaveReturn,         ''), COALESCE(inserted.Q,                   ''),
                COALESCE(inserted.MaildropCity,        ''),
                COALESCE(CONVERT(NVARCHAR(1), inserted.IsActive), '')
            )) AS NewRowHash,

            CAST(deleted.IsActive  AS NVARCHAR(255)) AS OldIsActive,
            CAST(inserted.IsActive AS NVARCHAR(255)) AS NewIsActive,

            -- Old column values (all CAST to NVARCHAR(255))
            CAST(deleted.Organization        AS NVARCHAR(255)) AS OldOrganization,
            CAST(deleted.Level1              AS NVARCHAR(255)) AS OldLevel1,
            CAST(deleted.Level2              AS NVARCHAR(255)) AS OldLevel2,
            CAST(deleted.Level3              AS NVARCHAR(255)) AS OldLevel3,
            CAST(deleted.PosBusinessUnit     AS NVARCHAR(255)) AS OldPosBusinessUnit,
            CAST(deleted.PosBU               AS NVARCHAR(255)) AS OldPosBU,
            CAST(deleted.PosDepartment       AS NVARCHAR(255)) AS OldPosDepartment,
            CAST(deleted.PosDeptId           AS NVARCHAR(255)) AS OldPosDeptId,
            CAST(deleted.Title               AS NVARCHAR(255)) AS OldTitle,
            CAST(deleted.PosRole             AS NVARCHAR(255)) AS OldPosRole,
            CAST(deleted.PosJobCode          AS NVARCHAR(255)) AS OldPosJobCode,
            CAST(deleted.PosClassification   AS NVARCHAR(255)) AS OldPosClassification,
            CAST(deleted.SupervisorPos       AS NVARCHAR(255)) AS OldSupervisorPos,
            CAST(deleted.SupervisorName      AS NVARCHAR(255)) AS OldSupervisorName,
            CAST(deleted.Direct              AS NVARCHAR(255)) AS OldDirect,
            CAST(deleted.Indirect            AS NVARCHAR(255)) AS OldIndirect,
            CAST(deleted.City                AS NVARCHAR(255)) AS OldCity,
            CAST(deleted.Status              AS NVARCHAR(255)) AS OldStatus,
            CAST(deleted.RT                  AS NVARCHAR(255)) AS OldRT,
            CAST(deleted.FP                  AS NVARCHAR(255)) AS OldFP,
            CAST(deleted.Budgetted           AS NVARCHAR(255)) AS OldBudgetted,
            CAST(deleted.Empty               AS NVARCHAR(255)) AS OldEmpty,
            CAST(deleted.Vacant              AS NVARCHAR(255)) AS OldVacant,
            CAST(deleted.TrueVacancy         AS NVARCHAR(255)) AS OldTrueVacancy,
            CAST(deleted.Future              AS NVARCHAR(255)) AS OldFuture,
            CAST(deleted.LastFilled          AS NVARCHAR(255)) AS OldLastFilled,
            CAST(deleted.LastFilledB         AS NVARCHAR(255)) AS OldLastFilledB,
            CAST(deleted.LastFilledBase      AS NVARCHAR(255)) AS OldLastFilledBase,
            CAST(deleted.EmplBU              AS NVARCHAR(255)) AS OldEmplBU,
            CAST(deleted.EmplDeptId          AS NVARCHAR(255)) AS OldEmplDeptId,
            CAST(deleted.JobRole             AS NVARCHAR(255)) AS OldJobRole,
            CAST(deleted.EmplJobCode         AS NVARCHAR(255)) AS OldEmplJobCode,
            CAST(deleted.EmplClassification  AS NVARCHAR(255)) AS OldEmplClassification,
            CAST(deleted.Grade               AS NVARCHAR(255)) AS OldGrade,
            CAST(deleted.Step                AS NVARCHAR(255)) AS OldStep,
            CAST(deleted.SalaryType          AS NVARCHAR(255)) AS OldSalaryType,
            CAST(deleted.Type                AS NVARCHAR(255)) AS OldType,
            CAST(deleted.StandardHours       AS NVARCHAR(255)) AS OldStandardHours,
            CAST(deleted.Base                AS NVARCHAR(255)) AS OldBase,
            CAST(deleted.Name                AS NVARCHAR(255)) AS OldName,
            CAST(deleted.EmplId              AS NVARCHAR(255)) AS OldEmplId,
            CAST(deleted.EmplStatus          AS NVARCHAR(255)) AS OldEmplStatus,
            CAST(deleted.Appt                AS NVARCHAR(255)) AS OldAppt,
            CAST(deleted.Age                 AS NVARCHAR(255)) AS OldAge,
            CAST(deleted.PosClassMax         AS NVARCHAR(255)) AS OldPosClassMax,
            CAST(deleted.JobClassMax         AS NVARCHAR(255)) AS OldJobClassMax,
            CAST(deleted.Annual              AS NVARCHAR(255)) AS OldAnnual,
            CAST(deleted.Abbr                AS NVARCHAR(255)) AS OldAbbr,
            CAST(deleted.AdminPlan           AS NVARCHAR(255)) AS OldAdminPlan,
            CAST(deleted.AMA                 AS NVARCHAR(255)) AS OldAMA,
            CAST(deleted.AMALimit            AS NVARCHAR(255)) AS OldAMALimit,
            CAST(deleted.CAD                 AS NVARCHAR(255)) AS OldCAD,
            CAST(deleted.CADLimit            AS NVARCHAR(255)) AS OldCADLimit,
            CAST(deleted.SPP                 AS NVARCHAR(255)) AS OldSPP,
            CAST(deleted.SPPLimit            AS NVARCHAR(255)) AS OldSPPLimit,
            CAST(deleted.TAJ                 AS NVARCHAR(255)) AS OldTAJ,
            CAST(deleted.TAJLimit            AS NVARCHAR(255)) AS OldTAJLimit,
            CAST(deleted.FutureTermDate      AS NVARCHAR(255)) AS OldFutureTermDate,
            CAST(deleted.FutureTermReason    AS NVARCHAR(255)) AS OldFutureTermReason,
            CAST(deleted.TAStatus            AS NVARCHAR(255)) AS OldTAStatus,
            CAST(deleted.TAStartDate         AS NVARCHAR(255)) AS OldTAStartDate,
            CAST(deleted.TAReturnDate        AS NVARCHAR(255)) AS OldTAReturnDate,
            CAST(deleted.TAReturnTo          AS NVARCHAR(255)) AS OldTAReturnTo,
            CAST(deleted.TAReturnBU          AS NVARCHAR(255)) AS OldTAReturnBU,
            CAST(deleted.TAReturnDeptId      AS NVARCHAR(255)) AS OldTAReturnDeptId,
            CAST(deleted.TAReturnJobCode     AS NVARCHAR(255)) AS OldTAReturnJobCode,
            CAST(deleted.TAReturnGrade       AS NVARCHAR(255)) AS OldTAReturnGrade,
            CAST(deleted.TAReturnPosition    AS NVARCHAR(255)) AS OldTAReturnPosition,
            CAST(deleted.TAReturnSupervisor  AS NVARCHAR(255)) AS OldTAReturnSupervisor,
            CAST(deleted.TAReturnAbbr        AS NVARCHAR(255)) AS OldTAReturnAbbr,
            CAST(deleted.LeaveReason         AS NVARCHAR(255)) AS OldLeaveReason,
            CAST(deleted.LeaveStart          AS NVARCHAR(255)) AS OldLeaveStart,
            CAST(deleted.LeaveReturn         AS NVARCHAR(255)) AS OldLeaveReturn,
            CAST(deleted.Q                   AS NVARCHAR(255)) AS OldQ,
            CAST(deleted.MaildropCity        AS NVARCHAR(255)) AS OldMaildropCity,

            -- New column values (all CAST to NVARCHAR(255))
            CAST(inserted.Organization        AS NVARCHAR(255)) AS NewOrganization,
            CAST(inserted.Level1              AS NVARCHAR(255)) AS NewLevel1,
            CAST(inserted.Level2              AS NVARCHAR(255)) AS NewLevel2,
            CAST(inserted.Level3              AS NVARCHAR(255)) AS NewLevel3,
            CAST(inserted.PosBusinessUnit     AS NVARCHAR(255)) AS NewPosBusinessUnit,
            CAST(inserted.PosBU               AS NVARCHAR(255)) AS NewPosBU,
            CAST(inserted.PosDepartment       AS NVARCHAR(255)) AS NewPosDepartment,
            CAST(inserted.PosDeptId           AS NVARCHAR(255)) AS NewPosDeptId,
            CAST(inserted.Title               AS NVARCHAR(255)) AS NewTitle,
            CAST(inserted.PosRole             AS NVARCHAR(255)) AS NewPosRole,
            CAST(inserted.PosJobCode          AS NVARCHAR(255)) AS NewPosJobCode,
            CAST(inserted.PosClassification   AS NVARCHAR(255)) AS NewPosClassification,
            CAST(inserted.SupervisorPos       AS NVARCHAR(255)) AS NewSupervisorPos,
            CAST(inserted.SupervisorName      AS NVARCHAR(255)) AS NewSupervisorName,
            CAST(inserted.Direct              AS NVARCHAR(255)) AS NewDirect,
            CAST(inserted.Indirect            AS NVARCHAR(255)) AS NewIndirect,
            CAST(inserted.City                AS NVARCHAR(255)) AS NewCity,
            CAST(inserted.Status              AS NVARCHAR(255)) AS NewStatus,
            CAST(inserted.RT                  AS NVARCHAR(255)) AS NewRT,
            CAST(inserted.FP                  AS NVARCHAR(255)) AS NewFP,
            CAST(inserted.Budgetted           AS NVARCHAR(255)) AS NewBudgetted,
            CAST(inserted.Empty               AS NVARCHAR(255)) AS NewEmpty,
            CAST(inserted.Vacant              AS NVARCHAR(255)) AS NewVacant,
            CAST(inserted.TrueVacancy         AS NVARCHAR(255)) AS NewTrueVacancy,
            CAST(inserted.Future              AS NVARCHAR(255)) AS NewFuture,
            CAST(inserted.LastFilled          AS NVARCHAR(255)) AS NewLastFilled,
            CAST(inserted.LastFilledB         AS NVARCHAR(255)) AS NewLastFilledB,
            CAST(inserted.LastFilledBase      AS NVARCHAR(255)) AS NewLastFilledBase,
            CAST(inserted.EmplBU              AS NVARCHAR(255)) AS NewEmplBU,
            CAST(inserted.EmplDeptId          AS NVARCHAR(255)) AS NewEmplDeptId,
            CAST(inserted.JobRole             AS NVARCHAR(255)) AS NewJobRole,
            CAST(inserted.EmplJobCode         AS NVARCHAR(255)) AS NewEmplJobCode,
            CAST(inserted.EmplClassification  AS NVARCHAR(255)) AS NewEmplClassification,
            CAST(inserted.Grade               AS NVARCHAR(255)) AS NewGrade,
            CAST(inserted.Step                AS NVARCHAR(255)) AS NewStep,
            CAST(inserted.SalaryType          AS NVARCHAR(255)) AS NewSalaryType,
            CAST(inserted.Type                AS NVARCHAR(255)) AS NewType,
            CAST(inserted.StandardHours       AS NVARCHAR(255)) AS NewStandardHours,
            CAST(inserted.Base                AS NVARCHAR(255)) AS NewBase,
            CAST(inserted.Name                AS NVARCHAR(255)) AS NewName,
            CAST(inserted.EmplId              AS NVARCHAR(255)) AS NewEmplId,
            CAST(inserted.EmplStatus          AS NVARCHAR(255)) AS NewEmplStatus,
            CAST(inserted.Appt                AS NVARCHAR(255)) AS NewAppt,
            CAST(inserted.Age                 AS NVARCHAR(255)) AS NewAge,
            CAST(inserted.PosClassMax         AS NVARCHAR(255)) AS NewPosClassMax,
            CAST(inserted.JobClassMax         AS NVARCHAR(255)) AS NewJobClassMax,
            CAST(inserted.Annual              AS NVARCHAR(255)) AS NewAnnual,
            CAST(inserted.Abbr                AS NVARCHAR(255)) AS NewAbbr,
            CAST(inserted.AdminPlan           AS NVARCHAR(255)) AS NewAdminPlan,
            CAST(inserted.AMA                 AS NVARCHAR(255)) AS NewAMA,
            CAST(inserted.AMALimit            AS NVARCHAR(255)) AS NewAMALimit,
            CAST(inserted.CAD                 AS NVARCHAR(255)) AS NewCAD,
            CAST(inserted.CADLimit            AS NVARCHAR(255)) AS NewCADLimit,
            CAST(inserted.SPP                 AS NVARCHAR(255)) AS NewSPP,
            CAST(inserted.SPPLimit            AS NVARCHAR(255)) AS NewSPPLimit,
            CAST(inserted.TAJ                 AS NVARCHAR(255)) AS NewTAJ,
            CAST(inserted.TAJLimit            AS NVARCHAR(255)) AS NewTAJLimit,
            CAST(inserted.FutureTermDate      AS NVARCHAR(255)) AS NewFutureTermDate,
            CAST(inserted.FutureTermReason    AS NVARCHAR(255)) AS NewFutureTermReason,
            CAST(inserted.TAStatus            AS NVARCHAR(255)) AS NewTAStatus,
            CAST(inserted.TAStartDate         AS NVARCHAR(255)) AS NewTAStartDate,
            CAST(inserted.TAReturnDate        AS NVARCHAR(255)) AS NewTAReturnDate,
            CAST(inserted.TAReturnTo          AS NVARCHAR(255)) AS NewTAReturnTo,
            CAST(inserted.TAReturnBU          AS NVARCHAR(255)) AS NewTAReturnBU,
            CAST(inserted.TAReturnDeptId     AS NVARCHAR(255)) AS NewTAReturnDeptId,
            CAST(inserted.TAReturnJobCode     AS NVARCHAR(255)) AS NewTAReturnJobCode,
            CAST(inserted.TAReturnGrade       AS NVARCHAR(255)) AS NewTAReturnGrade,
            CAST(inserted.TAReturnPosition    AS NVARCHAR(255)) AS NewTAReturnPosition,
            CAST(inserted.TAReturnSupervisor  AS NVARCHAR(255)) AS NewTAReturnSupervisor,
            CAST(inserted.TAReturnAbbr        AS NVARCHAR(255)) AS NewTAReturnAbbr,
            CAST(inserted.LeaveReason         AS NVARCHAR(255)) AS NewLeaveReason,
            CAST(inserted.LeaveStart          AS NVARCHAR(255)) AS NewLeaveStart,
            CAST(inserted.LeaveReturn         AS NVARCHAR(255)) AS NewLeaveReturn,
            CAST(inserted.Q                   AS NVARCHAR(255)) AS NewQ,
            CAST(inserted.MaildropCity        AS NVARCHAR(255)) AS NewMaildropCity

        INTO dbo.Peoplesoft_SO001HRORG_Audit
        (
            RunId, ActionType, PosPosition, EmplId,
            OldRowHash, NewRowHash,
            OldIsActive, NewIsActive,
            OldOrganization, OldLevel1, OldLevel2, OldLevel3,
            OldPosBusinessUnit, OldPosBU, OldPosDepartment, OldPosDeptId,
            OldTitle, OldPosRole, OldPosJobCode, OldPosClassification,
            OldSupervisorPos, OldSupervisorName,
            OldDirect, OldIndirect,
            OldCity, OldStatus, OldRT, OldFP, OldBudgetted, OldEmpty, OldVacant,
            OldTrueVacancy, OldFuture, OldLastFilled, OldLastFilledB, OldLastFilledBase,
            OldEmplBU, OldEmplDeptId, OldJobRole, OldEmplJobCode, OldEmplClassification,
            OldGrade, OldStep, OldSalaryType, OldType, OldStandardHours, OldBase,
            OldName, OldEmplId, OldEmplStatus, OldAppt, OldAge,
            OldPosClassMax, OldJobClassMax, OldAnnual, OldAbbr, OldAdminPlan,
            OldAMA, OldAMALimit, OldCAD, OldCADLimit, OldSPP, OldSPPLimit,
            OldTAJ, OldTAJLimit, OldFutureTermDate, OldFutureTermReason,
            OldTAStatus, OldTAStartDate, OldTAReturnDate, OldTAReturnTo,
            OldTAReturnBU, OldTAReturnDeptId, OldTAReturnJobCode, OldTAReturnGrade,
            OldTAReturnPosition, OldTAReturnSupervisor, OldTAReturnAbbr,
            OldLeaveReason, OldLeaveStart, OldLeaveReturn, OldQ, OldMaildropCity,
            NewOrganization, NewLevel1, NewLevel2, NewLevel3,
            NewPosBusinessUnit, NewPosBU, NewPosDepartment, NewPosDeptId,
            NewTitle, NewPosRole, NewPosJobCode, NewPosClassification,
            NewSupervisorPos, NewSupervisorName,
            NewDirect, NewIndirect,
            NewCity, NewStatus, NewRT, NewFP, NewBudgetted, NewEmpty, NewVacant,
            NewTrueVacancy, NewFuture, NewLastFilled, NewLastFilledB, NewLastFilledBase,
            NewEmplBU, NewEmplDeptId, NewJobRole, NewEmplJobCode, NewEmplClassification,
            NewGrade, NewStep, NewSalaryType, NewType, NewStandardHours, NewBase,
            NewName, NewEmplId, NewEmplStatus, NewAppt, NewAge,
            NewPosClassMax, NewJobClassMax, NewAnnual, NewAbbr, NewAdminPlan,
            NewAMA, NewAMALimit, NewCAD, NewCADLimit, NewSPP, NewSPPLimit,
            NewTAJ, NewTAJLimit, NewFutureTermDate, NewFutureTermReason,
            NewTAStatus, NewTAStartDate, NewTAReturnDate, NewTAReturnTo,
            NewTAReturnBU, NewTAReturnDeptId, NewTAReturnJobCode, NewTAReturnGrade,
            NewTAReturnPosition, NewTAReturnSupervisor, NewTAReturnAbbr,
            NewLeaveReason, NewLeaveStart, NewLeaveReturn, NewQ, NewMaildropCity
        );

        COMMIT;

        -- Return a concise run summary (handy for R logging)
        SELECT
            @RunId AS RunId,
            @StgCnt AS StagingRows,
            @TgtCnt AS TargetRows_Before,
            @WouldSoftDelete AS WouldSoftDelete_Preview,
            (SELECT COUNT(*) FROM dbo.Peoplesoft_SO001HRORG) AS TargetRows_After,
            (SELECT COUNT(*) FROM dbo.Peoplesoft_SO001HRORG_Audit WHERE RunId = @RunId) AS AuditEvents;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO
