-- hem__executive_summary.sql
-- Executive summary of movement events: hires, exits, moves by fiscal year.
SET NOCOUNT ON;

SELECT
    FiscalYear,
    SUM(CASE WHEN MoveType = 'Hire' THEN 1 ELSE 0 END)     AS TotalHires,
    SUM(CASE WHEN MoveType = 'Exit' THEN 1 ELSE 0 END)      AS TotalExits,
    SUM(CASE WHEN MoveType = 'Move' THEN 1 ELSE 0 END)      AS TotalMoves,
    COUNT(*)                                                  AS TotalEvents,
    COUNT(DISTINCT EmplId)                                    AS UniqueEmployees,
    SUM(CASE WHEN MoveType = 'Exit'
              AND NewLifeCycle = 'Retirement' THEN 1 ELSE 0 END) AS Retirements,
    SUM(CASE WHEN MoveType = 'Exit'
              AND NewLifeCycle = 'Termination' THEN 1 ELSE 0 END) AS Terminations
FROM dbo.Peoplesoft_HEM
WHERE IsActive = 1
GROUP BY FiscalYear
ORDER BY FiscalYear DESC;
