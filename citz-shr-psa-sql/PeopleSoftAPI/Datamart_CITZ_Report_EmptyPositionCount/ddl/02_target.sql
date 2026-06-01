SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================
-- Target table: Peoplesoft_EPC
-- API: Datamart_CITZ_Report_EmptyPositionCount (Empty Position Count)
-- Business key: Position (NOT NULL, enforced PRIMARY KEY)
-- Report metadata: AsOfDate EXCLUDED (see staging for lineage)
-- Soft delete: IsActive = 0 (never hard-delete rows)
-- =============================================================================

IF OBJECT_ID('dbo.Peoplesoft_EPC', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_EPC;
GO

CREATE TABLE dbo.Peoplesoft_EPC
(
    -- Business key
    Position                       NVARCHAR(20)    NOT NULL,

    -- Position attributes
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
    YearsEmpty                     DECIMAL(10,4)   NULL,

    -- Control columns
    IsActive                       BIT             NOT NULL DEFAULT 1,
    CreatedUtc                     DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    LastUpdatedUtc                 DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_EPC PRIMARY KEY CLUSTERED (Position)
);
GO
