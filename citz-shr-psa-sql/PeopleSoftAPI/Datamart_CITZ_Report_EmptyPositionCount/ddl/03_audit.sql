SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================
-- Audit table: Peoplesoft_EPC_Audit
-- API: Datamart_CITZ_Report_EmptyPositionCount (Empty Position Count)
-- Business key: Position
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

IF OBJECT_ID('dbo.Peoplesoft_EPC_Audit', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_EPC_Audit;
GO

CREATE TABLE dbo.Peoplesoft_EPC_Audit
(
    AuditId                        BIGINT           NOT NULL IDENTITY(1,1),
    RunId                          UNIQUEIDENTIFIER NOT NULL,
    AuditDtmUtc                    DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ActionType                     VARCHAR(12)      NOT NULL,  -- INSERT | UPDATE | SOFT_DELETE | REACTIVATE

    -- Business key
    Position                       NVARCHAR(255)    NULL,

    -- Row hash for quick change detection
    OldRowHash                     VARBINARY(32)    NULL,
    NewRowHash                     VARBINARY(32)    NULL,

    -- Control column deltas (NVARCHAR(255) standard)
    OldIsActive                    NVARCHAR(255)    NULL,
    NewIsActive                    NVARCHAR(255)    NULL,

    -- Tracked column deltas (Old) -- all NVARCHAR(255)
    OldBaseIncumbents              NVARCHAR(255)    NULL,
    OldBusinessUnitDescr           NVARCHAR(255)    NULL,
    OldCity                        NVARCHAR(255)    NULL,
    OldClassificationGroup         NVARCHAR(255)    NULL,
    OldCore                        NVARCHAR(255)    NULL,
    OldCreateEffDt                 NVARCHAR(255)    NULL,
    OldDeptId                      NVARCHAR(255)    NULL,
    OldDeptIdDesc                  NVARCHAR(255)    NULL,
    OldDevelopmentRegion           NVARCHAR(255)    NULL,
    OldEmptyEffDt                  NVARCHAR(255)    NULL,
    OldEmptyPosition               NVARCHAR(255)    NULL,
    OldExcludedOrIncluded          NVARCHAR(255)    NULL,
    OldIncumbentCount              NVARCHAR(255)    NULL,
    OldIncumbents                  NVARCHAR(255)    NULL,
    OldJobCode                     NVARCHAR(255)    NULL,
    OldJobCodeDesc                 NVARCHAR(255)    NULL,
    OldJobFunc                     NVARCHAR(255)    NULL,
    OldJobReqOpenDate              NVARCHAR(255)    NULL,
    OldJobReqStatus                NVARCHAR(255)    NULL,
    OldLastIncumbents              NVARCHAR(255)    NULL,
    OldLocation                    NVARCHAR(255)    NULL,
    OldNocCode                     NVARCHAR(255)    NULL,
    OldNocCodeDescr                NVARCHAR(255)    NULL,
    OldOrganization                NVARCHAR(255)    NULL,
    OldPosStatusDescr              NVARCHAR(255)    NULL,
    OldPositionEmptyGt1Year        NVARCHAR(255)    NULL,
    OldPositionHasBaseIncumbent    NVARCHAR(255)    NULL,
    OldPositionTitle               NVARCHAR(255)    NULL,
    OldProgram                     NVARCHAR(255)    NULL,
    OldProgramBranch               NVARCHAR(255)    NULL,
    OldProgramDivision             NVARCHAR(255)    NULL,
    OldProvincialQuadrant          NVARCHAR(255)    NULL,
    OldRegDistrictDesc             NVARCHAR(255)    NULL,
    OldRegOrTempDescr              NVARCHAR(255)    NULL,
    OldReportsTo                   NVARCHAR(255)    NULL,
    OldSupervisor                  NVARCHAR(255)    NULL,
    OldYearsEmpty                  NVARCHAR(255)    NULL,

    -- Tracked column deltas (New) -- all NVARCHAR(255)
    NewBaseIncumbents              NVARCHAR(255)    NULL,
    NewBusinessUnitDescr           NVARCHAR(255)    NULL,
    NewCity                        NVARCHAR(255)    NULL,
    NewClassificationGroup         NVARCHAR(255)    NULL,
    NewCore                        NVARCHAR(255)    NULL,
    NewCreateEffDt                 NVARCHAR(255)    NULL,
    NewDeptId                      NVARCHAR(255)    NULL,
    NewDeptIdDesc                  NVARCHAR(255)    NULL,
    NewDevelopmentRegion           NVARCHAR(255)    NULL,
    NewEmptyEffDt                  NVARCHAR(255)    NULL,
    NewEmptyPosition               NVARCHAR(255)    NULL,
    NewExcludedOrIncluded          NVARCHAR(255)    NULL,
    NewIncumbentCount              NVARCHAR(255)    NULL,
    NewIncumbents                  NVARCHAR(255)    NULL,
    NewJobCode                     NVARCHAR(255)    NULL,
    NewJobCodeDesc                 NVARCHAR(255)    NULL,
    NewJobFunc                     NVARCHAR(255)    NULL,
    NewJobReqOpenDate              NVARCHAR(255)    NULL,
    NewJobReqStatus                NVARCHAR(255)    NULL,
    NewLastIncumbents              NVARCHAR(255)    NULL,
    NewLocation                    NVARCHAR(255)    NULL,
    NewNocCode                     NVARCHAR(255)    NULL,
    NewNocCodeDescr                NVARCHAR(255)    NULL,
    NewOrganization                NVARCHAR(255)    NULL,
    NewPosStatusDescr              NVARCHAR(255)    NULL,
    NewPositionEmptyGt1Year        NVARCHAR(255)    NULL,
    NewPositionHasBaseIncumbent    NVARCHAR(255)    NULL,
    NewPositionTitle               NVARCHAR(255)    NULL,
    NewProgram                     NVARCHAR(255)    NULL,
    NewProgramBranch               NVARCHAR(255)    NULL,
    NewProgramDivision             NVARCHAR(255)    NULL,
    NewProvincialQuadrant          NVARCHAR(255)    NULL,
    NewRegDistrictDesc             NVARCHAR(255)    NULL,
    NewRegOrTempDescr              NVARCHAR(255)    NULL,
    NewReportsTo                   NVARCHAR(255)    NULL,
    NewSupervisor                  NVARCHAR(255)    NULL,
    NewYearsEmpty                  NVARCHAR(255)    NULL,

    CONSTRAINT PK_EPC_Audit PRIMARY KEY CLUSTERED (AuditId)
);
GO

CREATE INDEX IX_EPC_Audit_RunId   ON dbo.Peoplesoft_EPC_Audit (RunId);
CREATE INDEX IX_EPC_Audit_Pos     ON dbo.Peoplesoft_EPC_Audit (Position);
GO
