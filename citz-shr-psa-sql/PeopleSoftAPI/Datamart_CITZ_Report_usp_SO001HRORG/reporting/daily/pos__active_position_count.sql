/*=============================================================================
File:    pos__active_position_count.sql
Purpose: Count of active positions — total, filled, and vacant.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    COUNT(*)                                       AS TotalPositions,
    SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END) AS FilledPositions,
    SUM(CASE WHEN EmplId = '' THEN 1 ELSE 0 END)  AS VacantPositions,
    CAST(
        100.0 * SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,1))                               AS FillRatePct
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1;
