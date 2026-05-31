-- hem__active_records.sql
-- All active movement event records with key fields.
SET NOCOUNT ON;

SELECT
    EmplId,
    EffDt,
    EffSeq,
    EmplRcd,
    Name,
    MoveType,
    MoveType1,
    CompChange,
    FiscalYear,
    NewDeptId,
    NewDeptIdDescr,
    NewOrganization,
    NewLevel1,
    NewLevel2,
    NewEmplStatus,
    NewSalAdminPlan,
    NewGrade,
    NewStep,
    NewAnnualRt,
    NewPositionNbr,
    IsActive,
    LastUpdatedUtc
FROM dbo.Peoplesoft_HEM
WHERE IsActive = 1
ORDER BY EffDt DESC, EmplId;
