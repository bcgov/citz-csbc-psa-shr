/*=============================================================================
File:    05_dropped_stage.sql
Table:   dbo.Stg_Peoplesoft_SO001HRORG_Dropped
Purpose: Upstream data quality tracking for PSA API anomalies.
         Rows excluded from the main staging/MERGE pipeline are captured here
         before removal, providing an append-only audit log for transparency
         and SHR upstream data issue reporting.

DropReason values:
  'NULL_POSPOSITION'          — PosPosition was NULL or blank in the API response.
  'DUPLICATE_COMPOSITE_KEY'  — Duplicate on (PosPosition, EmplId) composite key;
                                caused by FutureTermReason reporting artifact
                                (e.g. 'Redundant' vs 'Retired' for same row).

Notes:
  - No primary key — append-only across ETL runs.
  - Schema mirrors dbo.Stg_Peoplesoft_SO001HRORG for direct comparability.
  - LoadDtmUtc records when the row was captured (set by DB DEFAULT).
  - Do NOT truncate between runs; historical records are valuable for trend analysis.
=============================================================================*/

IF OBJECT_ID('dbo.Stg_Peoplesoft_SO001HRORG_Dropped', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Peoplesoft_SO001HRORG_Dropped;
GO

CREATE TABLE dbo.Stg_Peoplesoft_SO001HRORG_Dropped
(
    -- Drop classification
    DropReason           NVARCHAR(100) NOT NULL,   -- 'NULL_POSPOSITION' | 'DUPLICATE_COMPOSITE_KEY'
    LoadDtmUtc           DATETIME2(0)  NOT NULL
        CONSTRAINT DF_Stg_Peoplesoft_SO001HRORG_Dropped_LoadDtmUtc DEFAULT SYSUTCDATETIME(),

    -- Business key (mirrors staging; may be NULL for NULL_POSPOSITION rows)
    PosPosition          NVARCHAR(20)  NULL,

    -- Org hierarchy
    Organization         NVARCHAR(255) NULL,
    Level1               NVARCHAR(255) NULL,
    Level2               NVARCHAR(255) NULL,
    Level3               NVARCHAR(255) NULL,

    -- Position attributes
    PosBusinessUnit      NVARCHAR(255) NULL,
    PosBU                NVARCHAR(20)  NULL,
    PosDepartment        NVARCHAR(255) NULL,
    PosDeptId            NVARCHAR(50)  NULL,
    Title                NVARCHAR(255) NULL,
    PosRole              NVARCHAR(255) NULL,   -- JSON: "pos role"
    PosJobCode           NVARCHAR(50)  NULL,
    PosClassification    NVARCHAR(255) NULL,

    -- Supervisor
    SupervisorPos        NVARCHAR(20)  NULL,
    SupervisorName       NVARCHAR(255) NULL,

    -- Headcount
    Direct               INT           NULL,
    Indirect             INT           NULL,

    -- Location / status
    City                 NVARCHAR(255) NULL,
    Status               NVARCHAR(50)  NULL,
    RT                   NVARCHAR(10)  NULL,
    FP                   NVARCHAR(10)  NULL,
    Budgetted            NVARCHAR(10)  NULL,
    Empty                NVARCHAR(10)  NULL,
    Vacant               NVARCHAR(10)  NULL,
    TrueVacancy          NVARCHAR(10)  NULL,
    Future               NVARCHAR(10)  NULL,
    LastFilled           NVARCHAR(50)  NULL,
    LastFilledB          NVARCHAR(50)  NULL,
    LastFilledBase       NVARCHAR(50)  NULL,

    -- Employee / incumbent details
    EmplBU               NVARCHAR(20)  NULL,
    EmplDeptId           NVARCHAR(50)  NULL,
    JobRole              NVARCHAR(255) NULL,   -- JSON: "job role"
    EmplJobCode          NVARCHAR(50)  NULL,
    EmplClassification   NVARCHAR(255) NULL,
    Grade                NVARCHAR(10)  NULL,
    Step                 NVARCHAR(50)  NULL,
    SalaryType           NVARCHAR(50)  NULL,
    Type                 NVARCHAR(50)  NULL,
    StandardHours        NVARCHAR(20)  NULL,
    Base                 NVARCHAR(10)  NULL,
    Name                 NVARCHAR(255) NULL,
    EmplId               NVARCHAR(20)  NULL,
    EmplStatus           NVARCHAR(50)  NULL,
    Appt                 NVARCHAR(50)  NULL,
    Age                  INT           NULL,

    -- Compensation
    PosClassMax          NVARCHAR(50)  NULL,
    JobClassMax          NVARCHAR(50)  NULL,
    Annual               NVARCHAR(50)  NULL,
    Abbr                 NVARCHAR(50)  NULL,
    AdminPlan            NVARCHAR(50)  NULL,
    AMA                  NVARCHAR(50)  NULL,
    AMALimit             NVARCHAR(50)  NULL,
    CAD                  NVARCHAR(50)  NULL,
    CADLimit             NVARCHAR(50)  NULL,
    SPP                  NVARCHAR(50)  NULL,
    SPPLimit             NVARCHAR(50)  NULL,
    TAJ                  NVARCHAR(50)  NULL,
    TAJLimit             NVARCHAR(50)  NULL,

    -- Future / term
    FutureTermDate       NVARCHAR(50)  NULL,
    FutureTermReason     NVARCHAR(255) NULL,

    -- Temporary assignment
    TAStatus             NVARCHAR(50)  NULL,
    TAStartDate          NVARCHAR(50)  NULL,
    TAReturnDate         NVARCHAR(50)  NULL,
    TAReturnTo           NVARCHAR(50)  NULL,
    TAReturnBU           NVARCHAR(20)  NULL,
    TAReturnDeptId       NVARCHAR(50)  NULL,
    TAReturnJobCode      NVARCHAR(50)  NULL,
    TAReturnGrade        NVARCHAR(10)  NULL,
    TAReturnPosition     NVARCHAR(20)  NULL,
    TAReturnSupervisor   NVARCHAR(255) NULL,
    TAReturnAbbr         NVARCHAR(50)  NULL,

    -- Leave
    LeaveReason          NVARCHAR(255) NULL,
    LeaveStart           NVARCHAR(50)  NULL,
    LeaveReturn          NVARCHAR(50)  NULL,

    -- Miscellaneous
    Q                    NVARCHAR(50)  NULL,
    MaildropCity         NVARCHAR(255) NULL,   -- JSON: "maildrop city"

    -- Report metadata (preserved for lineage on dropped rows)
    ReportName           NVARCHAR(255) NULL,   -- JSON: "report name"
    SubTitle             NVARCHAR(255) NULL,   -- JSON: "sub title"
    RunDate              NVARCHAR(100) NULL    -- JSON: "run date"
    -- NOTE: No primary key — append-only across ETL runs.
    -- Do NOT truncate this table between runs.
);
GO

CREATE INDEX IX_Stg_Peoplesoft_SO001HRORG_Dropped_DropReason
ON dbo.Stg_Peoplesoft_SO001HRORG_Dropped (DropReason, LoadDtmUtc);
GO
