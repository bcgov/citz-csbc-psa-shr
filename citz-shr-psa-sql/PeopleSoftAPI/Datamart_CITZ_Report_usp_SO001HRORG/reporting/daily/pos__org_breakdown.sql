/*=============================================================================
File:    pos__org_breakdown.sql
Purpose: Active position counts grouped by Organization / Level1.
         Shows fill rate per organizational unit.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    Organization,
    Level1,
    COUNT(*)                                       AS TotalPositions,
    SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END) AS FilledPositions,
    SUM(CASE WHEN EmplId = '' THEN 1 ELSE 0 END)  AS VacantPositions,
    CAST(
        100.0 * SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,1))                               AS FillRatePct
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
GROUP BY Organization, Level1
ORDER BY TotalPositions DESC;
