# PeopleSoft – Dept Org Levels

This folder contains SQL assets supporting the ingestion and auditing of
PeopleSoft Department / Organization hierarchy data.

## Structure

- ddl/
  Schema objects (tables, audit table, merge procedure).
  Executed once per environment.

- reporting/daily/
  Operational reporting for the most recent ingestion run.
  Safe to run daily.

- reporting/audit/
  Historical and audit-focused analysis across multiple runs.

- reporting/ad_hoc/
  Temporary or exploratory queries.

## Primary keys
- Business Key: DepartmentID
- Run boundary: RunId (from audit table)

## Notes
- Merge logic lives in `ddl/04_merge_proc.sql`
- No reporting script mutates data