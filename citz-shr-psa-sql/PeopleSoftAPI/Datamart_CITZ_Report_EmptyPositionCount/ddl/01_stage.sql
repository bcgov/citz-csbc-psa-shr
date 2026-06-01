SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================
-- Staging table: Stg_Peoplesoft_EPC
-- API: Datamart_CITZ_Report_EmptyPositionCount (Empty Position Count)
-- HTTP: GET
-- Business key: Position (single column, 100% unique, 0 nulls)
-- Report metadata: AsOfDate (1 distinct value per run -- staging lineage only;
--                  excluded from target, audit, MERGE, HASHBYTES)
-- Dedup: NOT REQUIRED (Position already unique at source)
-- Dropped records: see 05_dropped_stage.sql (protective -- NULL_POSITION)
--
-- All 39 API columns are stored here (including AsOfDate for lineage).
-- JSON field names that differ from SQL column names are noted in comments.
-- =============================================================================

IF OBJECT_ID('dbo.Stg_Peoplesoft_EPC', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Peoplesoft_EPC;
GO

CREATE TABLE dbo.Stg_Peoplesoft_EPC
(
    -- Business key
    Position                       NVARCHAR(20)    NOT NULL,   -- JSON: "Position"

    -- Report metadata (staging lineage; excluded from target/audit/MERGE)
    AsOfDate                       DATE            NULL,       -- JSON: "As_Of_Date"

    -- Position attributes
    BaseIncumbents                 NVARCHAR(500)   NULL,       -- JSON: "BASE_INCUMBENTS" (comma-separated names; {} = NULL)
    BusinessUnitDescr              NVARCHAR(255)   NULL,       -- JSON: "Business_Unit_Descr"
    City                           NVARCHAR(100)   NULL,       -- JSON: "CITY"
    ClassificationGroup            NVARCHAR(255)   NULL,       -- JSON: "Classification_Group"
    Core                           NVARCHAR(20)    NULL,       -- JSON: "core" (lowercase key)
    CreateEffDt                    DATE            NULL,       -- JSON: "Create_EFFDT"
    DeptId                         NVARCHAR(20)    NULL,       -- JSON: "DEPTID"
    DeptIdDesc                     NVARCHAR(255)   NULL,       -- JSON: "DeptID_Desc"
    DevelopmentRegion              NVARCHAR(100)   NULL,       -- JSON: "Development_Region"
    EmptyEffDt                     DATE            NULL,       -- JSON: "Empty_EFFDT" (~2925 nulls = never empty)
    EmptyPosition                  NVARCHAR(10)    NULL,       -- JSON: "Empty_Position" (YES/NO)
    ExcludedOrIncluded             NVARCHAR(20)    NULL,       -- JSON: "Excluded_or_Included"
    IncumbentCount                 INT             NULL,       -- JSON: "Incumbent_Count" ({} = NULL)
    Incumbents                     NVARCHAR(500)   NULL,       -- JSON: "Incumbents" (comma-separated names; {} = NULL)
    JobCode                        NVARCHAR(20)    NULL,       -- JSON: "Job_Code"
    JobCodeDesc                    NVARCHAR(255)   NULL,       -- JSON: "Job_Code_Desc"
    JobFunc                        NVARCHAR(20)    NULL,       -- JSON: "Job_Func"
    JobReqOpenDate                 DATE            NULL,       -- JSON: "Job_Req_Open_Date" (~3474 nulls)
    JobReqStatus                   NVARCHAR(50)    NULL,       -- JSON: "Job_Req_Status" (~3474 nulls)
    LastIncumbents                 NVARCHAR(500)   NULL,       -- JSON: "LAST_INCUMBENTS" (~2925 nulls)
    Location                       NVARCHAR(20)    NULL,       -- JSON: "LOCATION"
    NocCode                        NVARCHAR(20)    NULL,       -- JSON: "NOC_Code"
    NocCodeDescr                   NVARCHAR(255)   NULL,       -- JSON: "NOC_Code_Descr"
    Organization                   NVARCHAR(100)   NULL,       -- JSON: "Organization"
    PosStatusDescr                 NVARCHAR(100)   NULL,       -- JSON: "Pos_Status_Descr"
    PositionEmptyGt1Year           NVARCHAR(10)    NULL,       -- JSON: "Position_Empty_Greater_Than_1_Year" (YES/NO)
    PositionHasBaseIncumbent       NVARCHAR(10)    NULL,       -- JSON: "Position_Has_Base_Incumbent" (YES/NO)
    PositionTitle                  NVARCHAR(500)   NULL,       -- JSON: "Position_Title"
    Program                        NVARCHAR(255)   NULL,       -- JSON: "Program"
    ProgramBranch                  NVARCHAR(255)   NULL,       -- JSON: "Program_Branch" (~108 nulls)
    ProgramDivision                NVARCHAR(255)   NULL,       -- JSON: "Program_Division"
    ProvincialQuadrant             NVARCHAR(100)   NULL,       -- JSON: "Provincial_Quadrant"
    RegDistrictDesc                NVARCHAR(100)   NULL,       -- JSON: "Reg_District_Desc"
    RegOrTempDescr                 NVARCHAR(50)    NULL,       -- JSON: "Reg_or_Temp_Descr"
    ReportsTo                      NVARCHAR(20)    NULL,       -- JSON: "Reports_To"
    Supervisor                     NVARCHAR(500)   NULL,       -- JSON: "Supervisor" (~578 nulls)
    YearsEmpty                     DECIMAL(10,4)   NULL        -- JSON: "Years_Empty"
);
GO

-- Staging PK: Position is 100% unique (relational entity, not report-style dedup pattern)
ALTER TABLE dbo.Stg_Peoplesoft_EPC
    ADD CONSTRAINT PK_Stg_EPC PRIMARY KEY NONCLUSTERED (Position);
GO
