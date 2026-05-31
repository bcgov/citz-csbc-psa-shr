# Copilot Instructions — PeopleSoft HR Data Integration

## Project Context
This repository contains a standardized data integration pipeline for
BC Public Service Agency (PSA) PeopleSoft Analytics APIs. It ingests
OData API data into SQL Server using a staging → merge → audit pattern.

The first onboarded API is `Datamart_CITZ_Report_vw_Dept_Org_Levels`.
Use it as the reference implementation for all new APIs.

## Architecture
- **R scripts** (`citz-shr-psa-r/`): API fetch, JSON normalize, staging load
- **SQL scripts** (`citz-shr-psa-sql/PeopleSoftAPI/`): DDL, MERGE proc, reporting
- **Schema files** (`schemas/`): JSON schema snapshots for DDL generation

## Folder Structure (per API)
Each API lives in its own folder named exactly after the API: