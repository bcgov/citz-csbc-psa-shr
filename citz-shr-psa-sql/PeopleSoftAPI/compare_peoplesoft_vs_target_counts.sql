/*=============================================================================
File: compare_peoplesoft_vs_target_counts.sql
Purpose:
  Compare record counts between:
   - Staging (PeopleSoft API extract)
   - Target (current hierarchy state)
   - Active vs inactive (soft deletes)

Notes:
  - Staging represents the latest API snapshot.
  - Target contains cumulative history via soft delete.
  - Large or unexpected deltas should trigger investigation.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    'Staging (PeopleSoft API)' AS Source,
    COUNT(*) AS RowCount
FROM dbo.Stg_Peoplesoft_Dept_Org_Levels

UNION ALL

SELECT
    'Target (All Rows)' AS Source,
    COUNT(*)
FROM dbo.PeopleSoft_Dept_Org_Levels

UNION ALL

SELECT
    'Target (Active Only)' AS Source,
    COUNT(*)
FROM dbo.PeopleSoft_Dept_Org_Levels
WHERE IsActive = 1

UNION ALL

SELECT
    'Target (Inactive / Soft Deleted)' AS Source,
    COUNT(*)
FROM dbo.PeopleSoft_Dept_Org_Levels
WHERE IsActive = 0;
