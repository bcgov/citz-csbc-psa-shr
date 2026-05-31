-- Target (authoritative) table for Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ
-- Business key: EmplId + EffDt + EffSeq + EmplRcd
-- RowHash: VARBINARY(32) — SHA2-256 of all 136 data columns; used in MERGE WHEN MATCHED condition
--          to efficiently detect any column change without comparing 136 columns individually.
--          Pattern adopted for tables with 100+ data columns.

SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.Peoplesoft_HEM', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_HEM;
GO

CREATE TABLE dbo.Peoplesoft_HEM
(
    -- ── Business key ─────────────────────────────────────────────────────────
    EmplId                           NVARCHAR(20)   NOT NULL,  -- JSON: "EmplID"
    EffDt                            DATE           NOT NULL,  -- JSON: "EFFDT"
    EffSeq                           INT            NOT NULL,  -- JSON: "EFFSEQ"
    EmplRcd                          INT            NOT NULL,  -- JSON: "Empl_RCD"

    -- ── Event header ─────────────────────────────────────────────────────────
    CompChange                       NVARCHAR(100)  NULL,
    EstimatedYrsOfService            INT            NULL,
    EstimatedYearsOfService          INT            NULL,
    EstimatedYearsOfServiceStr       NVARCHAR(100)  NULL,
    FirstDateOfService               DATE           NULL,
    FiscalYear                       INT            NULL,
    LeaveServiceDt                   DATE           NULL,
    MostHistoricDate                 DATE           NULL,
    MoveType                         NVARCHAR(50)   NULL,
    MoveType1                        NVARCHAR(50)   NULL,
    MoveType1Sort                    INT            NULL,
    MoveType2                        NVARCHAR(100)  NULL,
    Name                             NVARCHAR(255)  NULL,
    SameGroup                        NVARCHAR(10)   NULL,
    SameLevel1                       NVARCHAR(10)   NULL,
    SameOrg                          NVARCHAR(10)   NULL,
    Seq                              INT            NULL,
    SupervisorMove                   NVARCHAR(100)  NULL,

    -- ── New state columns ────────────────────────────────────────────────────
    NewAction                        NVARCHAR(10)   NULL,
    NewActionDt                      DATE           NULL,
    NewActionReason                  NVARCHAR(10)   NULL,
    NewActionReasonDescr             NVARCHAR(255)  NULL,
    NewAnnualRt                      DECIMAL(18,4)  NULL,
    NewBusinessUnit                  NVARCHAR(20)   NULL,
    NewBusinessUnitDescr             NVARCHAR(255)  NULL,
    NewCity                          NVARCHAR(100)  NULL,
    NewClassificationGroup           NVARCHAR(100)  NULL,
    NewCompRate                      DECIMAL(18,4)  NULL,
    NewCoreBu                        NVARCHAR(20)   NULL,
    NewCoreOrg                       NVARCHAR(20)   NULL,
    NewDeptId                        NVARCHAR(50)   NULL,
    NewDeptIdDescr                   NVARCHAR(255)  NULL,
    NewDevelopmentRegion             NVARCHAR(100)  NULL,
    NewEmplCtg                       NVARCHAR(20)   NULL,
    NewEmplCtgDescr                  NVARCHAR(100)  NULL,
    NewEmplStatus                    NVARCHAR(10)   NULL,
    NewEmplStatusDescr               NVARCHAR(100)  NULL,
    NewEndOfDayHrStatus              NVARCHAR(10)   NULL,
    NewEndOfDayPerOrg                NVARCHAR(20)   NULL,
    NewEstimatedYearsInOrg           INT            NULL,
    NewEstimatedYearsInOrgStr        NVARCHAR(100)  NULL,
    NewEstimatedYearsInPos           INT            NULL,
    NewEstimatedYearsInPosStr        NVARCHAR(100)  NULL,
    NewFirstDateInOrg                DATE           NULL,
    NewFirstDateInPosition           DATE           NULL,
    NewGrade                         NVARCHAR(20)   NULL,
    NewHireDate                      DATE           NULL,
    NewHourlyRt                      DECIMAL(18,4)  NULL,
    NewHrStatus                      NVARCHAR(10)   NULL,
    NewIncludedOrExcluded            NVARCHAR(50)   NULL,
    NewIsSupervisor                  NVARCHAR(10)   NULL,
    NewJobFunction                   NVARCHAR(20)   NULL,
    NewJobcode                       NVARCHAR(20)   NULL,
    NewJobcodeDescr                  NVARCHAR(255)  NULL,
    NewLevel1                        NVARCHAR(255)  NULL,
    NewLevel2                        NVARCHAR(255)  NULL,
    NewLevel3                        NVARCHAR(255)  NULL,
    NewLevel4                        NVARCHAR(255)  NULL,
    NewLifeCycle                     NVARCHAR(50)   NULL,
    NewLocation                      NVARCHAR(50)   NULL,
    NewLocationGroup                 NVARCHAR(100)  NULL,
    NewMaxRtHourly                   DECIMAL(18,4)  NULL,
    NewOrganization                  NVARCHAR(255)  NULL,
    NewPerOrg                        NVARCHAR(20)   NULL,
    NewPositionDescr                 NVARCHAR(255)  NULL,
    NewPositionNbr                   NVARCHAR(20)   NULL,
    NewPsa                           NVARCHAR(10)   NULL,
    NewRegionalDistrict              NVARCHAR(100)  NULL,
    NewRehireDate                    DATE           NULL,
    NewReportsTo                     NVARCHAR(20)   NULL,
    NewSalAdminPlan                  NVARCHAR(20)   NULL,
    NewSelectedGroup                 NVARCHAR(10)   NULL,
    NewStdHours                      DECIMAL(6,2)   NULL,
    NewStep                          INT            NULL,
    NewSupervisor                    NVARCHAR(255)  NULL,

    -- ── Prior state columns ──────────────────────────────────────────────────
    PriorAction                      NVARCHAR(10)   NULL,
    PriorActionDt                    DATE           NULL,
    PriorActionReason                NVARCHAR(10)   NULL,
    PriorActionReasonDescr           NVARCHAR(255)  NULL,
    PriorAnnualRt                    DECIMAL(18,4)  NULL,
    PriorBusinessUnit                NVARCHAR(20)   NULL,
    PriorBusinessUnitDescr           NVARCHAR(255)  NULL,
    PriorCity                        NVARCHAR(100)  NULL,
    PriorClassificationGroup         NVARCHAR(100)  NULL,
    PriorCompRate                    DECIMAL(18,4)  NULL,
    PriorCoreBu                      NVARCHAR(20)   NULL,
    PriorCoreOrg                     NVARCHAR(20)   NULL,
    PriorDeptId                      NVARCHAR(50)   NULL,
    PriorDeptIdDescr                 NVARCHAR(255)  NULL,
    PriorDevelopmentRegion           NVARCHAR(100)  NULL,
    PriorEffDt                       DATE           NULL,
    PriorEffSeq                      INT            NULL,
    PriorEmplCtg                     NVARCHAR(20)   NULL,
    PriorEmplCtgDescr                NVARCHAR(100)  NULL,
    PriorEmplStatus                  NVARCHAR(10)   NULL,
    PriorEmplStatusDescr             NVARCHAR(100)  NULL,
    PriorEndOfDayHrStatus            NVARCHAR(10)   NULL,
    PriorEndOfDayPerOrg              NVARCHAR(20)   NULL,
    PriorEstimatedYearsInOrg         INT            NULL,
    PriorEstimatedYearsInOrgStr      NVARCHAR(100)  NULL,
    PriorEstimatedYearsInPos         INT            NULL,
    PriorEstimatedYearsInPosStr      NVARCHAR(100)  NULL,
    PriorFirstDateInOrg              DATE           NULL,
    PriorFirstDateInPosition         DATE           NULL,
    PriorFiscalYear                  INT            NULL,
    PriorGrade                       NVARCHAR(20)   NULL,
    PriorHireDate                    DATE           NULL,
    PriorHourlyRt                    DECIMAL(18,4)  NULL,
    PriorHrStatus                    NVARCHAR(10)   NULL,
    PriorIncludedOrExcluded          NVARCHAR(50)   NULL,
    PriorIsSupervisor                NVARCHAR(10)   NULL,
    PriorJobFunction                 NVARCHAR(20)   NULL,
    PriorJobcode                     NVARCHAR(20)   NULL,
    PriorJobcodeDescr                NVARCHAR(255)  NULL,
    PriorLevel1                      NVARCHAR(255)  NULL,
    PriorLevel2                      NVARCHAR(255)  NULL,
    PriorLevel3                      NVARCHAR(255)  NULL,
    PriorLevel4                      NVARCHAR(255)  NULL,
    PriorLifeCycle                   NVARCHAR(50)   NULL,
    PriorLocation                    NVARCHAR(50)   NULL,
    PriorLocationGroup               NVARCHAR(100)  NULL,
    PriorMaxRtHourly                 DECIMAL(18,4)  NULL,
    PriorOrganization                NVARCHAR(255)  NULL,
    PriorPerOrg                      NVARCHAR(20)   NULL,
    PriorPositionDescr               NVARCHAR(255)  NULL,
    PriorPositionNbr                 NVARCHAR(20)   NULL,
    PriorPsa                         NVARCHAR(10)   NULL,
    PriorRegionalDistrict            NVARCHAR(100)  NULL,
    PriorRehireDate                  DATE           NULL,
    PriorReportsTo                   NVARCHAR(20)   NULL,
    PriorSalAdminPlan                NVARCHAR(20)   NULL,
    PriorSelectedGroup               NVARCHAR(10)   NULL,
    PriorSeq                         INT            NULL,
    PriorStdHours                    DECIMAL(6,2)   NULL,
    PriorStep                        INT            NULL,
    PriorSupervisor                  NVARCHAR(255)  NULL,

    -- ── Row hash ─────────────────────────────────────────────────────────────
    -- SHA2-256 of all 136 data columns (CONCAT_WS with NVARCHAR(MAX)).
    -- Used in MERGE WHEN MATCHED condition to avoid 136-column OR expression.
    RowHash                          VARBINARY(32)  NULL,

    -- ── Soft delete and traceability ─────────────────────────────────────────
    IsActive          BIT          NOT NULL
        CONSTRAINT DF_Peoplesoft_HEM_IsActive DEFAULT (1),
    CreatedUtc        DATETIME2(0) NOT NULL
        CONSTRAINT DF_Peoplesoft_HEM_CreatedUtc DEFAULT SYSUTCDATETIME(),
    LastUpdatedUtc    DATETIME2(0) NOT NULL
        CONSTRAINT DF_Peoplesoft_HEM_LastUpdatedUtc DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Peoplesoft_HEM PRIMARY KEY (EmplId, EffDt, EffSeq, EmplRcd)
);
GO

CREATE INDEX IX_Peoplesoft_HEM_IsActive
ON dbo.Peoplesoft_HEM (IsActive)
INCLUDE (EmplId, EffDt, MoveType, CompChange, NewDeptId, NewOrganization, FiscalYear);
GO

CREATE INDEX IX_Peoplesoft_HEM_EmplId
ON dbo.Peoplesoft_HEM (EmplId)
INCLUDE (EffDt, MoveType, CompChange, IsActive);
GO

CREATE INDEX IX_Peoplesoft_HEM_FiscalYear
ON dbo.Peoplesoft_HEM (FiscalYear, MoveType)
INCLUDE (EmplId, CompChange, NewDeptId, NewOrganization, IsActive);
GO
