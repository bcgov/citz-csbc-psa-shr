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
-- =============================================================================

IF OBJECT_ID('dbo.Peoplesoft_EPC_Audit', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_EPC_Audit;
GO

CREATE TABLE dbo.Peoplesoft_EPC_Audit
(
    AuditId                        INT             NOT NULL IDENTITY(1,1),
    RunId                          UNIQUEIDENTIFIER NOT NULL,
    AuditDtmUtc                    DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    ActionType                     NVARCHAR(20)    NOT NULL,  -- INSERT | UPDATE | SOFT_DELETE | REACTIVATE

    -- Business key
    Position                       NVARCHAR(20)    NULL,

    -- Row hash for quick change detection
    OldRowHash                     BINARY(32)      NULL,
    NewRowHash                     BINARY(32)      NULL,

    -- Control column deltas
    OldIsActive                    BIT             NULL,
    NewIsActive                    BIT             NULL,

    -- Tracked column deltas (Old)
    OldBaseIncumbents              NVARCHAR(500)   NULL,
    OldBusinessUnitDescr           NVARCHAR(255)   NULL,
    OldCity                        NVARCHAR(100)   NULL,
    OldClassificationGroup         NVARCHAR(255)   NULL,
    OldCore                        NVARCHAR(20)    NULL,
    OldCreateEffDt                 DATE            NULL,
    OldDeptId                      NVARCHAR(20)    NULL,
    OldDeptIdDesc                  NVARCHAR(255)   NULL,
    OldDevelopmentRegion           NVARCHAR(100)   NULL,
    OldEmptyEffDt                  DATE            NULL,
    OldEmptyPosition               NVARCHAR(10)    NULL,
    OldExcludedOrIncluded          NVARCHAR(20)    NULL,
    OldIncumbentCount              INT             NULL,
    OldIncumbents                  NVARCHAR(500)   NULL,
    OldJobCode                     NVARCHAR(20)    NULL,
    OldJobCodeDesc                 NVARCHAR(255)   NULL,
    OldJobFunc                     NVARCHAR(20)    NULL,
    OldJobReqOpenDate              DATE            NULL,
    OldJobReqStatus                NVARCHAR(50)    NULL,
    OldLastIncumbents              NVARCHAR(500)   NULL,
    OldLocation                    NVARCHAR(20)    NULL,
    OldNocCode                     NVARCHAR(20)    NULL,
    OldNocCodeDescr                NVARCHAR(255)   NULL,
    OldOrganization                NVARCHAR(100)   NULL,
    OldPosStatusDescr              NVARCHAR(100)   NULL,
    OldPositionEmptyGt1Year        NVARCHAR(10)    NULL,
    OldPositionHasBaseIncumbent    NVARCHAR(10)    NULL,
    OldPositionTitle               NVARCHAR(500)   NULL,
    OldProgram                     NVARCHAR(255)   NULL,
    OldProgramBranch               NVARCHAR(255)   NULL,
    OldProgramDivision             NVARCHAR(255)   NULL,
    OldProvincialQuadrant          NVARCHAR(100)   NULL,
    OldRegDistrictDesc             NVARCHAR(100)   NULL,
    OldRegOrTempDescr              NVARCHAR(50)    NULL,
    OldReportsTo                   NVARCHAR(20)    NULL,
    OldSupervisor                  NVARCHAR(500)   NULL,
    OldYearsEmpty                  DECIMAL(10,4)   NULL,

    -- Tracked column deltas (New)
    NewBaseIncumbents              NVARCHAR(500)   NULL,
    NewBusinessUnitDescr           NVARCHAR(255)   NULL,
    NewCity                        NVARCHAR(100)   NULL,
    NewClassificationGroup         NVARCHAR(255)   NULL,
    NewCore                        NVARCHAR(20)    NULL,
    NewCreateEffDt                 DATE            NULL,
    NewDeptId                      NVARCHAR(20)    NULL,
    NewDeptIdDesc                  NVARCHAR(255)   NULL,
    NewDevelopmentRegion           NVARCHAR(100)   NULL,
    NewEmptyEffDt                  DATE            NULL,
    NewEmptyPosition               NVARCHAR(10)    NULL,
    NewExcludedOrIncluded          NVARCHAR(20)    NULL,
    NewIncumbentCount              INT             NULL,
    NewIncumbents                  NVARCHAR(500)   NULL,
    NewJobCode                     NVARCHAR(20)    NULL,
    NewJobCodeDesc                 NVARCHAR(255)   NULL,
    NewJobFunc                     NVARCHAR(20)    NULL,
    NewJobReqOpenDate              DATE            NULL,
    NewJobReqStatus                NVARCHAR(50)    NULL,
    NewLastIncumbents              NVARCHAR(500)   NULL,
    NewLocation                    NVARCHAR(20)    NULL,
    NewNocCode                     NVARCHAR(20)    NULL,
    NewNocCodeDescr                NVARCHAR(255)   NULL,
    NewOrganization                NVARCHAR(100)   NULL,
    NewPosStatusDescr              NVARCHAR(100)   NULL,
    NewPositionEmptyGt1Year        NVARCHAR(10)    NULL,
    NewPositionHasBaseIncumbent    NVARCHAR(10)    NULL,
    NewPositionTitle               NVARCHAR(500)   NULL,
    NewProgram                     NVARCHAR(255)   NULL,
    NewProgramBranch               NVARCHAR(255)   NULL,
    NewProgramDivision             NVARCHAR(255)   NULL,
    NewProvincialQuadrant          NVARCHAR(100)   NULL,
    NewRegDistrictDesc             NVARCHAR(100)   NULL,
    NewRegOrTempDescr              NVARCHAR(50)    NULL,
    NewReportsTo                   NVARCHAR(20)    NULL,
    NewSupervisor                  NVARCHAR(500)   NULL,
    NewYearsEmpty                  DECIMAL(10,4)   NULL,

    CONSTRAINT PK_EPC_Audit PRIMARY KEY CLUSTERED (AuditId)
);
GO

CREATE INDEX IX_EPC_Audit_RunId   ON dbo.Peoplesoft_EPC_Audit (RunId);
CREATE INDEX IX_EPC_Audit_Pos     ON dbo.Peoplesoft_EPC_Audit (Position);
GO
