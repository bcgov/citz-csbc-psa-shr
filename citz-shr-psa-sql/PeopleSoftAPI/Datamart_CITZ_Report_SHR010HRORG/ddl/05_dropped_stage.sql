-- Dropped records table for SHR010HRORG Employee HeadCount by Classification.
--
-- Rows are appended (never truncated) to preserve a full historical audit trail
-- of data-quality events across all ETL runs. The R ETL script captures invalid
-- rows BEFORE loading to staging and writes them here via dbWriteTable().
--
-- Current DropReason values:
--   'NULL_EMPLID'   — emplid is NULL or blank (precautionary; not observed in prod)
--
-- Reporting query: reporting/audit/hc__dropped_records_trend.sql

IF OBJECT_ID('dbo.Stg_Peoplesoft_SHR010HRORG_Dropped', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Peoplesoft_SHR010HRORG_Dropped;
GO

CREATE TABLE dbo.Stg_Peoplesoft_SHR010HRORG_Dropped
(
    -- Drop metadata (required on every row)
    DropReason                   NVARCHAR(100)  NOT NULL,  -- e.g. 'NULL_EMPLID'
    LoadDtmUtc                   DATETIME2(0)   NOT NULL
        CONSTRAINT DF_Stg_Peoplesoft_SHR010HRORG_Dropped_LoadDtmUtc DEFAULT SYSUTCDATETIME(),

    -- Original staging columns (all nullable — key may be NULL for NULL_EMPLID rows)
    EmplId                       NVARCHAR(20)   NULL,
    Name                         NVARCHAR(255)  NULL,
    Idir                         NVARCHAR(50)   NULL,
    EmailId                      NVARCHAR(255)  NULL,
    EmplStatus                   NVARCHAR(50)   NULL,
    EmplType                     NVARCHAR(10)   NULL,
    EmplCtg                      NVARCHAR(50)   NULL,
    EmplCtgL1                    NVARCHAR(50)   NULL,
    EmplRcd                      INT            NULL,
    ApptStatus                   NVARCHAR(50)   NULL,
    ApptStatusCode               NVARCHAR(10)   NULL,
    Birthdate                    DATE           NULL,
    HireDt                       DATE           NULL,
    LastHireDt                   DATE           NULL,
    MostHistoricDate             DATE           NULL,
    FirstDateInOrganization      DATE           NULL,
    FirstDateInPosition          DATE           NULL,
    FutureReturnDate             DATE           NULL,
    PositionNbr                  NVARCHAR(20)   NULL,
    TgbBasePosition              NVARCHAR(20)   NULL,
    PositionDataDescr            NVARCHAR(255)  NULL,
    JobCode                      NVARCHAR(20)   NULL,
    JobCodeDescr                 NVARCHAR(255)  NULL,
    JobFunction                  NVARCHAR(20)   NULL,
    SalAdminPlan                 NVARCHAR(20)   NULL,
    Grade                        NVARCHAR(20)   NULL,
    Step                         INT            NULL,
    StdHours                     DECIMAL(6,2)   NULL,
    AnnualRt                     DECIMAL(18,4)  NULL,
    CompRate                     DECIMAL(18,4)  NULL,
    HourlyRt                     DECIMAL(12,4)  NULL,
    Organization                 NVARCHAR(255)  NULL,
    BusinessUnit                 NVARCHAR(20)   NULL,
    DeptId                       NVARCHAR(50)   NULL,
    DeptDescr                    NVARCHAR(255)  NULL,
    Level1                       NVARCHAR(255)  NULL,
    Level2                       NVARCHAR(255)  NULL,
    Level3                       NVARCHAR(255)  NULL,
    Descr                        NVARCHAR(255)  NULL,
    Core                         NVARCHAR(20)   NULL,
    CoreGovernment               NVARCHAR(50)   NULL,
    Sector                       NVARCHAR(50)   NULL,
    PublicService                NVARCHAR(50)   NULL,
    PublicServiceAct             NVARCHAR(50)   NULL,
    TreasuryBoard                NVARCHAR(50)   NULL,
    OfficerCode                  NVARCHAR(50)   NULL,
    NocCode                      NVARCHAR(20)   NULL,
    NocCodeDescr                 NVARCHAR(255)  NULL,
    ReportsTo                    NVARCHAR(20)   NULL,
    Location                     NVARCHAR(50)   NULL,
    LocationCity                 NVARCHAR(100)  NULL,
    AgeGroup1                    NVARCHAR(10)   NULL,
    AgeGroup2                    NVARCHAR(20)   NULL,
    Age                          DECIMAL(8,4)   NULL,
    Generation                   NVARCHAR(30)   NULL,
    EligibleForPension           NVARCHAR(10)   NULL,
    EligibleForUnreducedPension  NVARCHAR(10)   NULL,
    Supervisor                   NVARCHAR(255)  NULL,
    SupervEmail                  NVARCHAR(255)  NULL,
    SupervSalPlan                NVARCHAR(20)   NULL,
    SupervisorStatus             NVARCHAR(50)   NULL,
    LayoffLeaveStopPayReason     NVARCHAR(255)  NULL,
    LayoffLeaveStopPayStartDate  DATE           NULL,
    AsOfDate                     DATE           NULL
);
GO

-- Index for trend reporting queries
CREATE INDEX IX_Stg_Peoplesoft_SHR010HRORG_Dropped_DropReason_LoadDtm
    ON dbo.Stg_Peoplesoft_SHR010HRORG_Dropped (DropReason, LoadDtmUtc);
GO
