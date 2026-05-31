/*=============================================================================
File: investigate_missing_departments.sql
Purpose:
  Identify departments that exist in the target table
  but are missing from the current staging (API) snapshot.

Interpretation:
  - These rows would be soft-deleted by the merge (unless @Force = 1).
  - Review carefully before approving large removals.
=============================================================================*/

SET NOCOUNT ON;

-- Departments currently active in target
-- but NOT present in the latest staging extract
SELECT
    tgt.DepartmentID,
    tgt.Organization,
    tgt.Level1,
    tgt.Level2,
    tgt.Level3,
    tgt.Level4,
    tgt.Level5,
    tgt.LastUpdatedUtc
FROM dbo.PeopleSoft_Dept_Org_Levels tgt
LEFT JOIN dbo.Stg_Peoplesoft_Dept_Org_Levels stg
    ON stg.DepartmentID = tgt.DepartmentID
WHERE tgt.IsActive = 1
  AND stg.DepartmentID IS NULL
ORDER BY tgt.DepartmentID;