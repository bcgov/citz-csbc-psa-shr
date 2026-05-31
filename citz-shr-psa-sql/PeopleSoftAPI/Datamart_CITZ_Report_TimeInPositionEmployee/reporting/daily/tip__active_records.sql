-- tip__active_records.sql
-- All active time-in-position records with key duration and classification fields.
SET NOCOUNT ON;

SELECT
    EmployeeId,
    Position,
    EntryDate,
    EntrySeq,
    ExitDate,
    EmployeeName,
    DaysInPosition,
    YearsInPosition,
    ClassificationGroupAtEntry,
    JobCodeAtEntry,
    Organization,
    Level1,
    Level2,
    DeptId,
    CurrentOrHistorical,
    CurrentStatus,
    IsActive,
    LastUpdatedUtc
FROM dbo.Peoplesoft_TIP
WHERE IsActive = 1
ORDER BY EntryDate DESC, EmployeeId;
