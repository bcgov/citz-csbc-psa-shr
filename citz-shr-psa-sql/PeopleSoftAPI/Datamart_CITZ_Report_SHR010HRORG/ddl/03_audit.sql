-- =============================================================================
-- Audit table: Peoplesoft_SHR010HRORG_Audit
-- API: Datamart_CITZ_Report_SHR010HRORG
-- Business key: EmplId
-- Tracks: INSERT, UPDATE, SOFT_DELETE, REACTIVATE actions from MERGE proc
-- Report metadata: AsOfDate EXCLUDED (not tracked)
-- Append-only; do NOT truncate between runs
--
-- TYPE-SAFETY STANDARD (applies to all APIs):
--   All Old/New columns are NVARCHAR(255). The MERGE OUTPUT clause CASTs
--   every deleted.*/inserted.* value to NVARCHAR(255) before insert.
--   Never use DATE/INT/DECIMAL/BIT for Old/New columns -- they break the
--   MERGE OUTPUT bind on schema drift.
-- =============================================================================

IF OBJECT_ID('dbo.Peoplesoft_SHR010HRORG_Audit', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_SHR010HRORG_Audit;
GO

CREATE TABLE dbo.Peoplesoft_SHR010HRORG_Audit
(
    AuditId          BIGINT IDENTITY(1,1) PRIMARY KEY,
    RunId            UNIQUEIDENTIFIER NOT NULL,
    AuditDtmUtc      DATETIME2(0)     NOT NULL
        CONSTRAINT DF_Peoplesoft_SHR010HRORG_Audit_AuditDtmUtc DEFAULT SYSUTCDATETIME(),

    ActionType       VARCHAR(12)      NOT NULL,  -- INSERT / UPDATE / SOFT_DELETE / REACTIVATE
    EmplId           NVARCHAR(20)     NOT NULL,  -- Business key

    OldRowHash       VARBINARY(32)    NULL,
    NewRowHash       VARBINARY(32)    NULL,

    OldIsActive      NVARCHAR(255)    NULL,
    NewIsActive      NVARCHAR(255)    NULL,

    -- NOTE: AsOfDate is excluded from audit (report metadata -- same for all rows per run).

    -- OLD values (all NVARCHAR(255))
    OldName                         NVARCHAR(255) NULL,
    OldIdir                         NVARCHAR(255) NULL,
    OldEmailId                      NVARCHAR(255) NULL,
    OldEmplStatus                   NVARCHAR(255) NULL,
    OldEmplType                     NVARCHAR(255) NULL,
    OldEmplCtg                      NVARCHAR(255) NULL,
    OldEmplCtgL1                    NVARCHAR(255) NULL,
    OldEmplRcd                      NVARCHAR(255) NULL,
    OldApptStatus                   NVARCHAR(255) NULL,
    OldApptStatusCode               NVARCHAR(255) NULL,
    OldBirthdate                    NVARCHAR(255) NULL,
    OldHireDt                       NVARCHAR(255) NULL,
    OldLastHireDt                   NVARCHAR(255) NULL,
    OldMostHistoricDate             NVARCHAR(255) NULL,
    OldFirstDateInOrganization      NVARCHAR(255) NULL,
    OldFirstDateInPosition          NVARCHAR(255) NULL,
    OldFutureReturnDate             NVARCHAR(255) NULL,
    OldPositionNbr                  NVARCHAR(255) NULL,
    OldTgbBasePosition              NVARCHAR(255) NULL,
    OldPositionDataDescr            NVARCHAR(255) NULL,
    OldJobCode                      NVARCHAR(255) NULL,
    OldJobCodeDescr                 NVARCHAR(255) NULL,
    OldJobFunction                  NVARCHAR(255) NULL,
    OldSalAdminPlan                 NVARCHAR(255) NULL,
    OldGrade                        NVARCHAR(255) NULL,
    OldStep                         NVARCHAR(255) NULL,
    OldStdHours                     NVARCHAR(255) NULL,
    OldAnnualRt                     NVARCHAR(255) NULL,
    OldCompRate                     NVARCHAR(255) NULL,
    OldHourlyRt                     NVARCHAR(255) NULL,
    OldOrganization                 NVARCHAR(255) NULL,
    OldBusinessUnit                 NVARCHAR(255) NULL,
    OldDeptId                       NVARCHAR(255) NULL,
    OldDeptDescr                    NVARCHAR(255) NULL,
    OldLevel1                       NVARCHAR(255) NULL,
    OldLevel2                       NVARCHAR(255) NULL,
    OldLevel3                       NVARCHAR(255) NULL,
    OldDescr                        NVARCHAR(255) NULL,
    OldCore                         NVARCHAR(255) NULL,
    OldCoreGovernment               NVARCHAR(255) NULL,
    OldSector                       NVARCHAR(255) NULL,
    OldPublicService                NVARCHAR(255) NULL,
    OldPublicServiceAct             NVARCHAR(255) NULL,
    OldTreasuryBoard                NVARCHAR(255) NULL,
    OldOfficerCode                  NVARCHAR(255) NULL,
    OldNocCode                      NVARCHAR(255) NULL,
    OldNocCodeDescr                 NVARCHAR(255) NULL,
    OldReportsTo                    NVARCHAR(255) NULL,
    OldLocation                     NVARCHAR(255) NULL,
    OldLocationCity                 NVARCHAR(255) NULL,
    OldAgeGroup1                    NVARCHAR(255) NULL,
    OldAgeGroup2                    NVARCHAR(255) NULL,
    OldAge                          NVARCHAR(255) NULL,
    OldGeneration                   NVARCHAR(255) NULL,
    OldEligibleForPension           NVARCHAR(255) NULL,
    OldEligibleForUnreducedPension  NVARCHAR(255) NULL,
    OldSupervisor                   NVARCHAR(255) NULL,
    OldSupervEmail                  NVARCHAR(255) NULL,
    OldSupervSalPlan                NVARCHAR(255) NULL,
    OldSupervisorStatus             NVARCHAR(255) NULL,
    OldLayoffLeaveStopPayReason     NVARCHAR(255) NULL,
    OldLayoffLeaveStopPayStartDate  NVARCHAR(255) NULL,

    -- NEW values (all NVARCHAR(255))
    NewName                         NVARCHAR(255) NULL,
    NewIdir                         NVARCHAR(255) NULL,
    NewEmailId                      NVARCHAR(255) NULL,
    NewEmplStatus                   NVARCHAR(255) NULL,
    NewEmplType                     NVARCHAR(255) NULL,
    NewEmplCtg                      NVARCHAR(255) NULL,
    NewEmplCtgL1                    NVARCHAR(255) NULL,
    NewEmplRcd                      NVARCHAR(255) NULL,
    NewApptStatus                   NVARCHAR(255) NULL,
    NewApptStatusCode               NVARCHAR(255) NULL,
    NewBirthdate                    NVARCHAR(255) NULL,
    NewHireDt                       NVARCHAR(255) NULL,
    NewLastHireDt                   NVARCHAR(255) NULL,
    NewMostHistoricDate             NVARCHAR(255) NULL,
    NewFirstDateInOrganization      NVARCHAR(255) NULL,
    NewFirstDateInPosition          NVARCHAR(255) NULL,
    NewFutureReturnDate             NVARCHAR(255) NULL,
    NewPositionNbr                  NVARCHAR(255) NULL,
    NewTgbBasePosition              NVARCHAR(255) NULL,
    NewPositionDataDescr            NVARCHAR(255) NULL,
    NewJobCode                      NVARCHAR(255) NULL,
    NewJobCodeDescr                 NVARCHAR(255) NULL,
    NewJobFunction                  NVARCHAR(255) NULL,
    NewSalAdminPlan                 NVARCHAR(255) NULL,
    NewGrade                        NVARCHAR(255) NULL,
    NewStep                         NVARCHAR(255) NULL,
    NewStdHours                     NVARCHAR(255) NULL,
    NewAnnualRt                     NVARCHAR(255) NULL,
    NewCompRate                     NVARCHAR(255) NULL,
    NewHourlyRt                     NVARCHAR(255) NULL,
    NewOrganization                 NVARCHAR(255) NULL,
    NewBusinessUnit                 NVARCHAR(255) NULL,
    NewDeptId                       NVARCHAR(255) NULL,
    NewDeptDescr                    NVARCHAR(255) NULL,
    NewLevel1                       NVARCHAR(255) NULL,
    NewLevel2                       NVARCHAR(255) NULL,
    NewLevel3                       NVARCHAR(255) NULL,
    NewDescr                        NVARCHAR(255) NULL,
    NewCore                         NVARCHAR(255) NULL,
    NewCoreGovernment               NVARCHAR(255) NULL,
    NewSector                       NVARCHAR(255) NULL,
    NewPublicService                NVARCHAR(255) NULL,
    NewPublicServiceAct             NVARCHAR(255) NULL,
    NewTreasuryBoard                NVARCHAR(255) NULL,
    NewOfficerCode                  NVARCHAR(255) NULL,
    NewNocCode                      NVARCHAR(255) NULL,
    NewNocCodeDescr                 NVARCHAR(255) NULL,
    NewReportsTo                    NVARCHAR(255) NULL,
    NewLocation                     NVARCHAR(255) NULL,
    NewLocationCity                 NVARCHAR(255) NULL,
    NewAgeGroup1                    NVARCHAR(255) NULL,
    NewAgeGroup2                    NVARCHAR(255) NULL,
    NewAge                          NVARCHAR(255) NULL,
    NewGeneration                   NVARCHAR(255) NULL,
    NewEligibleForPension           NVARCHAR(255) NULL,
    NewEligibleForUnreducedPension  NVARCHAR(255) NULL,
    NewSupervisor                   NVARCHAR(255) NULL,
    NewSupervEmail                  NVARCHAR(255) NULL,
    NewSupervSalPlan                NVARCHAR(255) NULL,
    NewSupervisorStatus             NVARCHAR(255) NULL,
    NewLayoffLeaveStopPayReason     NVARCHAR(255) NULL,
    NewLayoffLeaveStopPayStartDate  NVARCHAR(255) NULL
);
GO

CREATE INDEX IX_Peoplesoft_SHR010HRORG_Audit_RunId
    ON dbo.Peoplesoft_SHR010HRORG_Audit (RunId);
GO

CREATE INDEX IX_Peoplesoft_SHR010HRORG_Audit_EmplId
    ON dbo.Peoplesoft_SHR010HRORG_Audit (EmplId);
GO
