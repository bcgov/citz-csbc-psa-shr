IF OBJECT_ID('dbo.Stg_Peoplesoft_SHR010HRORG', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Peoplesoft_SHR010HRORG;
GO

CREATE TABLE dbo.Stg_Peoplesoft_SHR010HRORG
(
    -- Business key
    -- emplid is 100% unique and never NULL in current data (key_analysis confirmed).
    -- Staging enforces PK because this is a relational entity (not report-style).
    EmplId                       NVARCHAR(20)   NOT NULL,  -- JSON: "emplid"

    -- Employee identity
    Name                         NVARCHAR(255)  NULL,       -- JSON: "name"
    Idir                         NVARCHAR(50)   NULL,       -- JSON: "IDIR"         (8 nulls in prod)
    EmailId                      NVARCHAR(255)  NULL,       -- JSON: "EMAILID"      (8 nulls in prod)
    EmplStatus                   NVARCHAR(50)   NULL,       -- JSON: "empl_status"
    EmplType                     NVARCHAR(10)   NULL,       -- JSON: "empl_type"
    EmplCtg                      NVARCHAR(50)   NULL,       -- JSON: "empl_ctg"
    EmplCtgL1                    NVARCHAR(50)   NULL,       -- JSON: "empl_ctg_l1"
    EmplRcd                      INT            NULL,       -- JSON: "empl_rcd"
    ApptStatus                   NVARCHAR(50)   NULL,       -- JSON: "Appt_Status"
    ApptStatusCode               NVARCHAR(10)   NULL,       -- JSON: "Appt_Status_Code"

    -- Dates (stored as DATE — ISO-format dates from API)
    Birthdate                    DATE           NULL,       -- JSON: "BIRTHDATE"
    HireDt                       DATE           NULL,       -- JSON: "HIRE_DT"
    LastHireDt                   DATE           NULL,       -- JSON: "LAST_HIRE_DT"                 (2 nulls)
    MostHistoricDate             DATE           NULL,       -- JSON: "Most_Historic_Date"
    FirstDateInOrganization      DATE           NULL,       -- JSON: "First_Date_In_Organization"
    FirstDateInPosition          DATE           NULL,       -- JSON: "First_Date_in_Position"
    FutureReturnDate             DATE           NULL,       -- JSON: "Future_Return_Date"            (2682 nulls; returns {} in API)

    -- Position / job
    PositionNbr                  NVARCHAR(20)   NULL,       -- JSON: "position_nbr"
    TgbBasePosition              NVARCHAR(20)   NULL,       -- JSON: "tgb_base_position"
    PositionDataDescr            NVARCHAR(255)  NULL,       -- JSON: "PositionData_DESCR"
    JobCode                      NVARCHAR(20)   NULL,       -- JSON: "jobcode"
    JobCodeDescr                 NVARCHAR(255)  NULL,       -- JSON: "Jobcode_DESCR"
    JobFunction                  NVARCHAR(20)   NULL,       -- JSON: "job_function"
    SalAdminPlan                 NVARCHAR(20)   NULL,       -- JSON: "sal_admin_plan"
    Grade                        NVARCHAR(20)   NULL,       -- JSON: "grade"
    Step                         INT            NULL,       -- JSON: "step"
    StdHours                     DECIMAL(6,2)   NULL,       -- JSON: "std_hours"

    -- Compensation
    AnnualRt                     DECIMAL(18,4)  NULL,       -- JSON: "ANNUAL_RT"
    CompRate                     DECIMAL(18,4)  NULL,       -- JSON: "COMPRATE"
    HourlyRt                     DECIMAL(12,4)  NULL,       -- JSON: "HOURLY_RT"

    -- Organization hierarchy
    Organization                 NVARCHAR(255)  NULL,       -- JSON: "Organization"
    BusinessUnit                 NVARCHAR(20)   NULL,       -- JSON: "business_unit"
    DeptId                       NVARCHAR(50)   NULL,       -- JSON: "deptid"
    DeptDescr                    NVARCHAR(255)  NULL,       -- JSON: "DEPT_DESCR"
    Level1                       NVARCHAR(255)  NULL,       -- JSON: "Level1"
    Level2                       NVARCHAR(255)  NULL,       -- JSON: "Level2"
    Level3                       NVARCHAR(255)  NULL,       -- JSON: "Level3"                       (3 nulls)
    Descr                        NVARCHAR(255)  NULL,       -- JSON: "descr"
    Core                         NVARCHAR(20)   NULL,       -- JSON: "core"
    CoreGovernment               NVARCHAR(50)   NULL,       -- JSON: "Core_Government_"             (trailing underscore in JSON key)
    Sector                       NVARCHAR(50)   NULL,       -- JSON: "Sector"
    PublicService                NVARCHAR(50)   NULL,       -- JSON: "Public_Service"
    PublicServiceAct             NVARCHAR(50)   NULL,       -- JSON: "Public_Service_Act"
    TreasuryBoard                NVARCHAR(50)   NULL,       -- JSON: "Treasury_Board"
    OfficerCode                  NVARCHAR(50)   NULL,       -- JSON: "OFFICER_CODE"
    NocCode                      NVARCHAR(20)   NULL,       -- JSON: "NOC_Code"
    NocCodeDescr                 NVARCHAR(255)  NULL,       -- JSON: "NOC_Code_Descr"
    ReportsTo                    NVARCHAR(20)   NULL,       -- JSON: "reports_to"

    -- Location
    Location                     NVARCHAR(50)   NULL,       -- JSON: "location"
    LocationCity                 NVARCHAR(100)  NULL,       -- JSON: "Location_City"

    -- Demographics
    AgeGroup1                    NVARCHAR(10)   NULL,       -- JSON: "Age_Group_1"
    AgeGroup2                    NVARCHAR(20)   NULL,       -- JSON: "Age_Group_2"
    Age                          DECIMAL(8,4)   NULL,       -- JSON: "Age"
    Generation                   NVARCHAR(30)   NULL,       -- JSON: "Generation"
    EligibleForPension           NVARCHAR(10)   NULL,       -- JSON: "Eligible_for_Pension"
    EligibleForUnreducedPension  NVARCHAR(10)   NULL,       -- JSON: "Eligible_for_Unreduced_Pension"

    -- Supervisor
    Supervisor                   NVARCHAR(255)  NULL,       -- JSON: "SUPERVISOR"                   (291 nulls)
    SupervEmail                  NVARCHAR(255)  NULL,       -- JSON: "SUPERV_EMAIL"                 (291 nulls)
    SupervSalPlan                NVARCHAR(20)   NULL,       -- JSON: "SUPERV_SAL_PLAN"              (291 nulls)
    SupervisorStatus             NVARCHAR(50)   NULL,       -- JSON: "Supervisor_Status"

    -- Leave / layoff
    LayoffLeaveStopPayReason     NVARCHAR(255)  NULL,       -- JSON: "Layoff_Leave_Stop_Pay_Reason"     (2582 nulls)
    LayoffLeaveStopPayStartDate  DATE           NULL,       -- JSON: "Layoff_Leave_Stop_Pay_Start_Date" (2582 nulls; returns {})

    -- Report metadata: AsOfDate is the API snapshot date (identical for all rows per run).
    -- Stored in staging for lineage; excluded from target/audit/HASHBYTES to
    -- prevent false UPDATE events on every row when the date increments daily.
    AsOfDate                     DATE           NULL,       -- JSON: "As_of_Date"

    CONSTRAINT PK_Stg_Peoplesoft_SHR010HRORG PRIMARY KEY (EmplId)
);
GO
