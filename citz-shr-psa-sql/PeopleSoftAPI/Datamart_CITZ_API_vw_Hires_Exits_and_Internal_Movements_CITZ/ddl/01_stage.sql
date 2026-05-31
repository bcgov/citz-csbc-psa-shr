-- Staging table for Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ
-- API type  : Report-style event log (movement events: hires, exits, internal moves)
-- HTTP method: GET
-- Total rows : ~10,567
-- Business key: EmplId + EffDt + EffSeq + EmplRcd (PeopleSoft job row key — no single-column key confirmed)
-- Report metadata: None detected
-- Notes:
--   • No PK — report-style staging allows duplicates (dedup performed in R before load)
--   • ~1 377 rows have NULL Prior_ columns (new hires — first event, no prior state)
--   • New_Level4 and Prior_Level4 are highly nullable (~8 831 / 8 970 nulls)
--   • JSON keys "New_Level4" and "Prior_Level4" may return {} from API; R normalises to NA

IF OBJECT_ID('dbo.Stg_Peoplesoft_HEM', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Peoplesoft_HEM;
GO

SET NOCOUNT ON;
GO

CREATE TABLE dbo.Stg_Peoplesoft_HEM
(
    -- ── Business key (PeopleSoft JOB row) ───────────────────────────────────
    EmplId                           NVARCHAR(20)   NULL,   -- JSON: "EmplID"
    EffDt                            DATE           NULL,   -- JSON: "EFFDT"
    EffSeq                           INT            NULL,   -- JSON: "EFFSEQ"
    EmplRcd                          INT            NULL,   -- JSON: "Empl_RCD"

    -- ── Event header ─────────────────────────────────────────────────────────
    CompChange                       NVARCHAR(100)  NULL,   -- JSON: "CompChange"
    EstimatedYrsOfService            INT            NULL,   -- JSON: "Estimated_Years_of_Service"
    EstimatedYearsOfService          INT            NULL,   -- JSON: "EstimatedYearsOfService"  (duplicate representation)
    EstimatedYearsOfServiceStr       NVARCHAR(100)  NULL,   -- JSON: "EstimatedYearsOfServiceString"
    FirstDateOfService               DATE           NULL,   -- JSON: "First_Date_of_Service"
    FiscalYear                       INT            NULL,   -- JSON: "FiscalYear"
    LeaveServiceDt                   DATE           NULL,   -- JSON: "Leave_Service_DT"          (~20 nulls)
    MostHistoricDate                 DATE           NULL,   -- JSON: "Most_Historic_Date"         (~4 nulls)
    MoveType                         NVARCHAR(50)   NULL,   -- JSON: "MoveType"
    MoveType1                        NVARCHAR(50)   NULL,   -- JSON: "MoveType1"
    MoveType1Sort                    INT            NULL,   -- JSON: "MoveType1_Sort"             (~2 888 nulls)
    MoveType2                        NVARCHAR(100)  NULL,   -- JSON: "MoveType2"
    Name                             NVARCHAR(255)  NULL,   -- JSON: "Name"
    SameGroup                        NVARCHAR(10)   NULL,   -- JSON: "SameGroup"
    SameLevel1                       NVARCHAR(10)   NULL,   -- JSON: "SameLevel1"
    SameOrg                          NVARCHAR(10)   NULL,   -- JSON: "SameOrg"
    Seq                              INT            NULL,   -- JSON: "SEQ"
    SupervisorMove                   NVARCHAR(100)  NULL,   -- JSON: "SupervisorMove"

    -- ── New state columns ────────────────────────────────────────────────────
    NewAction                        NVARCHAR(10)   NULL,   -- JSON: "New_Action"
    NewActionDt                      DATE           NULL,   -- JSON: "New_Action_DT"
    NewActionReason                  NVARCHAR(10)   NULL,   -- JSON: "New_ActionReason"
    NewActionReasonDescr             NVARCHAR(255)  NULL,   -- JSON: "New_ActionReason_Descr"
    NewAnnualRt                      DECIMAL(18,4)  NULL,   -- JSON: "New_ANNUAL_RT"
    NewBusinessUnit                  NVARCHAR(20)   NULL,   -- JSON: "New_Business_Unit"
    NewBusinessUnitDescr             NVARCHAR(255)  NULL,   -- JSON: "New_Business_Unit_Descr"
    NewCity                          NVARCHAR(100)  NULL,   -- JSON: "New_City"
    NewClassificationGroup           NVARCHAR(100)  NULL,   -- JSON: "New_Classification_Group"
    NewCompRate                      DECIMAL(18,4)  NULL,   -- JSON: "New_COMPRATE"
    NewCoreBu                        NVARCHAR(20)   NULL,   -- JSON: "New_CoreBU"
    NewCoreOrg                       NVARCHAR(20)   NULL,   -- JSON: "New_CoreOrg"
    NewDeptId                        NVARCHAR(50)   NULL,   -- JSON: "New_DeptID"
    NewDeptIdDescr                   NVARCHAR(255)  NULL,   -- JSON: "New_DeptID_Descr"
    NewDevelopmentRegion             NVARCHAR(100)  NULL,   -- JSON: "New_Development_Region"
    NewEmplCtg                       NVARCHAR(20)   NULL,   -- JSON: "New_Empl_CTG"
    NewEmplCtgDescr                  NVARCHAR(100)  NULL,   -- JSON: "New_Empl_CTG_Descr"
    NewEmplStatus                    NVARCHAR(10)   NULL,   -- JSON: "New_Empl_Status"
    NewEmplStatusDescr               NVARCHAR(100)  NULL,   -- JSON: "New_Empl_Status_Descr"
    NewEndOfDayHrStatus              NVARCHAR(10)   NULL,   -- JSON: "New_EndOfDayHR_Status"
    NewEndOfDayPerOrg                NVARCHAR(20)   NULL,   -- JSON: "New_EndOfDayPER_ORG"
    NewEstimatedYearsInOrg           INT            NULL,   -- JSON: "New_EstimatedYearsInOrganization"
    NewEstimatedYearsInOrgStr        NVARCHAR(100)  NULL,   -- JSON: "New_EstimatedYearsInOrganizationString"
    NewEstimatedYearsInPos           INT            NULL,   -- JSON: "New_EstimatedYearsInPosition"
    NewEstimatedYearsInPosStr        NVARCHAR(100)  NULL,   -- JSON: "New_EstimatedYearsInPositionString"
    NewFirstDateInOrg                DATE           NULL,   -- JSON: "New_First_Date_in_Organization"
    NewFirstDateInPosition           DATE           NULL,   -- JSON: "New_First_Date_in_Position"
    NewGrade                         NVARCHAR(20)   NULL,   -- JSON: "New_Grade"
    NewHireDate                      DATE           NULL,   -- JSON: "New_Hire_Date"
    NewHourlyRt                      DECIMAL(18,4)  NULL,   -- JSON: "New_HOURLY_RT"
    NewHrStatus                      NVARCHAR(10)   NULL,   -- JSON: "New_HR_Status"
    NewIncludedOrExcluded            NVARCHAR(50)   NULL,   -- JSON: "New_Included_or_Excluded"
    NewIsSupervisor                  NVARCHAR(10)   NULL,   -- JSON: "New_IsSupervisor"
    NewJobFunction                   NVARCHAR(20)   NULL,   -- JSON: "New_Job_Function"
    NewJobcode                       NVARCHAR(20)   NULL,   -- JSON: "New_Jobcode"
    NewJobcodeDescr                  NVARCHAR(255)  NULL,   -- JSON: "New_Jobcode_Descr"
    NewLevel1                        NVARCHAR(255)  NULL,   -- JSON: "New_Level1"
    NewLevel2                        NVARCHAR(255)  NULL,   -- JSON: "New_Level2"                 (~4 nulls)
    NewLevel3                        NVARCHAR(255)  NULL,   -- JSON: "New_Level3"                 (~334 nulls)
    NewLevel4                        NVARCHAR(255)  NULL,   -- JSON: "New_Level4"                 (~8 831 nulls; {} → NA)
    NewLifeCycle                     NVARCHAR(50)   NULL,   -- JSON: "New_Life_Cycle"
    NewLocation                      NVARCHAR(50)   NULL,   -- JSON: "New_Location"
    NewLocationGroup                 NVARCHAR(100)  NULL,   -- JSON: "New_Location_Group"
    NewMaxRtHourly                   DECIMAL(18,4)  NULL,   -- JSON: "New_MAX_RT_HOURLY"
    NewOrganization                  NVARCHAR(255)  NULL,   -- JSON: "New_Organization"
    NewPerOrg                        NVARCHAR(20)   NULL,   -- JSON: "New_PER_ORG"
    NewPositionDescr                 NVARCHAR(255)  NULL,   -- JSON: "New_Position_Descr"          (~2 nulls)
    NewPositionNbr                   NVARCHAR(20)   NULL,   -- JSON: "New_Position_NBR"
    NewPsa                           NVARCHAR(10)   NULL,   -- JSON: "New_PSA"
    NewRegionalDistrict              NVARCHAR(100)  NULL,   -- JSON: "New_Regional_District"
    NewRehireDate                    DATE           NULL,   -- JSON: "New_Rehire_Date"             (~3 nulls)
    NewReportsTo                     NVARCHAR(20)   NULL,   -- JSON: "New_Reports_to"
    NewSalAdminPlan                  NVARCHAR(20)   NULL,   -- JSON: "New_Sal_Admin_Plan"
    NewSelectedGroup                 NVARCHAR(10)   NULL,   -- JSON: "New_SelectedGroup"
    NewStdHours                      DECIMAL(6,2)   NULL,   -- JSON: "New_STD_HOURS"
    NewStep                          INT            NULL,   -- JSON: "New_STEP"
    NewSupervisor                    NVARCHAR(255)  NULL,   -- JSON: "New_Supervisor"              (~322 nulls)

    -- ── Prior state columns ──────────────────────────────────────────────────
    -- All Prior_ columns are NULL for new hires (no prior HR event). ~1 377 nulls each.
    PriorAction                      NVARCHAR(10)   NULL,   -- JSON: "Prior_Action"
    PriorActionDt                    DATE           NULL,   -- JSON: "Prior_Action_DT"
    PriorActionReason                NVARCHAR(10)   NULL,   -- JSON: "Prior_ActionReason"
    PriorActionReasonDescr           NVARCHAR(255)  NULL,   -- JSON: "Prior_ActionReason_Descr"   (~6 679 nulls)
    PriorAnnualRt                    DECIMAL(18,4)  NULL,   -- JSON: "Prior_ANNUAL_RT"
    PriorBusinessUnit                NVARCHAR(20)   NULL,   -- JSON: "Prior_Business_Unit"
    PriorBusinessUnitDescr           NVARCHAR(255)  NULL,   -- JSON: "Prior_Business_Unit_Descr"
    PriorCity                        NVARCHAR(100)  NULL,   -- JSON: "Prior_City"
    PriorClassificationGroup         NVARCHAR(100)  NULL,   -- JSON: "Prior_Classification_Group"
    PriorCompRate                    DECIMAL(18,4)  NULL,   -- JSON: "Prior_COMPRATE"
    PriorCoreBu                      NVARCHAR(20)   NULL,   -- JSON: "Prior_CoreBU"
    PriorCoreOrg                     NVARCHAR(20)   NULL,   -- JSON: "Prior_CoreOrg"
    PriorDeptId                      NVARCHAR(50)   NULL,   -- JSON: "Prior_DeptID"
    PriorDeptIdDescr                 NVARCHAR(255)  NULL,   -- JSON: "Prior_DeptID_Descr"
    PriorDevelopmentRegion           NVARCHAR(100)  NULL,   -- JSON: "Prior_Development_Region"
    PriorEffDt                       DATE           NULL,   -- JSON: "Prior_EFFDT"
    PriorEffSeq                      INT            NULL,   -- JSON: "Prior_EFFSEQ"
    PriorEmplCtg                     NVARCHAR(20)   NULL,   -- JSON: "Prior_Empl_CTG"
    PriorEmplCtgDescr                NVARCHAR(100)  NULL,   -- JSON: "Prior_Empl_CTG_Descr"
    PriorEmplStatus                  NVARCHAR(10)   NULL,   -- JSON: "Prior_Empl_Status"
    PriorEmplStatusDescr             NVARCHAR(100)  NULL,   -- JSON: "Prior_Empl_Status_Descr"
    PriorEndOfDayHrStatus            NVARCHAR(10)   NULL,   -- JSON: "Prior_EndOfDayHR_Status"    (~1 416 nulls)
    PriorEndOfDayPerOrg              NVARCHAR(20)   NULL,   -- JSON: "Prior_EndOfDayPER_ORG"      (~1 416 nulls)
    PriorEstimatedYearsInOrg         INT            NULL,   -- JSON: "Prior_EstimatedYearsInOrganization"
    PriorEstimatedYearsInOrgStr      NVARCHAR(100)  NULL,   -- JSON: "Prior_EstimatedYearsInOrganizationString"
    PriorEstimatedYearsInPos         INT            NULL,   -- JSON: "Prior_EstimatedYearsInPosition"
    PriorEstimatedYearsInPosStr      NVARCHAR(100)  NULL,   -- JSON: "Prior_EstimatedYearsInPositionString"
    PriorFirstDateInOrg              DATE           NULL,   -- JSON: "Prior_First_Date_in_Organization"
    PriorFirstDateInPosition         DATE           NULL,   -- JSON: "Prior_First_Date_in_Position"
    PriorFiscalYear                  INT            NULL,   -- JSON: "Prior_FiscalYear"            (~1 378 nulls)
    PriorGrade                       NVARCHAR(20)   NULL,   -- JSON: "Prior_Grade"
    PriorHireDate                    DATE           NULL,   -- JSON: "Prior_Hire_Date"
    PriorHourlyRt                    DECIMAL(18,4)  NULL,   -- JSON: "Prior_HOURLY_RT"
    PriorHrStatus                    NVARCHAR(10)   NULL,   -- JSON: "Prior_HR_Status"
    PriorIncludedOrExcluded          NVARCHAR(50)   NULL,   -- JSON: "Prior_Included_or_Excluded"
    PriorIsSupervisor                NVARCHAR(10)   NULL,   -- JSON: "Prior_IsSupervisor"
    PriorJobFunction                 NVARCHAR(20)   NULL,   -- JSON: "Prior_Job_Function"
    PriorJobcode                     NVARCHAR(20)   NULL,   -- JSON: "Prior_Jobcode"
    PriorJobcodeDescr                NVARCHAR(255)  NULL,   -- JSON: "Prior_Jobcode_Descr"
    PriorLevel1                      NVARCHAR(255)  NULL,   -- JSON: "Prior_Level1"
    PriorLevel2                      NVARCHAR(255)  NULL,   -- JSON: "Prior_Level2"               (~1 382 nulls)
    PriorLevel3                      NVARCHAR(255)  NULL,   -- JSON: "Prior_Level3"               (~1 764 nulls)
    PriorLevel4                      NVARCHAR(255)  NULL,   -- JSON: "Prior_Level4"               (~8 970 nulls; {} → NA)
    PriorLifeCycle                   NVARCHAR(50)   NULL,   -- JSON: "Prior_Life_Cycle"            (~6 679 nulls)
    PriorLocation                    NVARCHAR(50)   NULL,   -- JSON: "Prior_Location"
    PriorLocationGroup               NVARCHAR(100)  NULL,   -- JSON: "Prior_Location_Group"
    PriorMaxRtHourly                 DECIMAL(18,4)  NULL,   -- JSON: "Prior_MAX_RT_HOURLY"         (~1 379 nulls)
    PriorOrganization                NVARCHAR(255)  NULL,   -- JSON: "Prior_Organization"
    PriorPerOrg                      NVARCHAR(20)   NULL,   -- JSON: "Prior_PER_ORG"
    PriorPositionDescr               NVARCHAR(255)  NULL,   -- JSON: "Prior_Position_Descr"        (~1 379 nulls)
    PriorPositionNbr                 NVARCHAR(20)   NULL,   -- JSON: "Prior_Position_NBR"
    PriorPsa                         NVARCHAR(10)   NULL,   -- JSON: "Prior_PSA"
    PriorRegionalDistrict            NVARCHAR(100)  NULL,   -- JSON: "Prior_Regional_District"
    PriorRehireDate                  DATE           NULL,   -- JSON: "Prior_Rehire_Date"           (~1 381 nulls)
    PriorReportsTo                   NVARCHAR(20)   NULL,   -- JSON: "Prior_Reports_to"
    PriorSalAdminPlan                NVARCHAR(20)   NULL,   -- JSON: "Prior_Sal_Admin_Plan"
    PriorSelectedGroup               NVARCHAR(10)   NULL,   -- JSON: "Prior_SelectedGroup"
    PriorSeq                         INT            NULL,   -- JSON: "Prior_SEQ"
    PriorStdHours                    DECIMAL(6,2)   NULL,   -- JSON: "Prior_STD_HOURS"
    PriorStep                        INT            NULL,   -- JSON: "Prior_STEP"
    PriorSupervisor                  NVARCHAR(255)  NULL    -- JSON: "Prior_Supervisor"            (~1 828 nulls)
    -- No PRIMARY KEY — report-style staging; dedup is performed in R before load.
    -- DropReason rows are written to dbo.Stg_Peoplesoft_HEM_Dropped instead.
);
GO
