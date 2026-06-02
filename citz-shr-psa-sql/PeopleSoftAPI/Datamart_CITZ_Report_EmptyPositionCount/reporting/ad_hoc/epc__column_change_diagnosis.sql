-- epc__column_change_diagnosis.sql
-- Counts how many MATCHED active rows have each column differing between
-- the current target and the freshly-loaded staging table.
--
-- RUN AFTER the R ETL script loads staging but BEFORE running the MERGE proc.
-- Any column showing a high diff count is a candidate for false-UPDATE investigation.
--
-- Interpret results:
--   High count AND matches total MATCHED rows  → continuously-computed or unstable API field
--   Moderate count                              → genuine data churn (recruitment, org moves)
--   Zero or near-zero                          → stable column
-- ============================================================================
SET NOCOUNT ON;

SELECT
    SUM(CASE WHEN ISNULL(tgt.BaseIncumbents,            '') <> ISNULL(src.BaseIncumbents,            '') THEN 1 ELSE 0 END) AS BaseIncumbents_Diffs,
    SUM(CASE WHEN ISNULL(tgt.BusinessUnitDescr,          '') <> ISNULL(src.BusinessUnitDescr,          '') THEN 1 ELSE 0 END) AS BusinessUnitDescr_Diffs,
    SUM(CASE WHEN ISNULL(tgt.City,                       '') <> ISNULL(src.City,                       '') THEN 1 ELSE 0 END) AS City_Diffs,
    SUM(CASE WHEN ISNULL(tgt.ClassificationGroup,        '') <> ISNULL(src.ClassificationGroup,        '') THEN 1 ELSE 0 END) AS ClassificationGroup_Diffs,
    SUM(CASE WHEN ISNULL(tgt.Core,                       '') <> ISNULL(src.Core,                       '') THEN 1 ELSE 0 END) AS Core_Diffs,
    SUM(CASE WHEN ISNULL(tgt.CreateEffDt,  '1900-01-01') <> ISNULL(src.CreateEffDt,  '1900-01-01') THEN 1 ELSE 0 END) AS CreateEffDt_Diffs,
    SUM(CASE WHEN ISNULL(tgt.DeptId,                     '') <> ISNULL(src.DeptId,                     '') THEN 1 ELSE 0 END) AS DeptId_Diffs,
    SUM(CASE WHEN ISNULL(tgt.DeptIdDesc,                 '') <> ISNULL(src.DeptIdDesc,                 '') THEN 1 ELSE 0 END) AS DeptIdDesc_Diffs,
    SUM(CASE WHEN ISNULL(tgt.DevelopmentRegion,          '') <> ISNULL(src.DevelopmentRegion,          '') THEN 1 ELSE 0 END) AS DevelopmentRegion_Diffs,
    SUM(CASE WHEN ISNULL(tgt.EmptyEffDt,   '1900-01-01') <> ISNULL(src.EmptyEffDt,   '1900-01-01') THEN 1 ELSE 0 END) AS EmptyEffDt_Diffs,
    SUM(CASE WHEN ISNULL(tgt.EmptyPosition,              '') <> ISNULL(src.EmptyPosition,              '') THEN 1 ELSE 0 END) AS EmptyPosition_Diffs,
    SUM(CASE WHEN ISNULL(tgt.ExcludedOrIncluded,         '') <> ISNULL(src.ExcludedOrIncluded,         '') THEN 1 ELSE 0 END) AS ExcludedOrIncluded_Diffs,
    SUM(CASE WHEN ISNULL(tgt.IncumbentCount,             -1) <> ISNULL(src.IncumbentCount,             -1) THEN 1 ELSE 0 END) AS IncumbentCount_Diffs,
    SUM(CASE WHEN ISNULL(tgt.Incumbents,                 '') <> ISNULL(src.Incumbents,                 '') THEN 1 ELSE 0 END) AS Incumbents_Diffs,
    SUM(CASE WHEN ISNULL(tgt.JobCode,                    '') <> ISNULL(src.JobCode,                    '') THEN 1 ELSE 0 END) AS JobCode_Diffs,
    SUM(CASE WHEN ISNULL(tgt.JobCodeDesc,                '') <> ISNULL(src.JobCodeDesc,                '') THEN 1 ELSE 0 END) AS JobCodeDesc_Diffs,
    SUM(CASE WHEN ISNULL(tgt.JobFunc,                    '') <> ISNULL(src.JobFunc,                    '') THEN 1 ELSE 0 END) AS JobFunc_Diffs,
    SUM(CASE WHEN ISNULL(tgt.JobReqOpenDate,'1900-01-01') <> ISNULL(src.JobReqOpenDate,'1900-01-01') THEN 1 ELSE 0 END) AS JobReqOpenDate_Diffs,
    SUM(CASE WHEN ISNULL(tgt.JobReqStatus,               '') <> ISNULL(src.JobReqStatus,               '') THEN 1 ELSE 0 END) AS JobReqStatus_Diffs,
    SUM(CASE WHEN ISNULL(tgt.LastIncumbents,             '') <> ISNULL(src.LastIncumbents,             '') THEN 1 ELSE 0 END) AS LastIncumbents_Diffs,
    SUM(CASE WHEN ISNULL(tgt.Location,                   '') <> ISNULL(src.Location,                   '') THEN 1 ELSE 0 END) AS Location_Diffs,
    SUM(CASE WHEN ISNULL(tgt.NocCode,                    '') <> ISNULL(src.NocCode,                    '') THEN 1 ELSE 0 END) AS NocCode_Diffs,
    SUM(CASE WHEN ISNULL(tgt.NocCodeDescr,               '') <> ISNULL(src.NocCodeDescr,               '') THEN 1 ELSE 0 END) AS NocCodeDescr_Diffs,
    SUM(CASE WHEN ISNULL(tgt.Organization,               '') <> ISNULL(src.Organization,               '') THEN 1 ELSE 0 END) AS Organization_Diffs,
    SUM(CASE WHEN ISNULL(tgt.PosStatusDescr,             '') <> ISNULL(src.PosStatusDescr,             '') THEN 1 ELSE 0 END) AS PosStatusDescr_Diffs,
    SUM(CASE WHEN ISNULL(tgt.PositionEmptyGt1Year,       '') <> ISNULL(src.PositionEmptyGt1Year,       '') THEN 1 ELSE 0 END) AS PositionEmptyGt1Year_Diffs,
    SUM(CASE WHEN ISNULL(tgt.PositionHasBaseIncumbent,   '') <> ISNULL(src.PositionHasBaseIncumbent,   '') THEN 1 ELSE 0 END) AS PositionHasBaseIncumbent_Diffs,
    SUM(CASE WHEN ISNULL(tgt.PositionTitle,              '') <> ISNULL(src.PositionTitle,              '') THEN 1 ELSE 0 END) AS PositionTitle_Diffs,
    SUM(CASE WHEN ISNULL(tgt.Program,                    '') <> ISNULL(src.Program,                    '') THEN 1 ELSE 0 END) AS Program_Diffs,
    SUM(CASE WHEN ISNULL(tgt.ProgramBranch,              '') <> ISNULL(src.ProgramBranch,              '') THEN 1 ELSE 0 END) AS ProgramBranch_Diffs,
    SUM(CASE WHEN ISNULL(tgt.ProgramDivision,            '') <> ISNULL(src.ProgramDivision,            '') THEN 1 ELSE 0 END) AS ProgramDivision_Diffs,
    SUM(CASE WHEN ISNULL(tgt.ProvincialQuadrant,         '') <> ISNULL(src.ProvincialQuadrant,         '') THEN 1 ELSE 0 END) AS ProvincialQuadrant_Diffs,
    SUM(CASE WHEN ISNULL(tgt.RegDistrictDesc,            '') <> ISNULL(src.RegDistrictDesc,            '') THEN 1 ELSE 0 END) AS RegDistrictDesc_Diffs,
    SUM(CASE WHEN ISNULL(tgt.RegOrTempDescr,             '') <> ISNULL(src.RegOrTempDescr,             '') THEN 1 ELSE 0 END) AS RegOrTempDescr_Diffs,
    SUM(CASE WHEN ISNULL(tgt.ReportsTo,                  '') <> ISNULL(src.ReportsTo,                  '') THEN 1 ELSE 0 END) AS ReportsTo_Diffs,
    SUM(CASE WHEN ISNULL(tgt.Supervisor,                 '') <> ISNULL(src.Supervisor,                 '') THEN 1 ELSE 0 END) AS Supervisor_Diffs,
    SUM(CASE WHEN ISNULL(CAST(tgt.YearsEmpty AS NVARCHAR(30)), '') <> ISNULL(CAST(src.YearsEmpty AS NVARCHAR(30)), '') THEN 1 ELSE 0 END) AS YearsEmpty_Diffs,
    COUNT(*) AS TotalMatchedRows
FROM dbo.Peoplesoft_EPC      tgt
INNER JOIN dbo.Stg_Peoplesoft_EPC src
    ON tgt.Position = src.Position
WHERE tgt.IsActive = 1;
