/*=============================================================================
File:    pos__active_employee_list.sql
Purpose: All active positions with an incumbent (EmplId <> '').
         Use for workforce headcount and employee attribute reporting.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    EmplId,
    Name,
    PosPosition,
    Title,
    JobRole,
    Grade,
    EmplClassification,
    Organization,
    Level1,
    Level2,
    PosDepartment,
    EmplStatus,
    Appt,
    Type,
    City
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
  AND EmplId <> ''
ORDER BY Organization, Name;
