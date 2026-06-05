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
        --
        -- NOTE: LastFilled, LastFilledB, LastFilledBase, and Age are
        -- EXCLUDED from WHEN MATCHED and HASHBYTES because PeopleSoft
        -- recomputes them daily (days-since-filled counters / age).
        -- They are KEPT in UPDATE SET, INSERT, and OUTPUT so values
        -- stay fresh and are tracked in audit history.
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
            -- LastFilled, LastFilledB, LastFilledBase REMOVED (daily counter)
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
            -- Age REMOVED (recomputed daily)
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
            LastFilled         = src.LastFilled,       -- kept in SET (value stays fresh)
            LastFilledB        = src.LastFilledB,      -- kept in SET (value stays fresh)
            LastFilledBase     = src.LastFilledBase,    -- kept in SET (value stays fresh)
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
            Age                = src.Age,              -- kept in SET (value stays fresh)
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

              -- Old row hash (LastFilled, LastFilledB, LastFilledBase, Age REMOVED)
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
                -- LastFilled, LastFilledB, LastFilledBase REMOVED
                COALESCE(deleted.EmplBU,              ''), COALESCE(deleted.EmplDeptId,          ''),
                COALESCE(deleted.JobRole,             ''), COALESCE(deleted.EmplJobCode,         ''),
                COALESCE(deleted.EmplClassification,  ''),
                COALESCE(deleted.Grade,               ''), COALESCE(deleted.Step,                ''),
                COALESCE(deleted.SalaryType,          ''), COALESCE(deleted.Type,                ''),
                COALESCE(deleted.StandardHours,       ''), COALESCE(deleted.Base,                ''),
                COALESCE(deleted.Name,                ''), COALESCE(deleted.EmplId,              ''),
                COALESCE(deleted.EmplStatus,          ''), COALESCE(deleted.Appt,                ''),
                -- Age REMOVED
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

              -- New row hash (LastFilled, LastFilledB, LastFilledBase, Age REMOVED)
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
                -- LastFilled, LastFilledB, LastFilledBase REMOVED
                COALESCE(inserted.EmplBU,              ''), COALESCE(inserted.EmplDeptId,          ''),
                COALESCE(inserted.JobRole,             ''), COALESCE(inserted.EmplJobCode,         ''),
                COALESCE(inserted.EmplClassification,  ''),
                COALESCE(inserted.Grade,               ''), COALESCE(inserted.Step,                ''),
                COALESCE(inserted.SalaryType,          ''), COALESCE(inserted.Type,                ''),
                COALESCE(inserted.StandardHours,       ''), COALESCE(inserted.Base,                ''),
                COALESCE(inserted.Name,                ''), COALESCE(inserted.EmplId,              ''),
                COALESCE(inserted.EmplStatus,          ''), COALESCE(inserted.Appt,                ''),
                -- Age REMOVED
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

              deleted.IsActive  AS OldIsActive,
            inserted.IsActive AS NewIsActive,

              -- Old column values (ALL columns kept for audit trail)
            deleted.Organization        AS OldOrganization,
            deleted.Level1              AS OldLevel1,
            deleted.Level2              AS OldLevel2,
            deleted.Level3              AS OldLevel3,
            deleted.PosBusinessUnit     AS OldPosBusinessUnit,
            deleted.PosBU               AS OldPosBU,
            deleted.PosDepartment       AS OldPosDepartment,
            deleted.PosDeptId           AS OldPosDeptId,
            deleted.Title               AS OldTitle,
            deleted.PosRole             AS OldPosRole,
            deleted.PosJobCode          AS OldPosJobCode,
            deleted.PosClassification   AS OldPosClassification,
            deleted.SupervisorPos       AS OldSupervisorPos,
            deleted.SupervisorName      AS OldSupervisorName,
            deleted.Direct              AS OldDirect,
            deleted.Indirect            AS OldIndirect,
            deleted.City                AS OldCity,
            deleted.Status              AS OldStatus,
            deleted.RT                  AS OldRT,
            deleted.FP                  AS OldFP,
            deleted.Budgetted           AS OldBudgetted,
            deleted.Empty               AS OldEmpty,
            deleted.Vacant              AS OldVacant,
            deleted.TrueVacancy         AS OldTrueVacancy,
            deleted.Future              AS OldFuture,
            deleted.LastFilled          AS OldLastFilled,
            deleted.LastFilledB         AS OldLastFilledB,
            deleted.LastFilledBase      AS OldLastFilledBase,
            deleted.EmplBU              AS OldEmplBU,
            deleted.EmplDeptId          AS OldEmplDeptId,
            deleted.JobRole             AS OldJobRole,
            deleted.EmplJobCode         AS OldEmplJobCode,
            deleted.EmplClassification  AS OldEmplClassification,
            deleted.Grade               AS OldGrade,
            deleted.Step                AS OldStep,
            deleted.SalaryType          AS OldSalaryType,
            deleted.Type                AS OldType,
            deleted.StandardHours       AS OldStandardHours,
            deleted.Base                AS OldBase,
            deleted.Name                AS OldName,
            deleted.EmplId              AS OldEmplId,
            deleted.EmplStatus          AS OldEmplStatus,
            deleted.Appt                AS OldAppt,
            deleted.Age                 AS OldAge,
            deleted.PosClassMax         AS OldPosClassMax,
            deleted.JobClassMax         AS OldJobClassMax,
            deleted.Annual              AS OldAnnual,
            deleted.Abbr                AS OldAbbr,
            deleted.AdminPlan           AS OldAdminPlan,
            deleted.AMA                 AS OldAMA,
            deleted.AMALimit            AS OldAMALimit,
            deleted.CAD                 AS OldCAD,
            deleted.CADLimit            AS OldCADLimit,
            deleted.SPP                 AS OldSPP,
            deleted.SPPLimit            AS OldSPPLimit,
            deleted.TAJ                 AS OldTAJ,
            deleted.TAJLimit            AS OldTAJLimit,
            deleted.FutureTermDate      AS OldFutureTermDate,
            deleted.FutureTermReason    AS OldFutureTermReason,
            deleted.TAStatus            AS OldTAStatus,
            deleted.TAStartDate         AS OldTAStartDate,
            deleted.TAReturnDate        AS OldTAReturnDate,
            deleted.TAReturnTo          AS OldTAReturnTo,
            deleted.TAReturnBU          AS OldTAReturnBU,
            deleted.TAReturnDeptId      AS OldTAReturnDeptId,
            deleted.TAReturnJobCode     AS OldTAReturnJobCode,
            deleted.TAReturnGrade       AS OldTAReturnGrade,
            deleted.TAReturnPosition    AS OldTAReturnPosition,
            deleted.TAReturnSupervisor  AS OldTAReturnSupervisor,
            deleted.TAReturnAbbr        AS OldTAReturnAbbr,
            deleted.LeaveReason         AS OldLeaveReason,
            deleted.LeaveStart          AS OldLeaveStart,
            deleted.LeaveReturn         AS OldLeaveReturn,
            deleted.Q                   AS OldQ,
            deleted.MaildropCity        AS OldMaildropCity,

              -- New column values (ALL columns kept for audit trail)
            inserted.Organization        AS NewOrganization,
            inserted.Level1              AS NewLevel1,
            inserted.Level2              AS NewLevel2,
            inserted.Level3              AS NewLevel3,
            inserted.PosBusinessUnit     AS NewPosBusinessUnit,
            inserted.PosBU               AS NewPosBU,
            inserted.PosDepartment       AS NewPosDepartment,
            inserted.PosDeptId           AS NewPosDeptId,
            inserted.Title               AS NewTitle,
            inserted.PosRole             AS NewPosRole,
            inserted.PosJobCode          AS NewPosJobCode,
            inserted.PosClassification   AS NewPosClassification,
            inserted.SupervisorPos       AS NewSupervisorPos,
            inserted.SupervisorName      AS NewSupervisorName,
            inserted.Direct              AS NewDirect,
            inserted.Indirect            AS NewIndirect,
            inserted.City                AS NewCity,
            inserted.Status              AS NewStatus,
            inserted.RT                  AS NewRT,
            inserted.FP                  AS NewFP,
            inserted.Budgetted           AS NewBudgetted,
            inserted.Empty               AS NewEmpty,
            inserted.Vacant              AS NewVacant,
            inserted.TrueVacancy         AS NewTrueVacancy,
            inserted.Future              AS NewFuture,
            inserted.LastFilled          AS NewLastFilled,
            inserted.LastFilledB         AS NewLastFilledB,
            inserted.LastFilledBase      AS NewLastFilledBase,
            inserted.EmplBU              AS NewEmplBU,
            inserted.EmplDeptId          AS NewEmplDeptId,
            inserted.JobRole             AS NewJobRole,
            inserted.EmplJobCode         AS NewEmplJobCode,
            inserted.EmplClassification  AS NewEmplClassification,
            inserted.Grade               AS NewGrade,
            inserted.Step                AS NewStep,
            inserted.SalaryType          AS NewSalaryType,
            inserted.Type                AS NewType,
            inserted.StandardHours       AS NewStandardHours,
            inserted.Base                AS NewBase,
            inserted.Name                AS NewName,
            inserted.EmplId              AS NewEmplId,
            inserted.EmplStatus          AS NewEmplStatus,
            inserted.Appt                AS NewAppt,
            inserted.Age                 AS NewAge,
            inserted.PosClassMax         AS NewPosClassMax,
            inserted.JobClassMax         AS NewJobClassMax,
            inserted.Annual              AS NewAnnual,
            inserted.Abbr                AS NewAbbr,
            inserted.AdminPlan           AS NewAdminPlan,
            inserted.AMA                 AS NewAMA,
            inserted.AMALimit            AS NewAMALimit,
            inserted.CAD                 AS NewCAD,
            inserted.CADLimit            AS NewCADLimit,
            inserted.SPP                 AS NewSPP,
            inserted.SPPLimit            AS NewSPPLimit,
            inserted.TAJ                 AS NewTAJ,
            inserted.TAJLimit            AS NewTAJLimit,
            inserted.FutureTermDate      AS NewFutureTermDate,
            inserted.FutureTermReason    AS NewFutureTermReason,
            inserted.TAStatus            AS NewTAStatus,
            inserted.TAStartDate         AS NewTAStartDate,
            inserted.TAReturnDate        AS NewTAReturnDate,
            inserted.TAReturnTo          AS NewTAReturnTo,
            inserted.TAReturnBU          AS NewTAReturnBU,
            inserted.TAReturnDeptId      AS NewTAReturnDeptId,
            inserted.TAReturnJobCode     AS NewTAReturnJobCode,
            inserted.TAReturnGrade       AS NewTAReturnGrade,
            inserted.TAReturnPosition    AS NewTAReturnPosition,
            inserted.TAReturnSupervisor  AS NewTAReturnSupervisor,
            inserted.TAReturnAbbr        AS NewTAReturnAbbr,
            inserted.LeaveReason         AS NewLeaveReason,
            inserted.LeaveStart          AS NewLeaveStart,
            inserted.LeaveReturn         AS NewLeaveReturn,
            inserted.Q                   AS NewQ,
            inserted.MaildropCity        AS NewMaildropCity

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