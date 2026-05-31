/*=============================================================================
File: pos__headcount_summary.sql
Purpose: Headcount by Organization / Level1 / Level2, split by filled vs vacant.
Notes:
  - A row is filled when EmplId <> ''.
  - A row is vacant when EmplId = ''.
  - Only active rows (IsActive = 1) are counted.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    Organization,
    Level1,
    Level2,
    COUNT(*)                                                       AS TotalPositions,
    SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END)                AS FilledPositions,
    SUM(CASE WHEN EmplId  = '' THEN 1 ELSE 0 END)                AS VacantPositions,
    CAST(
        ROUND(
            100.0 * SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END) / COUNT(*),
            1
        ) AS DECIMAL(5,1)
    )                                                              AS FillRatePct
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
GROUP BY
    Organization,
    Level1,
    Level2
ORDER BY
    Organization,
    Level1,
    Level2;
