SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================
-- Procedure : dbo.usp_Merge_PeopleSoft_HEM
-- Source    : Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ
-- Purpose   : UPSERT + soft-delete + audit for movement events (hires, exits,
--             internal moves). Uses SHA2-256 row hash via source CTE to detect
--             changes across all 136 data columns without 136-column OR expression.
-- Business key: EmplId + EffDt + EffSeq + EmplRcd
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_Merge_PeopleSoft_HEM
(
      @Force                 BIT          = 0
    , @MinPctOfTarget        DECIMAL(5,2) = 0.80   -- staging must be >= 80% of target
    , @MaxPctOfTarget        DECIMAL(5,2) = 1.20   -- staging must be <= 120% of target
    , @MaxSoftDeletePct      DECIMAL(5,2) = 0.10   -- max 10% of active target may soft-delete per run
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunId UNIQUEIDENTIFIER = NEWID();
    DECLARE @StgCnt INT, @TgtCnt INT;

    SELECT @StgCnt = COUNT(*) FROM dbo.Stg_Peoplesoft_HEM;
    SELECT @TgtCnt = COUNT(*) FROM dbo.Peoplesoft_HEM;

    ------------------------------------------------------------------------
    -- Guardrail 0: staging must not be empty unless forced
    ------------------------------------------------------------------------
    IF (@StgCnt = 0 AND @Force = 0)
        THROW 51000, 'MERGE aborted: staging table is empty (possible API failure). Use @Force=1 to override.', 1;

    ------------------------------------------------------------------------
    -- Guardrail 0b: business key must not contain NULL
    ------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM dbo.Stg_Peoplesoft_HEM
        WHERE EmplId IS NULL OR EmplId = ''
           OR EffDt   IS NULL
           OR EffSeq  IS NULL
           OR EmplRcd IS NULL
    )
        THROW 51001, 'MERGE aborted: staging contains NULL business key (EmplId/EffDt/EffSeq/EmplRcd).', 1;

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
        -- Guardrail 2: preview soft deletes
        --------------------------------------------------------------------
        DECLARE @WouldSoftDelete INT = 0;
        IF (@TgtCnt > 0)
        BEGIN
            SELECT @WouldSoftDelete = COUNT(*)
            FROM dbo.Peoplesoft_HEM tgt
            LEFT JOIN dbo.Stg_Peoplesoft_HEM src
                ON  tgt.EmplId  = src.EmplId
                AND tgt.EffDt   = src.EffDt
                AND tgt.EffSeq  = src.EffSeq
                AND tgt.EmplRcd = src.EmplRcd
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
        -- MERGE + SOFT DELETE + AUDIT OUTPUT
        -- Row hash computed in CTE to detect any data change across 136 columns
        -- without a 136-term OR expression in WHEN MATCHED.
        -- COALESCE used for all nullable columns to prevent CONCAT_WS from
        -- silently skipping NULLs and producing ambiguous hash collisions.
        --------------------------------------------------------------------
        ;WITH src AS (
            SELECT
                EmplId, EffDt, EffSeq, EmplRcd,
                CompChange, EstimatedYrsOfService, EstimatedYearsOfService,
                EstimatedYearsOfServiceStr, FirstDateOfService, FiscalYear,
                LeaveServiceDt, MostHistoricDate, MoveType, MoveType1,
                MoveType1Sort, MoveType2, Name, SameGroup, SameLevel1,
                SameOrg, Seq, SupervisorMove,
                NewAction, NewActionDt, NewActionReason, NewActionReasonDescr,
                NewAnnualRt, NewBusinessUnit, NewBusinessUnitDescr, NewCity,
                NewClassificationGroup, NewCompRate, NewCoreBu, NewCoreOrg,
                NewDeptId, NewDeptIdDescr, NewDevelopmentRegion,
                NewEmplCtg, NewEmplCtgDescr, NewEmplStatus, NewEmplStatusDescr,
                NewEndOfDayHrStatus, NewEndOfDayPerOrg,
                NewEstimatedYearsInOrg, NewEstimatedYearsInOrgStr,
                NewEstimatedYearsInPos, NewEstimatedYearsInPosStr,
                NewFirstDateInOrg, NewFirstDateInPosition,
                NewGrade, NewHireDate, NewHourlyRt, NewHrStatus,
                NewIncludedOrExcluded, NewIsSupervisor, NewJobFunction,
                NewJobcode, NewJobcodeDescr,
                NewLevel1, NewLevel2, NewLevel3, NewLevel4,
                NewLifeCycle, NewLocation, NewLocationGroup,
                NewMaxRtHourly, NewOrganization, NewPerOrg,
                NewPositionDescr, NewPositionNbr, NewPsa,
                NewRegionalDistrict, NewRehireDate, NewReportsTo,
                NewSalAdminPlan, NewSelectedGroup, NewStdHours, NewStep, NewSupervisor,
                PriorAction, PriorActionDt, PriorActionReason, PriorActionReasonDescr,
                PriorAnnualRt, PriorBusinessUnit, PriorBusinessUnitDescr, PriorCity,
                PriorClassificationGroup, PriorCompRate, PriorCoreBu, PriorCoreOrg,
                PriorDeptId, PriorDeptIdDescr, PriorDevelopmentRegion,
                PriorEffDt, PriorEffSeq,
                PriorEmplCtg, PriorEmplCtgDescr, PriorEmplStatus, PriorEmplStatusDescr,
                PriorEndOfDayHrStatus, PriorEndOfDayPerOrg,
                PriorEstimatedYearsInOrg, PriorEstimatedYearsInOrgStr,
                PriorEstimatedYearsInPos, PriorEstimatedYearsInPosStr,
                PriorFirstDateInOrg, PriorFirstDateInPosition,
                PriorFiscalYear, PriorGrade, PriorHireDate, PriorHourlyRt,
                PriorHrStatus, PriorIncludedOrExcluded, PriorIsSupervisor,
                PriorJobFunction, PriorJobcode, PriorJobcodeDescr,
                PriorLevel1, PriorLevel2, PriorLevel3, PriorLevel4,
                PriorLifeCycle, PriorLocation, PriorLocationGroup,
                PriorMaxRtHourly, PriorOrganization, PriorPerOrg,
                PriorPositionDescr, PriorPositionNbr, PriorPsa,
                PriorRegionalDistrict, PriorRehireDate, PriorReportsTo,
                PriorSalAdminPlan, PriorSelectedGroup, PriorSeq,
                PriorStdHours, PriorStep, PriorSupervisor,
                -- Compute row hash across all 136 data columns
                HASHBYTES('SHA2_256', CAST(CONCAT_WS('|',
                    COALESCE(CompChange,                        ''),
                    COALESCE(CAST(EstimatedYrsOfService   AS NVARCHAR(20)), ''),
                    COALESCE(CAST(EstimatedYearsOfService  AS NVARCHAR(20)), ''),
                    COALESCE(EstimatedYearsOfServiceStr,        ''),
                    COALESCE(CONVERT(NVARCHAR(10), FirstDateOfService,  23), ''),
                    COALESCE(CAST(FiscalYear               AS NVARCHAR(10)), ''),
                    COALESCE(CONVERT(NVARCHAR(10), LeaveServiceDt,      23), ''),
                    COALESCE(CONVERT(NVARCHAR(10), MostHistoricDate,    23), ''),
                    COALESCE(MoveType,                          ''),
                    COALESCE(MoveType1,                         ''),
                    COALESCE(CAST(MoveType1Sort            AS NVARCHAR(10)), ''),
                    COALESCE(MoveType2,                         ''),
                    COALESCE(Name,                              ''),
                    COALESCE(SameGroup,                         ''),
                    COALESCE(SameLevel1,                        ''),
                    COALESCE(SameOrg,                           ''),
                    COALESCE(CAST(Seq                     AS NVARCHAR(10)), ''),
                    COALESCE(SupervisorMove,                    ''),
                    COALESCE(NewAction,                         ''),
                    COALESCE(CONVERT(NVARCHAR(10), NewActionDt,          23), ''),
                    COALESCE(NewActionReason,                   ''),
                    COALESCE(NewActionReasonDescr,              ''),
                    COALESCE(CAST(NewAnnualRt             AS NVARCHAR(30)), ''),
                    COALESCE(NewBusinessUnit,                   ''),
                    COALESCE(NewBusinessUnitDescr,              ''),
                    COALESCE(NewCity,                           ''),
                    COALESCE(NewClassificationGroup,            ''),
                    COALESCE(CAST(NewCompRate             AS NVARCHAR(30)), ''),
                    COALESCE(NewCoreBu,                         ''),
                    COALESCE(NewCoreOrg,                        ''),
                    COALESCE(NewDeptId,                         ''),
                    COALESCE(NewDeptIdDescr,                    ''),
                    COALESCE(NewDevelopmentRegion,              ''),
                    COALESCE(NewEmplCtg,                        ''),
                    COALESCE(NewEmplCtgDescr,                   ''),
                    COALESCE(NewEmplStatus,                     ''),
                    COALESCE(NewEmplStatusDescr,                ''),
                    COALESCE(NewEndOfDayHrStatus,               ''),
                    COALESCE(NewEndOfDayPerOrg,                 ''),
                    COALESCE(CAST(NewEstimatedYearsInOrg  AS NVARCHAR(10)), ''),
                    COALESCE(NewEstimatedYearsInOrgStr,         ''),
                    COALESCE(CAST(NewEstimatedYearsInPos  AS NVARCHAR(10)), ''),
                    COALESCE(NewEstimatedYearsInPosStr,         ''),
                    COALESCE(CONVERT(NVARCHAR(10), NewFirstDateInOrg,    23), ''),
                    COALESCE(CONVERT(NVARCHAR(10), NewFirstDateInPosition,23), ''),
                    COALESCE(NewGrade,                          ''),
                    COALESCE(CONVERT(NVARCHAR(10), NewHireDate,          23), ''),
                    COALESCE(CAST(NewHourlyRt             AS NVARCHAR(30)), ''),
                    COALESCE(NewHrStatus,                       ''),
                    COALESCE(NewIncludedOrExcluded,             ''),
                    COALESCE(NewIsSupervisor,                   ''),
                    COALESCE(NewJobFunction,                    ''),
                    COALESCE(NewJobcode,                        ''),
                    COALESCE(NewJobcodeDescr,                   ''),
                    COALESCE(NewLevel1,                         ''),
                    COALESCE(NewLevel2,                         ''),
                    COALESCE(NewLevel3,                         ''),
                    COALESCE(NewLevel4,                         ''),
                    COALESCE(NewLifeCycle,                      ''),
                    COALESCE(NewLocation,                       ''),
                    COALESCE(NewLocationGroup,                  ''),
                    COALESCE(CAST(NewMaxRtHourly          AS NVARCHAR(30)), ''),
                    COALESCE(NewOrganization,                   ''),
                    COALESCE(NewPerOrg,                         ''),
                    COALESCE(NewPositionDescr,                  ''),
                    COALESCE(NewPositionNbr,                    ''),
                    COALESCE(NewPsa,                            ''),
                    COALESCE(NewRegionalDistrict,               ''),
                    COALESCE(CONVERT(NVARCHAR(10), NewRehireDate,        23), ''),
                    COALESCE(NewReportsTo,                      ''),
                    COALESCE(NewSalAdminPlan,                   ''),
                    COALESCE(NewSelectedGroup,                  ''),
                    COALESCE(CAST(NewStdHours             AS NVARCHAR(20)), ''),
                    COALESCE(CAST(NewStep                 AS NVARCHAR(10)), ''),
                    COALESCE(NewSupervisor,                     ''),
                    COALESCE(PriorAction,                       ''),
                    COALESCE(CONVERT(NVARCHAR(10), PriorActionDt,        23), ''),
                    COALESCE(PriorActionReason,                 ''),
                    COALESCE(PriorActionReasonDescr,            ''),
                    COALESCE(CAST(PriorAnnualRt           AS NVARCHAR(30)), ''),
                    COALESCE(PriorBusinessUnit,                 ''),
                    COALESCE(PriorBusinessUnitDescr,            ''),
                    COALESCE(PriorCity,                         ''),
                    COALESCE(PriorClassificationGroup,          ''),
                    COALESCE(CAST(PriorCompRate           AS NVARCHAR(30)), ''),
                    COALESCE(PriorCoreBu,                       ''),
                    COALESCE(PriorCoreOrg,                      ''),
                    COALESCE(PriorDeptId,                       ''),
                    COALESCE(PriorDeptIdDescr,                  ''),
                    COALESCE(PriorDevelopmentRegion,            ''),
                    COALESCE(CONVERT(NVARCHAR(10), PriorEffDt,           23), ''),
                    COALESCE(CAST(PriorEffSeq             AS NVARCHAR(10)), ''),
                    COALESCE(PriorEmplCtg,                      ''),
                    COALESCE(PriorEmplCtgDescr,                 ''),
                    COALESCE(PriorEmplStatus,                   ''),
                    COALESCE(PriorEmplStatusDescr,              ''),
                    COALESCE(PriorEndOfDayHrStatus,             ''),
                    COALESCE(PriorEndOfDayPerOrg,               ''),
                    COALESCE(CAST(PriorEstimatedYearsInOrg  AS NVARCHAR(10)), ''),
                    COALESCE(PriorEstimatedYearsInOrgStr,       ''),
                    COALESCE(CAST(PriorEstimatedYearsInPos  AS NVARCHAR(10)), ''),
                    COALESCE(PriorEstimatedYearsInPosStr,       ''),
                    COALESCE(CONVERT(NVARCHAR(10), PriorFirstDateInOrg,   23), ''),
                    COALESCE(CONVERT(NVARCHAR(10), PriorFirstDateInPosition, 23), ''),
                    COALESCE(CAST(PriorFiscalYear          AS NVARCHAR(10)), ''),
                    COALESCE(PriorGrade,                        ''),
                    COALESCE(CONVERT(NVARCHAR(10), PriorHireDate,        23), ''),
                    COALESCE(CAST(PriorHourlyRt           AS NVARCHAR(30)), ''),
                    COALESCE(PriorHrStatus,                     ''),
                    COALESCE(PriorIncludedOrExcluded,           ''),
                    COALESCE(PriorIsSupervisor,                 ''),
                    COALESCE(PriorJobFunction,                  ''),
                    COALESCE(PriorJobcode,                      ''),
                    COALESCE(PriorJobcodeDescr,                 ''),
                    COALESCE(PriorLevel1,                       ''),
                    COALESCE(PriorLevel2,                       ''),
                    COALESCE(PriorLevel3,                       ''),
                    COALESCE(PriorLevel4,                       ''),
                    COALESCE(PriorLifeCycle,                    ''),
                    COALESCE(PriorLocation,                     ''),
                    COALESCE(PriorLocationGroup,                ''),
                    COALESCE(CAST(PriorMaxRtHourly        AS NVARCHAR(30)), ''),
                    COALESCE(PriorOrganization,                 ''),
                    COALESCE(PriorPerOrg,                       ''),
                    COALESCE(PriorPositionDescr,                ''),
                    COALESCE(PriorPositionNbr,                  ''),
                    COALESCE(PriorPsa,                          ''),
                    COALESCE(PriorRegionalDistrict,             ''),
                    COALESCE(CONVERT(NVARCHAR(10), PriorRehireDate,      23), ''),
                    COALESCE(PriorReportsTo,                    ''),
                    COALESCE(PriorSalAdminPlan,                 ''),
                    COALESCE(PriorSelectedGroup,                ''),
                    COALESCE(CAST(PriorSeq                AS NVARCHAR(10)), ''),
                    COALESCE(CAST(PriorStdHours           AS NVARCHAR(20)), ''),
                    COALESCE(CAST(PriorStep               AS NVARCHAR(10)), ''),
                    COALESCE(PriorSupervisor,                   '')
                ) AS NVARCHAR(MAX))) AS _RowHash
            FROM dbo.Stg_Peoplesoft_HEM
        )
        MERGE dbo.Peoplesoft_HEM WITH (HOLDLOCK) AS tgt
        USING src
            ON  tgt.EmplId  = src.EmplId
            AND tgt.EffDt   = src.EffDt
            AND tgt.EffSeq  = src.EffSeq
            AND tgt.EmplRcd = src.EmplRcd

        -- UPDATE or REACTIVATE when any column changed (hash differs) or was soft-deleted
        WHEN MATCHED AND (tgt.IsActive = 0 OR tgt.RowHash <> src._RowHash)
        THEN UPDATE SET
            CompChange                  = src.CompChange,
            EstimatedYrsOfService       = src.EstimatedYrsOfService,
            EstimatedYearsOfService     = src.EstimatedYearsOfService,
            EstimatedYearsOfServiceStr  = src.EstimatedYearsOfServiceStr,
            FirstDateOfService          = src.FirstDateOfService,
            FiscalYear                  = src.FiscalYear,
            LeaveServiceDt              = src.LeaveServiceDt,
            MostHistoricDate            = src.MostHistoricDate,
            MoveType                    = src.MoveType,
            MoveType1                   = src.MoveType1,
            MoveType1Sort               = src.MoveType1Sort,
            MoveType2                   = src.MoveType2,
            Name                        = src.Name,
            SameGroup                   = src.SameGroup,
            SameLevel1                  = src.SameLevel1,
            SameOrg                     = src.SameOrg,
            Seq                         = src.Seq,
            SupervisorMove              = src.SupervisorMove,
            NewAction                   = src.NewAction,
            NewActionDt                 = src.NewActionDt,
            NewActionReason             = src.NewActionReason,
            NewActionReasonDescr        = src.NewActionReasonDescr,
            NewAnnualRt                 = src.NewAnnualRt,
            NewBusinessUnit             = src.NewBusinessUnit,
            NewBusinessUnitDescr        = src.NewBusinessUnitDescr,
            NewCity                     = src.NewCity,
            NewClassificationGroup      = src.NewClassificationGroup,
            NewCompRate                 = src.NewCompRate,
            NewCoreBu                   = src.NewCoreBu,
            NewCoreOrg                  = src.NewCoreOrg,
            NewDeptId                   = src.NewDeptId,
            NewDeptIdDescr              = src.NewDeptIdDescr,
            NewDevelopmentRegion        = src.NewDevelopmentRegion,
            NewEmplCtg                  = src.NewEmplCtg,
            NewEmplCtgDescr             = src.NewEmplCtgDescr,
            NewEmplStatus               = src.NewEmplStatus,
            NewEmplStatusDescr          = src.NewEmplStatusDescr,
            NewEndOfDayHrStatus         = src.NewEndOfDayHrStatus,
            NewEndOfDayPerOrg           = src.NewEndOfDayPerOrg,
            NewEstimatedYearsInOrg      = src.NewEstimatedYearsInOrg,
            NewEstimatedYearsInOrgStr   = src.NewEstimatedYearsInOrgStr,
            NewEstimatedYearsInPos      = src.NewEstimatedYearsInPos,
            NewEstimatedYearsInPosStr   = src.NewEstimatedYearsInPosStr,
            NewFirstDateInOrg           = src.NewFirstDateInOrg,
            NewFirstDateInPosition      = src.NewFirstDateInPosition,
            NewGrade                    = src.NewGrade,
            NewHireDate                 = src.NewHireDate,
            NewHourlyRt                 = src.NewHourlyRt,
            NewHrStatus                 = src.NewHrStatus,
            NewIncludedOrExcluded       = src.NewIncludedOrExcluded,
            NewIsSupervisor             = src.NewIsSupervisor,
            NewJobFunction              = src.NewJobFunction,
            NewJobcode                  = src.NewJobcode,
            NewJobcodeDescr             = src.NewJobcodeDescr,
            NewLevel1                   = src.NewLevel1,
            NewLevel2                   = src.NewLevel2,
            NewLevel3                   = src.NewLevel3,
            NewLevel4                   = src.NewLevel4,
            NewLifeCycle                = src.NewLifeCycle,
            NewLocation                 = src.NewLocation,
            NewLocationGroup            = src.NewLocationGroup,
            NewMaxRtHourly              = src.NewMaxRtHourly,
            NewOrganization             = src.NewOrganization,
            NewPerOrg                   = src.NewPerOrg,
            NewPositionDescr            = src.NewPositionDescr,
            NewPositionNbr              = src.NewPositionNbr,
            NewPsa                      = src.NewPsa,
            NewRegionalDistrict         = src.NewRegionalDistrict,
            NewRehireDate               = src.NewRehireDate,
            NewReportsTo                = src.NewReportsTo,
            NewSalAdminPlan             = src.NewSalAdminPlan,
            NewSelectedGroup            = src.NewSelectedGroup,
            NewStdHours                 = src.NewStdHours,
            NewStep                     = src.NewStep,
            NewSupervisor               = src.NewSupervisor,
            PriorAction                 = src.PriorAction,
            PriorActionDt               = src.PriorActionDt,
            PriorActionReason           = src.PriorActionReason,
            PriorActionReasonDescr      = src.PriorActionReasonDescr,
            PriorAnnualRt               = src.PriorAnnualRt,
            PriorBusinessUnit           = src.PriorBusinessUnit,
            PriorBusinessUnitDescr      = src.PriorBusinessUnitDescr,
            PriorCity                   = src.PriorCity,
            PriorClassificationGroup    = src.PriorClassificationGroup,
            PriorCompRate               = src.PriorCompRate,
            PriorCoreBu                 = src.PriorCoreBu,
            PriorCoreOrg                = src.PriorCoreOrg,
            PriorDeptId                 = src.PriorDeptId,
            PriorDeptIdDescr            = src.PriorDeptIdDescr,
            PriorDevelopmentRegion      = src.PriorDevelopmentRegion,
            PriorEffDt                  = src.PriorEffDt,
            PriorEffSeq                 = src.PriorEffSeq,
            PriorEmplCtg                = src.PriorEmplCtg,
            PriorEmplCtgDescr           = src.PriorEmplCtgDescr,
            PriorEmplStatus             = src.PriorEmplStatus,
            PriorEmplStatusDescr        = src.PriorEmplStatusDescr,
            PriorEndOfDayHrStatus       = src.PriorEndOfDayHrStatus,
            PriorEndOfDayPerOrg         = src.PriorEndOfDayPerOrg,
            PriorEstimatedYearsInOrg    = src.PriorEstimatedYearsInOrg,
            PriorEstimatedYearsInOrgStr = src.PriorEstimatedYearsInOrgStr,
            PriorEstimatedYearsInPos    = src.PriorEstimatedYearsInPos,
            PriorEstimatedYearsInPosStr = src.PriorEstimatedYearsInPosStr,
            PriorFirstDateInOrg         = src.PriorFirstDateInOrg,
            PriorFirstDateInPosition    = src.PriorFirstDateInPosition,
            PriorFiscalYear             = src.PriorFiscalYear,
            PriorGrade                  = src.PriorGrade,
            PriorHireDate               = src.PriorHireDate,
            PriorHourlyRt               = src.PriorHourlyRt,
            PriorHrStatus               = src.PriorHrStatus,
            PriorIncludedOrExcluded     = src.PriorIncludedOrExcluded,
            PriorIsSupervisor           = src.PriorIsSupervisor,
            PriorJobFunction            = src.PriorJobFunction,
            PriorJobcode                = src.PriorJobcode,
            PriorJobcodeDescr           = src.PriorJobcodeDescr,
            PriorLevel1                 = src.PriorLevel1,
            PriorLevel2                 = src.PriorLevel2,
            PriorLevel3                 = src.PriorLevel3,
            PriorLevel4                 = src.PriorLevel4,
            PriorLifeCycle              = src.PriorLifeCycle,
            PriorLocation               = src.PriorLocation,
            PriorLocationGroup          = src.PriorLocationGroup,
            PriorMaxRtHourly            = src.PriorMaxRtHourly,
            PriorOrganization           = src.PriorOrganization,
            PriorPerOrg                 = src.PriorPerOrg,
            PriorPositionDescr          = src.PriorPositionDescr,
            PriorPositionNbr            = src.PriorPositionNbr,
            PriorPsa                    = src.PriorPsa,
            PriorRegionalDistrict       = src.PriorRegionalDistrict,
            PriorRehireDate             = src.PriorRehireDate,
            PriorReportsTo              = src.PriorReportsTo,
            PriorSalAdminPlan           = src.PriorSalAdminPlan,
            PriorSelectedGroup          = src.PriorSelectedGroup,
            PriorSeq                    = src.PriorSeq,
            PriorStdHours               = src.PriorStdHours,
            PriorStep                   = src.PriorStep,
            PriorSupervisor             = src.PriorSupervisor,
            RowHash                     = src._RowHash,
            IsActive                    = 1,
            LastUpdatedUtc              = SYSUTCDATETIME()

        -- INSERT new events
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            EmplId, EffDt, EffSeq, EmplRcd,
            CompChange, EstimatedYrsOfService, EstimatedYearsOfService,
            EstimatedYearsOfServiceStr, FirstDateOfService, FiscalYear,
            LeaveServiceDt, MostHistoricDate, MoveType, MoveType1,
            MoveType1Sort, MoveType2, Name, SameGroup, SameLevel1,
            SameOrg, Seq, SupervisorMove,
            NewAction, NewActionDt, NewActionReason, NewActionReasonDescr,
            NewAnnualRt, NewBusinessUnit, NewBusinessUnitDescr, NewCity,
            NewClassificationGroup, NewCompRate, NewCoreBu, NewCoreOrg,
            NewDeptId, NewDeptIdDescr, NewDevelopmentRegion,
            NewEmplCtg, NewEmplCtgDescr, NewEmplStatus, NewEmplStatusDescr,
            NewEndOfDayHrStatus, NewEndOfDayPerOrg,
            NewEstimatedYearsInOrg, NewEstimatedYearsInOrgStr,
            NewEstimatedYearsInPos, NewEstimatedYearsInPosStr,
            NewFirstDateInOrg, NewFirstDateInPosition,
            NewGrade, NewHireDate, NewHourlyRt, NewHrStatus,
            NewIncludedOrExcluded, NewIsSupervisor, NewJobFunction,
            NewJobcode, NewJobcodeDescr,
            NewLevel1, NewLevel2, NewLevel3, NewLevel4,
            NewLifeCycle, NewLocation, NewLocationGroup,
            NewMaxRtHourly, NewOrganization, NewPerOrg,
            NewPositionDescr, NewPositionNbr, NewPsa,
            NewRegionalDistrict, NewRehireDate, NewReportsTo,
            NewSalAdminPlan, NewSelectedGroup, NewStdHours, NewStep, NewSupervisor,
            PriorAction, PriorActionDt, PriorActionReason, PriorActionReasonDescr,
            PriorAnnualRt, PriorBusinessUnit, PriorBusinessUnitDescr, PriorCity,
            PriorClassificationGroup, PriorCompRate, PriorCoreBu, PriorCoreOrg,
            PriorDeptId, PriorDeptIdDescr, PriorDevelopmentRegion,
            PriorEffDt, PriorEffSeq,
            PriorEmplCtg, PriorEmplCtgDescr, PriorEmplStatus, PriorEmplStatusDescr,
            PriorEndOfDayHrStatus, PriorEndOfDayPerOrg,
            PriorEstimatedYearsInOrg, PriorEstimatedYearsInOrgStr,
            PriorEstimatedYearsInPos, PriorEstimatedYearsInPosStr,
            PriorFirstDateInOrg, PriorFirstDateInPosition,
            PriorFiscalYear, PriorGrade, PriorHireDate, PriorHourlyRt,
            PriorHrStatus, PriorIncludedOrExcluded, PriorIsSupervisor,
            PriorJobFunction, PriorJobcode, PriorJobcodeDescr,
            PriorLevel1, PriorLevel2, PriorLevel3, PriorLevel4,
            PriorLifeCycle, PriorLocation, PriorLocationGroup,
            PriorMaxRtHourly, PriorOrganization, PriorPerOrg,
            PriorPositionDescr, PriorPositionNbr, PriorPsa,
            PriorRegionalDistrict, PriorRehireDate, PriorReportsTo,
            PriorSalAdminPlan, PriorSelectedGroup, PriorSeq,
            PriorStdHours, PriorStep, PriorSupervisor,
            RowHash, IsActive, CreatedUtc, LastUpdatedUtc
        )
        VALUES (
            src.EmplId, src.EffDt, src.EffSeq, src.EmplRcd,
            src.CompChange, src.EstimatedYrsOfService, src.EstimatedYearsOfService,
            src.EstimatedYearsOfServiceStr, src.FirstDateOfService, src.FiscalYear,
            src.LeaveServiceDt, src.MostHistoricDate, src.MoveType, src.MoveType1,
            src.MoveType1Sort, src.MoveType2, src.Name, src.SameGroup, src.SameLevel1,
            src.SameOrg, src.Seq, src.SupervisorMove,
            src.NewAction, src.NewActionDt, src.NewActionReason, src.NewActionReasonDescr,
            src.NewAnnualRt, src.NewBusinessUnit, src.NewBusinessUnitDescr, src.NewCity,
            src.NewClassificationGroup, src.NewCompRate, src.NewCoreBu, src.NewCoreOrg,
            src.NewDeptId, src.NewDeptIdDescr, src.NewDevelopmentRegion,
            src.NewEmplCtg, src.NewEmplCtgDescr, src.NewEmplStatus, src.NewEmplStatusDescr,
            src.NewEndOfDayHrStatus, src.NewEndOfDayPerOrg,
            src.NewEstimatedYearsInOrg, src.NewEstimatedYearsInOrgStr,
            src.NewEstimatedYearsInPos, src.NewEstimatedYearsInPosStr,
            src.NewFirstDateInOrg, src.NewFirstDateInPosition,
            src.NewGrade, src.NewHireDate, src.NewHourlyRt, src.NewHrStatus,
            src.NewIncludedOrExcluded, src.NewIsSupervisor, src.NewJobFunction,
            src.NewJobcode, src.NewJobcodeDescr,
            src.NewLevel1, src.NewLevel2, src.NewLevel3, src.NewLevel4,
            src.NewLifeCycle, src.NewLocation, src.NewLocationGroup,
            src.NewMaxRtHourly, src.NewOrganization, src.NewPerOrg,
            src.NewPositionDescr, src.NewPositionNbr, src.NewPsa,
            src.NewRegionalDistrict, src.NewRehireDate, src.NewReportsTo,
            src.NewSalAdminPlan, src.NewSelectedGroup, src.NewStdHours, src.NewStep, src.NewSupervisor,
            src.PriorAction, src.PriorActionDt, src.PriorActionReason, src.PriorActionReasonDescr,
            src.PriorAnnualRt, src.PriorBusinessUnit, src.PriorBusinessUnitDescr, src.PriorCity,
            src.PriorClassificationGroup, src.PriorCompRate, src.PriorCoreBu, src.PriorCoreOrg,
            src.PriorDeptId, src.PriorDeptIdDescr, src.PriorDevelopmentRegion,
            src.PriorEffDt, src.PriorEffSeq,
            src.PriorEmplCtg, src.PriorEmplCtgDescr, src.PriorEmplStatus, src.PriorEmplStatusDescr,
            src.PriorEndOfDayHrStatus, src.PriorEndOfDayPerOrg,
            src.PriorEstimatedYearsInOrg, src.PriorEstimatedYearsInOrgStr,
            src.PriorEstimatedYearsInPos, src.PriorEstimatedYearsInPosStr,
            src.PriorFirstDateInOrg, src.PriorFirstDateInPosition,
            src.PriorFiscalYear, src.PriorGrade, src.PriorHireDate, src.PriorHourlyRt,
            src.PriorHrStatus, src.PriorIncludedOrExcluded, src.PriorIsSupervisor,
            src.PriorJobFunction, src.PriorJobcode, src.PriorJobcodeDescr,
            src.PriorLevel1, src.PriorLevel2, src.PriorLevel3, src.PriorLevel4,
            src.PriorLifeCycle, src.PriorLocation, src.PriorLocationGroup,
            src.PriorMaxRtHourly, src.PriorOrganization, src.PriorPerOrg,
            src.PriorPositionDescr, src.PriorPositionNbr, src.PriorPsa,
            src.PriorRegionalDistrict, src.PriorRehireDate, src.PriorReportsTo,
            src.PriorSalAdminPlan, src.PriorSelectedGroup, src.PriorSeq,
            src.PriorStdHours, src.PriorStep, src.PriorSupervisor,
            src._RowHash, 1, SYSUTCDATETIME(), SYSUTCDATETIME()
        )

        -- SOFT DELETE: event no longer returned by API
        WHEN NOT MATCHED BY SOURCE AND tgt.IsActive = 1
        THEN UPDATE SET
            IsActive       = 0,
            LastUpdatedUtc = SYSUTCDATETIME()

        OUTPUT
            @RunId,
            SYSUTCDATETIME(),
            CASE $action
                WHEN 'INSERT' THEN 'INSERT'
                WHEN 'UPDATE' THEN
                    CASE WHEN deleted.IsActive = 0 AND inserted.IsActive = 1 THEN 'REACTIVATE'
                         WHEN inserted.IsActive = 0                          THEN 'SOFT_DELETE'
                         ELSE 'UPDATE'
                    END
            END,
            inserted.EmplId,
            inserted.EffDt,
            inserted.EffSeq,
            inserted.EmplRcd,
            deleted.RowHash,
            inserted.RowHash,
            CAST(deleted.IsActive  AS NVARCHAR(255)),
            CAST(inserted.IsActive AS NVARCHAR(255)),
            -- header Old/New (all CAST to NVARCHAR(255))
            CAST(deleted.CompChange               AS NVARCHAR(255)), CAST(inserted.CompChange               AS NVARCHAR(255)),
            CAST(deleted.MoveType                 AS NVARCHAR(255)), CAST(inserted.MoveType                 AS NVARCHAR(255)),
            CAST(deleted.MoveType1                AS NVARCHAR(255)), CAST(inserted.MoveType1                AS NVARCHAR(255)),
            CAST(deleted.MoveType2                AS NVARCHAR(255)), CAST(inserted.MoveType2                AS NVARCHAR(255)),
            CAST(deleted.FiscalYear               AS NVARCHAR(255)), CAST(inserted.FiscalYear               AS NVARCHAR(255)),
            CAST(deleted.Name                     AS NVARCHAR(255)), CAST(inserted.Name                     AS NVARCHAR(255)),
            -- New-state key cols Old/New
            CAST(deleted.NewAction                AS NVARCHAR(255)), CAST(inserted.NewAction                AS NVARCHAR(255)),
            CAST(deleted.NewActionReasonDescr     AS NVARCHAR(255)), CAST(inserted.NewActionReasonDescr     AS NVARCHAR(255)),
            CAST(deleted.NewEmplStatus            AS NVARCHAR(255)), CAST(inserted.NewEmplStatus            AS NVARCHAR(255)),
            CAST(deleted.NewEmplCtg               AS NVARCHAR(255)), CAST(inserted.NewEmplCtg               AS NVARCHAR(255)),
            CAST(deleted.NewDeptId                AS NVARCHAR(255)), CAST(inserted.NewDeptId                AS NVARCHAR(255)),
            CAST(deleted.NewDeptIdDescr           AS NVARCHAR(255)), CAST(inserted.NewDeptIdDescr           AS NVARCHAR(255)),
            CAST(deleted.NewLevel1                AS NVARCHAR(255)), CAST(inserted.NewLevel1                AS NVARCHAR(255)),
            CAST(deleted.NewLevel2                AS NVARCHAR(255)), CAST(inserted.NewLevel2                AS NVARCHAR(255)),
            CAST(deleted.NewOrganization          AS NVARCHAR(255)), CAST(inserted.NewOrganization          AS NVARCHAR(255)),
            CAST(deleted.NewSalAdminPlan          AS NVARCHAR(255)), CAST(inserted.NewSalAdminPlan          AS NVARCHAR(255)),
            CAST(deleted.NewGrade                 AS NVARCHAR(255)), CAST(inserted.NewGrade                 AS NVARCHAR(255)),
            CAST(deleted.NewStep                  AS NVARCHAR(255)), CAST(inserted.NewStep                  AS NVARCHAR(255)),
            CAST(deleted.NewAnnualRt              AS NVARCHAR(255)), CAST(inserted.NewAnnualRt              AS NVARCHAR(255)),
            CAST(deleted.NewPositionNbr           AS NVARCHAR(255)), CAST(inserted.NewPositionNbr           AS NVARCHAR(255)),
            CAST(deleted.NewSupervisor            AS NVARCHAR(255)), CAST(inserted.NewSupervisor            AS NVARCHAR(255)),
            -- Prior-state key cols Old/New
            CAST(deleted.PriorAction              AS NVARCHAR(255)), CAST(inserted.PriorAction              AS NVARCHAR(255)),
            CAST(deleted.PriorEmplStatus          AS NVARCHAR(255)), CAST(inserted.PriorEmplStatus          AS NVARCHAR(255)),
            CAST(deleted.PriorEmplCtg             AS NVARCHAR(255)), CAST(inserted.PriorEmplCtg             AS NVARCHAR(255)),
            CAST(deleted.PriorDeptId              AS NVARCHAR(255)), CAST(inserted.PriorDeptId              AS NVARCHAR(255)),
            CAST(deleted.PriorDeptIdDescr         AS NVARCHAR(255)), CAST(inserted.PriorDeptIdDescr         AS NVARCHAR(255)),
            CAST(deleted.PriorLevel1              AS NVARCHAR(255)), CAST(inserted.PriorLevel1              AS NVARCHAR(255)),
            CAST(deleted.PriorOrganization        AS NVARCHAR(255)), CAST(inserted.PriorOrganization        AS NVARCHAR(255)),
            CAST(deleted.PriorSalAdminPlan        AS NVARCHAR(255)), CAST(inserted.PriorSalAdminPlan        AS NVARCHAR(255)),
            CAST(deleted.PriorGrade               AS NVARCHAR(255)), CAST(inserted.PriorGrade               AS NVARCHAR(255)),
            CAST(deleted.PriorStep                AS NVARCHAR(255)), CAST(inserted.PriorStep                AS NVARCHAR(255)),
            CAST(deleted.PriorAnnualRt            AS NVARCHAR(255)), CAST(inserted.PriorAnnualRt            AS NVARCHAR(255))
        INTO dbo.Peoplesoft_HEM_Audit (
            RunId, AuditDtmUtc, ActionType,
            EmplId, EffDt, EffSeq, EmplRcd,
            OldRowHash, NewRowHash, OldIsActive, NewIsActive,
            OldCompChange,           NewCompChange,
            OldMoveType,             NewMoveType,
            OldMoveType1,            NewMoveType1,
            OldMoveType2,            NewMoveType2,
            OldFiscalYear,           NewFiscalYear,
            OldName,                 NewName,
            OldNewAction,            NewNewAction,
            OldNewActionReasonDescr, NewNewActionReasonDescr,
            OldNewEmplStatus,        NewNewEmplStatus,
            OldNewEmplCtg,           NewNewEmplCtg,
            OldNewDeptId,            NewNewDeptId,
            OldNewDeptIdDescr,       NewNewDeptIdDescr,
            OldNewLevel1,            NewNewLevel1,
            OldNewLevel2,            NewNewLevel2,
            OldNewOrganization,      NewNewOrganization,
            OldNewSalAdminPlan,      NewNewSalAdminPlan,
            OldNewGrade,             NewNewGrade,
            OldNewStep,              NewNewStep,
            OldNewAnnualRt,          NewNewAnnualRt,
            OldNewPositionNbr,       NewNewPositionNbr,
            OldNewSupervisor,        NewNewSupervisor,
            OldPriorAction,          NewPriorAction,
            OldPriorEmplStatus,      NewPriorEmplStatus,
            OldPriorEmplCtg,         NewPriorEmplCtg,
            OldPriorDeptId,          NewPriorDeptId,
            OldPriorDeptIdDescr,     NewPriorDeptIdDescr,
            OldPriorLevel1,          NewPriorLevel1,
            OldPriorOrganization,    NewPriorOrganization,
            OldPriorSalAdminPlan,    NewPriorSalAdminPlan,
            OldPriorGrade,           NewPriorGrade,
            OldPriorStep,            NewPriorStep,
            OldPriorAnnualRt,        NewPriorAnnualRt
        );

        COMMIT;

        SELECT
            CAST(@RunId AS NVARCHAR(36))                                                       AS RunId,
            (SELECT COUNT(*) FROM dbo.Peoplesoft_HEM_Audit WHERE RunId = @RunId AND ActionType = 'INSERT')      AS Inserted,
            (SELECT COUNT(*) FROM dbo.Peoplesoft_HEM_Audit WHERE RunId = @RunId AND ActionType = 'UPDATE')      AS Updated,
            (SELECT COUNT(*) FROM dbo.Peoplesoft_HEM_Audit WHERE RunId = @RunId AND ActionType = 'SOFT_DELETE') AS SoftDeleted,
            (SELECT COUNT(*) FROM dbo.Peoplesoft_HEM_Audit WHERE RunId = @RunId AND ActionType = 'REACTIVATE')  AS Reactivated,
            (SELECT COUNT(*) FROM dbo.Peoplesoft_HEM WHERE IsActive = 1)                       AS ActiveTarget,
            SYSUTCDATETIME()                                                                   AS CompletedUtc;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO
