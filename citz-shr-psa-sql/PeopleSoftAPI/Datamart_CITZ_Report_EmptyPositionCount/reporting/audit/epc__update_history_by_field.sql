-- epc__update_history_by_field.sql
-- Positions whose key vacancy attributes changed in the most recent MERGE run.

SELECT
    a.Position,
    e.PositionTitle,
    e.DeptIdDesc,
    a.AuditDtmUtc,
    a.ActionType,

    -- EmptyPosition flag change
    CASE WHEN ISNULL(a.OldEmptyPosition,'') <> ISNULL(a.NewEmptyPosition,'')
         THEN CONCAT(a.OldEmptyPosition, ' -> ', a.NewEmptyPosition) END
                                                    AS EmptyPositionChange,

    -- YearsEmpty change
    CASE WHEN ISNULL(CONVERT(NVARCHAR(20), a.OldYearsEmpty),'')
              <> ISNULL(CONVERT(NVARCHAR(20), a.NewYearsEmpty),'')
         THEN CONCAT(a.OldYearsEmpty, ' -> ', a.NewYearsEmpty) END
                                                    AS YearsEmptyChange,

    -- PositionTitle change
    CASE WHEN ISNULL(a.OldPositionTitle,'') <> ISNULL(a.NewPositionTitle,'')
         THEN CONCAT(a.OldPositionTitle, ' -> ', a.NewPositionTitle) END
                                                    AS PositionTitleChange,

    -- Incumbents change
    CASE WHEN ISNULL(a.OldIncumbents,'') <> ISNULL(a.NewIncumbents,'')
         THEN CONCAT(a.OldIncumbents, ' -> ', a.NewIncumbents) END
                                                    AS IncumbentsChange,

    -- Dept change
    CASE WHEN ISNULL(a.OldDeptId,'') <> ISNULL(a.NewDeptId,'')
         THEN CONCAT(a.OldDeptId, ' -> ', a.NewDeptId) END
                                                    AS DeptChange

FROM dbo.Peoplesoft_EPC_Audit AS a
JOIN dbo.Peoplesoft_EPC       AS e ON e.Position = a.Position
WHERE a.RunId = (
    SELECT TOP 1 RunId
    FROM dbo.Peoplesoft_EPC_Audit
    ORDER BY AuditDtmUtc DESC
)
  AND a.ActionType = 'UPDATE'
ORDER BY a.AuditDtmUtc DESC;
