SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================
-- Dropped records staging table: Stg_Peoplesoft_EPC_Dropped
-- API: Datamart_CITZ_Report_EmptyPositionCount (Empty Position Count)
-- Purpose: Append-only log of rows removed from staging before MERGE
--
-- DropReason values:
--   'NULL_POSITION' -- Position is NULL (cannot be merged; business key required)
--
-- Note: Position should never be NULL (0 nulls observed in analysis), but this
--       table exists as a protective guardrail and for upstream issue reporting.
-- Do NOT truncate between runs -- historical trend analysis required.
-- =============================================================================

IF OBJECT_ID('dbo.Stg_Peoplesoft_EPC_Dropped', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Peoplesoft_EPC_Dropped;
GO

CREATE TABLE dbo.Stg_Peoplesoft_EPC_Dropped
(
    -- Drop metadata
    DropReason                     NVARCHAR(100)   NOT NULL,   -- 'NULL_POSITION'
    LoadDtmUtc                     DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    -- All staging columns (Position may be NULL for NULL_POSITION rows)
    Position                       NVARCHAR(20)    NULL,
    AsOfDate                       DATE            NULL,
    BaseIncumbents                 NVARCHAR(500)   NULL,
    BusinessUnitDescr              NVARCHAR(255)   NULL,
    City                           NVARCHAR(100)   NULL,
    ClassificationGroup            NVARCHAR(255)   NULL,
    Core                           NVARCHAR(20)    NULL,
    CreateEffDt                    DATE            NULL,
    DeptId                         NVARCHAR(20)    NULL,
    DeptIdDesc                     NVARCHAR(255)   NULL,
    DevelopmentRegion              NVARCHAR(100)   NULL,
    EmptyEffDt                     DATE            NULL,
    EmptyPosition                  NVARCHAR(10)    NULL,
    ExcludedOrIncluded             NVARCHAR(20)    NULL,
    IncumbentCount                 INT             NULL,
    Incumbents                     NVARCHAR(500)   NULL,
    JobCode                        NVARCHAR(20)    NULL,
    JobCodeDesc                    NVARCHAR(255)   NULL,
    JobFunc                        NVARCHAR(20)    NULL,
    JobReqOpenDate                 DATE            NULL,
    JobReqStatus                   NVARCHAR(50)    NULL,
    LastIncumbents                 NVARCHAR(500)   NULL,
    Location                       NVARCHAR(20)    NULL,
    NocCode                        NVARCHAR(20)    NULL,
    NocCodeDescr                   NVARCHAR(255)   NULL,
    Organization                   NVARCHAR(100)   NULL,
    PosStatusDescr                 NVARCHAR(100)   NULL,
    PositionEmptyGt1Year           NVARCHAR(10)    NULL,
    PositionHasBaseIncumbent       NVARCHAR(10)    NULL,
    PositionTitle                  NVARCHAR(500)   NULL,
    Program                        NVARCHAR(255)   NULL,
    ProgramBranch                  NVARCHAR(255)   NULL,
    ProgramDivision                NVARCHAR(255)   NULL,
    ProvincialQuadrant             NVARCHAR(100)   NULL,
    RegDistrictDesc                NVARCHAR(100)   NULL,
    RegOrTempDescr                 NVARCHAR(50)    NULL,
    ReportsTo                      NVARCHAR(20)    NULL,
    Supervisor                     NVARCHAR(500)   NULL,
    YearsEmpty                     DECIMAL(10,4)   NULL
    -- No primary key: append-only across ETL runs
);
GO

CREATE INDEX IX_EPC_Dropped_Reason ON dbo.Stg_Peoplesoft_EPC_Dropped (DropReason, LoadDtmUtc);
GO
