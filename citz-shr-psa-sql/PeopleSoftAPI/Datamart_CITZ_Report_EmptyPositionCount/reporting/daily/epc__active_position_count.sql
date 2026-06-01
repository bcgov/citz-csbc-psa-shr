-- epc__active_position_count.sql
-- Total active position count by empty vs filled status.

SELECT
    e.EmptyPosition                              AS EmptyFlag,
    COUNT(*)                                     AS PositionCount,
    CAST(COUNT(*) * 100.0 /
         SUM(COUNT(*)) OVER ()
    AS DECIMAL(5,2))                             AS PctOfTotal
FROM dbo.Peoplesoft_EPC AS e
WHERE e.IsActive = 1
GROUP BY e.EmptyPosition
ORDER BY e.EmptyPosition;
