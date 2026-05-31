-- hem__internal_movements.sql
-- Internal movements (MoveType = 'Move') with org/dept before and after.
SET NOCOUNT ON;

SELECT
    EmplId,
    EffDt,
    Name,
    CompChange,
    MoveType2                    AS MovementType,
    SameOrg,
    SameLevel1,
    SameGroup,
    -- Prior state
    PriorDeptId,
    PriorDeptIdDescr,
    PriorLevel1,
    PriorOrganization,
    PriorSalAdminPlan,
    PriorGrade,
    PriorAnnualRt,
    -- New state
    NewDeptId,
    NewDeptIdDescr,
    NewLevel1,
    NewOrganization,
    NewSalAdminPlan,
    NewGrade,
    NewAnnualRt,
    FiscalYear
FROM dbo.Peoplesoft_HEM
WHERE IsActive  = 1
  AND MoveType  = 'Move'
ORDER BY EffDt DESC, EmplId;
