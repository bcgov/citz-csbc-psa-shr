/*=============================================================================
File:    pos__active_position_list.sql
Purpose: Full list of all active positions with key attributes.
         Includes both filled and vacant positions.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    PosPosition,
    CASE WHEN EmplId <> '' THEN 'Filled' ELSE 'Vacant' END AS PositionStatus,
    EmplId,
    Name,
    Title,
    Organization,
    Level1,
    Level2,
    Level3,
    PosDepartment,
    PosDeptId,
    SupervisorPos,
    SupervisorName,
    Status,
    City
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
ORDER BY Organization, Level1, PosPosition;
