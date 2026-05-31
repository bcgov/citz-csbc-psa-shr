IF OBJECT_ID('dbo.Peoplesoft_SHR010HRORG', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_SHR010HRORG;
GO

CREATE TABLE dbo.Peoplesoft_SHR010HRORG
(
    -- Business key (single column; emplid is 100% unique per key_analysis)
    EmplId                       NVARCHAR(20)   NOT NULL,

    -- Employee identity
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

    -- Dates
    Birthdate                    DATE           NULL,
    HireDt                       DATE           NULL,
    LastHireDt                   DATE           NULL,
    MostHistoricDate             DATE           NULL,
    FirstDateInOrganization      DATE           NULL,
    FirstDateInPosition          DATE           NULL,
    FutureReturnDate             DATE           NULL,

    -- Position / job
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

    -- Compensation
    AnnualRt                     DECIMAL(18,4)  NULL,
    CompRate                     DECIMAL(18,4)  NULL,
    HourlyRt                     DECIMAL(12,4)  NULL,

    -- Organization hierarchy
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

    -- Location
    Location                     NVARCHAR(50)   NULL,
    LocationCity                 NVARCHAR(100)  NULL,

    -- Demographics
    AgeGroup1                    NVARCHAR(10)   NULL,
    AgeGroup2                    NVARCHAR(20)   NULL,
    Age                          DECIMAL(8,4)   NULL,
    Generation                   NVARCHAR(30)   NULL,
    EligibleForPension           NVARCHAR(10)   NULL,
    EligibleForUnreducedPension  NVARCHAR(10)   NULL,

    -- Supervisor
    Supervisor                   NVARCHAR(255)  NULL,
    SupervEmail                  NVARCHAR(255)  NULL,
    SupervSalPlan                NVARCHAR(20)   NULL,
    SupervisorStatus             NVARCHAR(50)   NULL,

    -- Leave / layoff
    LayoffLeaveStopPayReason     NVARCHAR(255)  NULL,
    LayoffLeaveStopPayStartDate  DATE           NULL,

    -- NOTE: AsOfDate (JSON: "As_of_Date") is NOT stored in target.
    -- It is identical for all rows per API run (snapshot date) and would
    -- cause every row to appear updated on every daily run if included in
    -- HASHBYTES. Stored in staging only for lineage.

    -- Soft delete flag
    IsActive                     BIT            NOT NULL
        CONSTRAINT DF_Peoplesoft_SHR010HRORG_IsActive DEFAULT (1),

    -- Operational traceability
    CreatedUtc                   DATETIME2(0)   NOT NULL
        CONSTRAINT DF_Peoplesoft_SHR010HRORG_CreatedUtc DEFAULT SYSUTCDATETIME(),
    LastUpdatedUtc               DATETIME2(0)   NOT NULL
        CONSTRAINT DF_Peoplesoft_SHR010HRORG_LastUpdatedUtc DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Peoplesoft_SHR010HRORG PRIMARY KEY (EmplId)
);
GO
