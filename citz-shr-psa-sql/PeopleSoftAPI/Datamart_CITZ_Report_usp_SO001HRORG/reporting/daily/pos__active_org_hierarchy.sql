/*=============================================================================
File:    pos__active_org_hierarchy.sql
Purpose: Active positions grouped by Organization / Level1–Level3 hierarchy.
         Shows filled vs vacant breakdown per node.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    Organization,
    Level1,
    Level2,
    Level3,
    COUNT(*)                                       AS TotalPositions,
    SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END) AS FilledPositions,
    SUM(CASE WHEN EmplId = '' THEN 1 ELSE 0 END)  AS VacantPositions
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
GROUP BY Organization, Level1, Level2, Level3
ORDER BY Organization, Level1, Level2, Level3;
