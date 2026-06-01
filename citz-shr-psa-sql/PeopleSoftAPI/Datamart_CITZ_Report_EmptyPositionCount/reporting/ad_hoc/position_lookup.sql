-- position_lookup.sql
-- Full record for a single position by Position number.
-- Replace the Position value to inspect any specific position.

DECLARE @Position NVARCHAR(20) = '00000000';  -- replace with target Position

SELECT
    e.Position,
    e.PositionTitle,
    e.DeptId,
    e.DeptIdDesc,
    e.EmptyPosition,
    e.EmptyEffDt,
    e.YearsEmpty,
    e.PositionEmptyGt1Year,
    e.PositionHasBaseIncumbent,
    e.IncumbentCount,
    e.Incumbents,
    e.BaseIncumbents,
    e.LastIncumbents,
    e.ClassificationGroup,
    e.JobCode,
    e.JobCodeDesc,
    e.JobFunc,
    e.NocCode,
    e.NocCodeDescr,
    e.Program,
    e.ProgramBranch,
    e.ProgramDivision,
    e.BusinessUnitDescr,
    e.Organization,
    e.Core,
    e.DevelopmentRegion,
    e.ProvincialQuadrant,
    e.RegDistrictDesc,
    e.City,
    e.Location,
    e.RegOrTempDescr,
    e.ExcludedOrIncluded,
    e.PosStatusDescr,
    e.CreateEffDt,
    e.ReportsTo,
    e.Supervisor,
    e.JobReqStatus,
    e.JobReqOpenDate,
    e.IsActive,
    e.CreatedUtc,
    e.LastUpdatedUtc
FROM dbo.Peoplesoft_EPC AS e
WHERE e.Position = @Position;
