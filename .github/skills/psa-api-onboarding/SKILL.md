---
name: psa-api-onboarding
description: Onboards a new PeopleSoft PSA API endpoint into the data integration pipeline. Activates when asked to create DDLs, MERGE procedures, ETL scripts, or reporting SQL for a new PSA API. Also activates when asked to onboard, add, integrate, or set up a new API.
---

# PSA API Onboarding Procedure

## Reference Implementations (Gold Standards)

- R ETL: [psa_so001hrorg_etl.R](../../citz-shr-psa-r/psa_so001hrorg_etl.R)
- SQL pipeline: [Datamart_CITZ_Report_vw_Dept_Org_Levels](../../citz-shr-psa-sql/PeopleSoftAPI/Datamart_CITZ_Report_vw_Dept_Org_Levels/)

**Read both fully before generating any new artifact.** Copy them; do not
reconstruct from memory.

## Step 1: Find the Schema

`citz-shr-psa-sql/PeopleSoftAPI/<api_name>/schemas/<api_name>_schema.json`

Use it to determine column names, data types, and key candidates.

## Step 2: Identify Business Key (CRITICAL)

- NEVER assume the first column is the key.
- ALWAYS validate uniqueness via `psa_key_discovery.R` + SQL DISTINCT.
- Key represents BUSINESS IDENTITY -- never attributes (status, reason, flags)
  and never report metadata (RunDate, ReportName).

| API shape | Key |
|---|---|
| Lookup | Single column |
| Relational entity | Composite |
| Report-style | Composite + dedup in R |

## Step 3: Staging DDL (`ddl/01_stage.sql`)

- Table: `Stg_Peoplesoft_<ApiCode>`
- NVARCHAR for strings, INT/DECIMAL/DATE as appropriate.
- Allow NULL where API allows NULL.
- **NO PRIMARY KEY** for report-style APIs (dedup happens in R).
- Document original JSON field names in column comments where they differ.

## Step 4: Target DDL (`ddl/02_target.sql`)

- Table: `Peoplesoft_<ApiCode>`
- Add: `IsActive BIT DEFAULT 1`, `CreatedUtc`, `LastUpdatedUtc DATETIME2(0) DEFAULT SYSUTCDATETIME()`.
- MUST enforce business key (`PRIMARY KEY` or `UNIQUE`).
- Composite key example: `PRIMARY KEY (PosPosition, EmplId)` with
  `EmplId NOT NULL DEFAULT ''` for nullable identity columns.
- For wide tables (>50 data cols): add `RowHash VARBINARY(32) NULL`.

## Step 5: Audit DDL (`ddl/03_audit.sql`)

- Table: `Peoplesoft_<ApiCode>_Audit`
- Include: `AuditId`, `RunId`, `AuditDtmUtc`, `ActionType`, ALL business key columns, `OldRowHash`/`NewRowHash`, `OldIsActive`/`NewIsActive`, Old/New for every tracked column.
- EXCLUDE report metadata columns.

## Step 6: Dropped Records DDL (`ddl/05_dropped_stage.sql`)

- Table: `Stg_Peoplesoft_<ApiCode>_Dropped`
- `DropReason NVARCHAR(100) NOT NULL`
- `LoadDtmUtc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()`
- All staging columns (same schema, all nullable).
- No PK; append-only across runs.

Common DropReason values: `'NULL_<KEY>'`, `'DUPLICATE_COMPOSITE_KEY'`.

## Step 7: MERGE Procedure (`ddl/04_merge_proc.sql`)

Procedure: `usp_Merge_PeopleSoft_<ApiCode>`. Standard guardrails:

| Code | Condition |
|---|---|
| 51000 | Empty staging |
| 51001 | NULL business key |
| 51002 | Row variance threshold exceeded |
| 51003 | Soft-delete cap exceeded |

MERGE rules:
- MATCHED + changed -> UPDATE
- NOT MATCHED -> INSERT
- NOT MATCHED BY SOURCE -> soft delete (`IsActive = 0`, NEVER physical DELETE)

Composite key ON clause (NULL-safe):
```sql
ON tgt.PosPosition = src.PosPosition
AND ISNULL(tgt.EmplId, '') = ISNULL(src.EmplId, '')
```

Change detection:
- <= ~55 data cols: individual column comparisons in `WHEN MATCHED`.
- > ~50 data cols: use `RowHash` (`SHA2_256` over `CONCAT_WS('|', COALESCE(...))`).

## Step 8: R ETL Script

File: `psa_<api_code>_etl.R`.

**Copy [psa_so001hrorg_etl.R](../../citz-shr-psa-r/psa_so001hrorg_etl.R) verbatim.**
Change ONLY:
- `api_name`
- `staging_table`, `dropped_table`
- MERGE proc name
- `json_to_sql` rename map
- `key_cols`
- `char_cols` / `int_cols` / `dec_cols` / `date_cols`
- Header comments

Do NOT change libraries, env var names, auth, proxy, HTTP, JSON parsing,
row binding, DB connection params, or banner format. See
[r-scripts.instructions.md](../../instructions/r-scripts.instructions.md).

## Step 9: Sanity Checks Before Commit

- [ ] Business key validated; `nrow(df)` == `nrow(unique(df[, key_cols]))` after dedup
- [ ] Staging matches schema
- [ ] Target enforces key
- [ ] MERGE ON uses correct keys + NULL-safe comparisons
- [ ] Report metadata excluded from MERGE/HASHBYTES/target
- [ ] Dropped records captured + persisted
- [ ] R script passes ASCII verification (`LC_ALL=C grep ...`)
- [ ] R script structure matches reference (diff against `psa_so001hrorg_etl.R`)
- [ ] Naming conventions, no credentials in code

---

# Known API Patterns (Lessons Learned)

## API 1: Datamart_CITZ_Report_vw_Dept_Org_Levels (DeptOrg)

Clean relational entity, single key, no report metadata. Used as the SQL
gold standard.

## API 2: SO001HRORG

- HTTP: POST, ~75 columns, ~3795 rows
- Initial assumption `PosPosition` alone failed -- 71 duplicates
- Actual key: **composite `PosPosition + EmplId`** -> 3791 unique
- 4 remaining duplicates caused by `FutureTermReason` (Redundant vs Retired)
- Decision: `FutureTermReason` is an ATTRIBUTE, not key. Deduplicate in R.
- Staging has NO PK. `PosPosition` allows NULL.
- Dropped reasons: `'NULL_POSPOSITION'`, `'DUPLICATE_COMPOSITE_KEY'`

**Architectural insight:** some PSA APIs are report outputs, not normalized
entities. The pipeline must handle key discovery, dedup, and flexible staging.

## API 3: SHR010HRORG (Employee HeadCount by Classification)

- HTTP: GET, ~2,764 rows, reporting prefix `hc__`
- Single-column key: `EmplId` (NVARCHAR(20)), 100% unique, 0 nulls
- No dedup needed; staging enforces PK on `EmplId`
- Report metadata: `AsOfDate` (1 distinct value per run) -- staging only
- New patterns introduced:
  - DATE cols: Birthdate, HireDt, LastHireDt, MostHistoricDate, FirstDateInOrganization, FirstDateInPosition, FutureReturnDate, LayoffLeaveStopPayStartDate, AsOfDate
  - DECIMAL(18,4): AnnualRt, CompRate; DECIMAL(12,4): HourlyRt; DECIMAL(8,4): Age; DECIMAL(6,2): StdHours
  - INT: EmplRcd, Step
- MERGE ON: `tgt.EmplId = src.EmplId` (no ISNULL needed)
- Nullable `{}` fields handled by `normalize_cell()`
- Dropped reason: `'NULL_EMPLID'`

## API 4: Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ (HEM)

- HTTP: GET, ~10,567 rows, reporting prefix `hem__`
- **4-column composite key:** `EmplId + EffDt + EffSeq + EmplRcd` (PeopleSoft JOB row key)
- 140 columns -> too wide for individual `WHEN MATCHED` comparisons
- **RowHash pattern required** (threshold >~50 data cols):
  1. Add `RowHash VARBINARY(32) NULL` to target
  2. Pre-compute in source CTE:
     ```sql
     _RowHash = HASHBYTES('SHA2_256', CAST(CONCAT_WS('|', col1, col2, ...) AS NVARCHAR(MAX)))
     ```
     - Nullable strings: `COALESCE(col, '')`
     - Nullable dates: `COALESCE(CONVERT(NVARCHAR(10), col, 23), '')`
     - Nullable numerics: `COALESCE(CONVERT(NVARCHAR(38), col), '')`
  3. `WHEN MATCHED` condition: `tgt.IsActive = 0 OR tgt.RowHash <> src._RowHash`
  4. `SET RowHash = src._RowHash` in UPDATE + INSERT branches
- Column sections: Event header (5), `New_*` (57), `Prior_*` (61)
- ~1,377 rows have all-NULL `Prior_*` columns -- EXPECTED (hire events, no prior state)
- Dropped reasons: `'NULL_EMPLID'`, `'DUPLICATE_COMPOSITE_KEY'`

## API 5: Datamart_CITZ_Report_TimeInPositionEmployee (TIP)

- HTTP: GET, ~18,551 rows, reporting prefix `tip__`
- **4-column composite key:** `EmployeeId + Position + EntryDate + EntrySeq`
- 55 columns -> individual `WHEN MATCHED` comparisons fine (no RowHash)
- ~2,764 rows have NULL `ExitDate` -- EXPECTED (still in position)
- **JSON field `core` is lowercase** -- rename map must use `Core = "core"`
- No report metadata columns
- Dropped reasons: `'NULL_EMPLOYEEID'`, `'DUPLICATE_COMPOSITE_KEY'`

## API 6: Datamart_CITZ_Report_EmptyPositionCount (EPC)

- HTTP: GET, ~3,859 rows, reporting prefix `epc__`
- **Single-column key:** `Position` (NVARCHAR(20), 100% unique, 0 nulls)
- No deduplication needed; staging enforces PK on `Position`
- **Report metadata:** `As_Of_Date` (JSON key) -> `AsOfDate` (1 distinct value
  per run, snapshot date) -- stored in staging for lineage, EXCLUDED from
  target/audit/MERGE/HASHBYTES
- `Business_Unit_Descr` and `Organization` each have 1 distinct value; these
  are positional ATTRIBUTES (org scope filter), NOT report metadata -- include
  in target and HASHBYTES
- 39 columns total (38 tracked; 37 in MERGE WHEN MATCHED); individual column
  comparisons used (37 < threshold of ~50)
- **JSON field `core` is lowercase** -- rename must use `Core = "core"` (same
  as TIP; two APIs now with this pattern)
- API URL requires `?$top=5000` page-size parameter; `req_timeout(600)`
- Nullable fields: EmptyEffDt (~2925), LastIncumbents (~2925), BaseIncumbents
  (~1225), IncumbentCount (~1173), Incumbents (~1173), Supervisor (~578),
  ProgramBranch (~108), JobReqOpenDate (~3474), JobReqStatus (~3474)
- Dropped reason: `'NULL_POSITION'` (protective guardrail; 0 null positions
  observed in analysis)

---

# Cross-Cutting Lessons

## APIs 4-5: Pattern Drift Fix

**Symptom:** ETL scripts generated in a batch diverged from the reference:
Unicode chars in banners, wrong env var names (`PSA_DB_DRIVER` instead of
`PSA_SQL_*`), wrong auth (`req_auth_bearer_token` instead of `req_auth_basic`),
missing proxy, wrong JSON parsing (`fromJSON`), wrong row binding
(`purrr::map_dfr`), wrong DB driver/params, no env validation, DB connection
opened at top of script.

**Root cause:** Insufficient anchoring to the reference. The agent
reconstructed scripts from generic R ETL memory instead of copying the
reference and swapping only API-specific pieces.

**Fix applied:**
1. ASCII-only rule + verification command in
   [r-scripts.instructions.md](../../instructions/r-scripts.instructions.md)
2. Mandatory Script Structure table listing every locked-in choice
3. Pattern Consistency Rule in [copilot-instructions.md](../../copilot-instructions.md)

**Prevention for APIs 6+:**
- Always open `psa_so001hrorg_etl.R` BEFORE generating.
- Diff the new script against it before declaring done.
- Run ASCII verification before commit.

## Data Quality Tracking (mandatory for every API)

Rows excluded from the pipeline MUST be persisted to
`Stg_<ApiName>_Dropped`, not just logged. Warning logs disappear; a SQL
table is permanent and queryable, and enables trend analysis across runs.

Reporting: create `reporting/audit/audit__dropped_records_summary.sql`
showing count by `DropReason`, latest `LoadDtmUtc`, and sample records.

## Wide-Table MERGE Threshold

| Data columns | Approach |
|---|---|
| <= ~55 | Individual column OR comparisons in `WHEN MATCHED` |
| > ~50 | `RowHash VARBINARY(32)` + `SHA2_256(CONCAT_WS(...))` |

Overlap zone (50-55): prefer RowHash for readability and ease of maintenance.

## API 6 (EPC): Audit Type Safety (CRITICAL)

**Symptom:** EPC MERGE failed at runtime with
`Error converting data type nvarchar to numeric` at `OUTPUT ... INTO
dbo.Peoplesoft_EPC_Audit`. The audit table had typed Old/New columns
(DATE, INT, DECIMAL, BIT, varying NVARCHAR widths). The MERGE OUTPUT bind
attempted implicit conversion against the audit column types and failed
the moment any source column's type or width drifted.

**Root cause:** A typed audit table forces every MERGE OUTPUT to satisfy
implicit conversion rules across the entire schema. Any drift -- a new
NULL, a longer string, a non-numeric value in a previously numeric column
-- breaks the entire MERGE.

**Fix (applied uniformly across all 6 APIs):**

1. Audit table standard
   - All `Old*` / `New*` columns: `NVARCHAR(255) NULL` -- including
     `OldIsActive` / `NewIsActive`.
   - `OldRowHash` / `NewRowHash`: `VARBINARY(32) NULL`.
   - Native types kept only for: `AuditId BIGINT IDENTITY`,
     `RunId UNIQUEIDENTIFIER`, `AuditDtmUtc DATETIME2(0)`,
     `ActionType VARCHAR(12)`, business-key columns.

2. MERGE OUTPUT standard
   - Every `deleted.*` / `inserted.*` value column is explicitly cast to
     `NVARCHAR(255)`:
     - NVARCHAR / VARCHAR -> `CAST(deleted.Col AS NVARCHAR(255))`
     - DATE              -> `CONVERT(NVARCHAR(255), deleted.Col, 23)`
     - INT / DECIMAL / BIT -> `CAST(deleted.Col AS NVARCHAR(255))`

**Rationale:** NVARCHAR(255) is a type-agnostic landing zone. It removes
all OUTPUT bind fragility, survives schema drift, and lets the audit table
accept any value the source produces.

**Prevention for APIs 7+:**
- Generate audit DDL with all Old/New columns as `NVARCHAR(255) NULL`.
- Generate MERGE OUTPUT with explicit CAST/CONVERT on every value.
- The sanity-check prompt (`.github/prompts/sanity-check.prompt.md`)
  now includes an "Audit Type Check" step that rejects any DATE, INT,
  DECIMAL, BIT, or BINARY Old/New column, and rejects any uncast
  `deleted.*` / `inserted.*` in OUTPUT.
- Codified in `.github/instructions/sql.instructions.md` (Audit Table
  Column Types) and `.github/copilot-instructions.md` (Audit Type Safety).

---

## API 7 (SHR010HRORG): Continuously-Computed Columns in WHEN MATCHED (CRITICAL)

**Symptom:** Run 1 (2026-05-31) produced 2764 INSERTs, 0 UPDATEs (correct —
first load). Run 2 (2026-06-02) produced 2 INSERTs, 2759 UPDATEs, 5 soft
deletes. Expected: near-zero UPDATEs (no real data changed).

**Root cause:** `Age DECIMAL(8,4)` was included in the `WHEN MATCHED`
comparison. PeopleSoft computes `Age` continuously as
`(AsOfDate - Birthdate) / 365.25`. Since `AsOfDate` increments daily, `Age`
changes by approximately 1/365.25 per day for every employee. Over 2 days,
every employee's `Age` differs by ~0.0055. The DECIMAL comparison fired for
every matched row, producing 100% false UPDATE detection.

**Why it looks correct but isn't:** `Age` uses a native DECIMAL-to-DECIMAL
comparison (`ISNULL(tgt.Age, -1) <> ISNULL(src.Age, -1)`), which is the
correct type pattern. The bug is not in the comparison syntax -- it is in
including a column whose value is mathematically guaranteed to change on every
run. The same root cause as `AsOfDate`.

**Fix applied to `usp_Merge_PeopleSoft_SHR010HRORG`:**
1. Removed `OR ISNULL(tgt.Age, -1) <> ISNULL(src.Age, -1)` from `WHEN MATCHED`.
2. Removed `Age` from both `OldRowHash` and `NewRowHash` `HASHBYTES` calls.
3. Kept `Age` in `UPDATE SET` (stays current whenever a real change fires).
4. Kept `OldAge` / `NewAge` in `OUTPUT` (informational context in audit).
5. Also fixed 5 nullable DATE columns that used bare `<>` (misses NULL-to-value
   transitions) and 3 that used `CONVERT(NVARCHAR(10), col, 23)` (unnecessary)
   -- all replaced with `ISNULL(tgt.Col, '1900-01-01') <> ISNULL(src.Col, '1900-01-01')`.

**Audit across all 6 APIs (performed after SHR010HRORG fix):**
Same root cause found in 3 other procs. All fixed identically (removed from
WHEN MATCHED and HASHBYTES; kept in UPDATE SET and OUTPUT):

| API | Column | Type | Computed from |
|---|---|---|---|
| SO001HRORG | `Age` | `INT` | `AsOfDate − Birthdate` |
| EPC | `YearsEmpty` | `DECIMAL(10,4)` | `AsOfDate − EmptyEffDt` |
| TIP | `DaysInPosition` | `INT` | `AsOfDate − FirstDateInPosition` (active rows) |
| TIP | `YearsInPosition` | `DECIMAL(10,4)` | `DaysInPosition / 365.25` (active rows) |
| TIP | `AccumulatedYearsInPositions` | `DECIMAL(10,4)` | includes current active position |
| HEM | `EstimatedYrsOfService` | `DECIMAL` | `AsOfDate − FirstDateOfService` |
| HEM | `EstimatedYearsOfService` | `DECIMAL` | same |
| HEM | `EstimatedYearsOfServiceStr` | string | string form of above |
| HEM | `NewEstimatedYearsInOrg` (+`Str`) | `DECIMAL` / string | `AsOfDate − NewFirstDateInOrg` |
| HEM | `NewEstimatedYearsInPos` (+`Str`) | `DECIMAL` / string | `AsOfDate − NewFirstDateInPosition` |
| HEM | `PriorEstimatedYearsInOrg` (+`Str`) | `DECIMAL` / string | `AsOfDate − PriorFirstDateInOrg` |
| HEM | `PriorEstimatedYearsInPos` (+`Str`) | `DECIMAL` / string | `AsOfDate − PriorFirstDateInPosition` |

HEM evidence: run on 2026-06-02 produced 7935 UPDATEs / 10556 active rows (~75%).
After excluding the 11 `Estimated*` columns from the `_RowHash` CTE, only true
data changes trigger UPDATEs. The 11 columns are still propagated to the target
via `UPDATE SET` / `INSERT` so reported values stay current.

Initial belief that `HEM.Estimated*` was snapshotted to `EffDt` was WRONG \u2014
the API recomputes against the current `AsOfDate` on every run.

Safe (truly snapshotted to a historical date, NOT continuously computed):
`TIP.AgeAtEntry`, `TIP.AgeAtExit`.

**Prevention for APIs 7+:**
- Before writing WHEN MATCHED, classify every non-STRING column:
  - Is it computed from `AsOfDate` or the current run date? → EXCLUDE.
  - Is it snapshotted to a historical event date? → INCLUDE.
- Common red-flag names: `Age*` (unless `*At<Event>`), `Years*`, `Days*`,
  `Months*`, `Duration*`, `TimeIn*`, `*OfService` (unless snapshotted).
- Conditional-active red flag: columns that only change while an event is
  open (e.g., `ExitDate IS NULL`) \u2014 same problem, only on the active subset.
- Use the rule codified in `.github/instructions/sql.instructions.md`
  (WHEN MATCHED Comparison Rules → Continuously-computed columns).
---

## Model Selection Guide

This guide helps the human operator choose the correct model in VS Code Copilot Chat. Auto model selection is useful but does NOT include high-reasoning models like Opus, so manual overrides are required for certain tasks.

### Model Selection Table

| Task | Recommended Model | Reason |
|------|------------------|--------|
| Single API onboarding (≤ 30 files) | Auto or Sonnet | Fast, efficient, follows patterns well |
| Multi-API batch onboarding (≥ 2 APIs / ≥ 60 files) | Opus (manual select) | Better at maintaining consistency across large outputs |
| Schema/key discovery analysis | Opus (manual select) | Requires deeper reasoning and pattern recognition |
| Complex merge logic / composite key design | Opus (manual select) | High reasoning complexity |
| Debugging specific SQL or R errors | Auto or Sonnet | Focused, fast response |
| Reporting SQL generation | Auto or Sonnet | Repetitive pattern-based work |
| Full-file rewrites (large SQL/R scripts) | Opus (manual select) | Avoids truncation / output limits |
| Documentation (MD updates) | Auto or Sonnet | Both perform well |

### Important Notes

- Auto model selection does NOT route to Opus-class models.
- Auto optimizes for cost, speed, and availability — not maximum reasoning capability.
- Opus must be selected manually from the model picker when needed.
- Use Opus for:
  - Large outputs
  - Cross-file consistency
  - Architecture decisions
- Use Auto for default workflows (recommended baseline).

### Operational Rule

Default to Auto for day-to-day work.

Switch to Opus manually when:
- Output size is large (multi-file generation)
- The problem requires deeper reasoning
- You observe pattern drift or inconsistent outputs
- You hit response length limits
## Public Repo Sanitization Rule (CRITICAL)

This repository is public. Sample/example values in any committed artifact
MUST be bogus, format-preserving placeholders -- never real BC Gov data.

- Never commit real names, EmplIds, position numbers, jobcodes, deptids,
  emails, IDIRs, birthdates, hire dates, or salary figures.
- Schema JSON sample rows, key-analysis JSON, SQL comment examples, R
  script comment examples, and markdown docs are all in scope.
- Preserve structure, keys, data types, counts, and business rules; redact
  only the literal sensitive values.
- Use the standard placeholders: name "Sample,Person", emplid "999999",
  position "00099999" / "00088888" / "00077777", jobcode "999999",
  email "sample.person@example.gov", IDIR "sampleperson", birthdate
  "1990-01-01", salary 99999.0000 / 9999.99 / 99.9999.