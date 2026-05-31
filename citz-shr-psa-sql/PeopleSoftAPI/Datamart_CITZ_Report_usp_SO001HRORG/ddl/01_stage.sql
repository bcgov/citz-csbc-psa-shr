IF OBJECT_ID('dbo.Stg_Peoplesoft_SO001HRORG', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Peoplesoft_SO001HRORG;
GO

CREATE TABLE dbo.Stg_Peoplesoft_SO001HRORG
(
    -- Business key (composite: PosPosition + EmplId)
    -- PosPosition is NULL for some API rows; those are dropped in R before load.
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

    -- Report metadata (per-run values; stored here but excluded from target/audit
    -- to prevent false UPDATE events on every row)
    ReportName           NVARCHAR(255) NULL,   -- JSON: "report name"
    SubTitle             NVARCHAR(255) NULL,   -- JSON: "sub title"
    RunDate              NVARCHAR(100) NULL    -- JSON: "run date"
    -- NOTE: no PRIMARY KEY on staging. The SO001HRORG API can return multiple
    -- rows per (PosPosition, EmplId) composite key due to FutureTermReason
    -- reporting artifacts (e.g. Redundant vs Retired for the same position+employee).
    -- Deduplication on the composite key (PosPosition + EmplId) is performed in
    -- the R ETL script before the staging INSERT. NULL PosPosition rows are also
    -- dropped in R. The MERGE proc requires unique composite source keys;
    -- enforce uniqueness in R, not here.
);
GO
