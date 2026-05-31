/*=============================================================================
File: compare_peoplesoft_vs_target_counts.sql
Purpose:
  Compare record counts between:
   - Staging (PeopleSoft API extract)
   - Target (all rows)
   - Target active vs inactive (soft deletes)
=============================================================================*/

SET NOCOUNT ON;

SELECT
    CAST('Staging (PeopleSoft API)' AS varchar(50)) AS SourceName,
    COUNT(*) AS RecordCount
FROM dbo.Stg_Peoplesoft_Dept_Org_Levels

UNION ALL

SELECT
    CAST('Target (All Rows)' AS varchar(50)) AS SourceName,
    COUNT(*) AS RecordCount
FROM dbo.PeopleSoft_Dept_Org_Levels

UNION ALL

SELECT
    CAST('Target (Active Only)' AS varchar(50)) AS SourceName,
    COUNT(*) AS RecordCount
FROM dbo.PeopleSoft_Dept_Org_Levels
WHERE IsActive = 1

UNION ALL

SELECT
    CAST('Target (Inactive / Soft Deleted)' AS varchar(50)) AS SourceName,
    COUNT(*) AS RecordCount
FROM dbo.PeopleSoft_Dept_Org_Levels
WHERE IsActive = 0;