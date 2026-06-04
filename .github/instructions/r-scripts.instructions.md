---
applyTo: "**/*.R"
---

# R Script Standards

## ASCII-Only Rule (CRITICAL)

All R scripts MUST contain only ASCII characters (codes 0-127).

Prohibited: Unicode box-drawing (`──`, `│`, `└`), arrows (`→`, `←`),
em/en dashes (`—`, `–`), smart quotes (`"`, `"`, `'`, `'`), decorative
bullets (`•`, `◦`). Use instead: `---`, `->`, `--`, `"`, `'`, `-`, `*`.

Reason: the on-prem Windows scheduler runs under a locale that corrupts
non-ASCII bytes, producing mojibake in logs and breaking string comparisons.

Verify before commit (must return "ASCII-only: OK"):
```bash
LC_ALL=C grep -n '[^[:print:][:space:]]' path/to/script.R || echo "ASCII-only: OK"
```

## Mandatory Script Structure (CRITICAL)

Every PSA ETL script MUST follow the exact structure of the reference:
[psa_so001hrorg_etl.R](../../citz-shr-psa-r/psa_so001hrorg_etl.R).

Copy that file as the starting point for every new API. Do NOT change any of
the locked-in choices below without documenting WHY in the script header AND
updating this file:

| Concern | Required choice |
|---|---|
| Libraries | `httr2`, `jsonlite`, `DBI`, `odbc`, `dplyr`, `tibble` (NOT `purrr`) |
| Env loading | Task Scheduler safe bootstrap (see below) -- resolve `project_root` via `commandArgs()`, `setwd(project_root)`, load `.Renviron.<env>` via absolute path |
| Config env vars | `PSA_API_BASE_URL`, `PSA_SQL_SERVER`, `PSA_SQL_DATABASE`, `PSA_PROXY_HOST`, `PSA_PROXY_PORT` |
| Credential env vars | `PSA_API_USERNAME`, `PSA_API_PROD_PASSWORD`, `PSA_SQL_USERNAME`, `PSA_SQL_PASSWORD` -- SYSTEM env vars only, NEVER in `.Renviron.*` |
| Validation | `config_vars` + `credential_vars` checked, `stop()` on missing |
| HTTP client | `httr2` only (NOT `httr`) |
| Auth | `req_auth_basic(psa_user, psa_pass)` |
| Proxy | `req_proxy(proxy_host, as.integer(proxy_port))` |
| Timeout | `req_timeout(120)` |
| JSON parse | `resp_body_json(resp, simplifyVector = FALSE)` (NOT `fromJSON`) |
| Row binding | `bind_rows()` over `lapply(rows, normalize_row)` (NOT `purrr::map_dfr`) |
| Empty object `{}` | `normalize_cell()` converts to `NA` |
| DB driver | `ODBC Driver 17 for SQL Server` |
| DB auth | SQL auth required: `UID=sql_user, PWD=sql_pass, Trusted_Connection="No"`. NEVER `Trusted_Connection="Yes"` (fails under Task Scheduler with NT AUTHORITY\\ANONYMOUS LOGON). |
| DB connect args | `Encrypt="Yes"`, `TrustServerCertificate="Yes"` |
| DB connect placement | AFTER data prep + dedup, BEFORE staging load |
| Rename idiom | `dplyr::rename(any_of(json_to_sql))` (NEVER bare `rename()`) |
| Banners | `cat()` start banner + end banner with row counts |
| License | Apache 2.0 header at top |
| Copyright year | Current year |

## Task Scheduler Safe Bootstrap (CRITICAL)

Every ETL script MUST start with the bootstrap below BEFORE any other code
that reads files, env vars, or opens connections. This is the only way the
same script runs identically under Task Scheduler (cwd = `system32`) and
under RStudio (cwd = project root).

```r
# --- Robust environment loading (Task Scheduler safe) ----------------------
args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args[grep("--file=", args)])

if (length(script_path) > 0) {
  script_dir <- dirname(normalizePath(script_path))
} else {
  script_dir <- getwd()
}

project_root <- dirname(script_dir)   # parent of citz-shr-psa-r/
setwd(project_root)

api_env <- toupper(Sys.getenv("PSA_API_ENV", unset = "PROD"))
env_file <- switch(api_env,
  "TEST" = file.path(project_root, ".Renviron.test"),
  "PROD" = file.path(project_root, ".Renviron.prod"),
  stop("PSA_API_ENV must be TEST or PROD; got: ", api_env)
)
if (!file.exists(env_file)) stop("Env file not found: ", env_file)
readRenviron(env_file)
```

Hard rules:
- Resolve project root from `commandArgs()`, NEVER from `getwd()` alone.
- `setwd(project_root)` BEFORE any relative path.
- Load `.Renviron.<env>` via absolute path (`file.path(project_root, ...)`).
- `.Renviron.*` is for non-sensitive config ONLY. All passwords/usernames
  come from SYSTEM env vars (`PSA_API_USERNAME`, `PSA_API_PROD_PASSWORD`,
  `PSA_SQL_USERNAME`, `PSA_SQL_PASSWORD`).

## SQL Server Connection (CRITICAL)

Task Scheduler runs non-interactively without Kerberos delegation, so
`Trusted_Connection = "Yes"` fails with
`Login failed for user 'NT AUTHORITY\ANONYMOUS LOGON'`. Always use SQL auth:

```r
con <- dbConnect(
  odbc(),
  Driver                 = "ODBC Driver 17 for SQL Server",
  Server                 = sql_server,
  Database               = sql_database,
  UID                    = sql_user,           # from PSA_SQL_USERNAME
  PWD                    = sql_pass,           # from PSA_SQL_PASSWORD
  Trusted_Connection     = "No",
  Encrypt                = "Yes",
  TrustServerCertificate = "Yes"
)
```

## CMD Wrapper (Task Scheduler entry point)

Every scheduled ETL must be launched via a wrapper under
[citz-shr-psa-cmd/](../../citz-shr-psa-cmd/). The wrapper:
- Uses absolute paths for `Rscript.exe` and the `.R` script.
- Calls `Rscript.exe --vanilla` (ignore user `.Rprofile`/`.Renviron`).
- Writes stdout + stderr to `E:\Projects\citz-shr-psa\logs\<script>.log`.
- Records `%ERRORLEVEL%` and exits with it.
- Does NOT rely on the Task Scheduler "Start in" field.

See [run_tip_etl.cmd](../../citz-shr-psa-cmd/run_tip_etl.cmd) as the
canonical template; copy and change only `LOGFILE` and the `.R` script name.

## JSON Field Renaming

Place rename BEFORE column validation. Include all fields (report metadata included).

```r
json_to_sql <- c(PosRole = "pos role", EmplId = "EMPLID")
df <- df |> dplyr::rename(any_of(json_to_sql))
```

`any_of()` avoids hard failure when fields are absent.

## Missing Column Handling

After renaming, backfill missing non-key columns instead of failing:
```r
missing_cols <- setdiff(expected, names(df))
if (length(missing_cols) > 0) {
  warning(paste("Columns absent (backfilled as NA):", paste(missing_cols, collapse = ", ")))
  df[missing_cols] <- NA
}
```

ONLY `stop()` if a business key column is missing.

## Deduplication & Dropped Record Capture (CRITICAL)

Dedup BEFORE `dbWriteTable()`. Dedup ONLY on the business key. Keep last row
with `fromLast = TRUE`. Capture dropped rows for the quality table BEFORE
removing them from `df`.

Pattern:
```r
# 1. Capture + drop NULL key rows
null_mask <- is.na(df$PosPosition) | df$PosPosition == ""
null_rows <- df[null_mask, ]
null_rows$DropReason <- "NULL_POSPOSITION"
df <- df[!null_mask, ]

# 2. Normalize nullable key column (e.g. vacant positions)
df$EmplId[is.na(df$EmplId)] <- ""

# 3. Capture + drop duplicates on composite key
composite_key <- paste(df$PosPosition, df$EmplId, sep = "|")
dup_mask <- duplicated(composite_key, fromLast = TRUE)
dup_rows <- df[dup_mask, ]
dup_rows$DropReason <- "DUPLICATE_COMPOSITE_KEY"
df <- df[!dup_mask, ]

# 4. Combine + persist (best-effort, never blocks pipeline)
dropped_df <- rbind(null_rows, dup_rows)
tryCatch({
  dbWriteTable(con,
    name = Id(schema = "dbo", table = "Stg_<ApiName>_Dropped"),
    value = dropped_df, append = TRUE, row.names = FALSE)
}, error = function(e) warning(paste("Quality log failed:", conditionMessage(e))))
```

Never truncate the dropped table -- it is append-only history.

## Type Conversion

Use `dplyr::across(all_of(cols))`. List each type group explicitly. Wrap
numeric/date casts in `suppressWarnings()`.

```r
df <- df |> dplyr::mutate(
  dplyr::across(all_of(char_cols), as.character),
  dplyr::across(all_of(int_cols),  ~ suppressWarnings(as.integer(.x))),
  dplyr::across(all_of(dec_cols),  ~ suppressWarnings(as.numeric(.x))),
  dplyr::across(all_of(date_cols), ~ suppressWarnings(as.Date(as.character(.x))))
)
```

Rules:
- Dates -> R `Date` (produces SQL `DATE`, not `NVARCHAR`).
- Decimals -> R numeric (SQL `DECIMAL`).
- Integers -> R integer (SQL `INT`).
- NEVER cast numeric/date columns to character.

## Pagination

Always handle OData pagination. Check both `@odata.nextLink` and `odata.nextLink`.
Use `Sys.sleep(0.2)` between pages.

## SQL Execution

- `dbExecute()` for DDL/DML.
- `dbGetQuery()` for SELECT.
- Do NOT mix the two.
- Always `dbDisconnect(con)`.

## Report Metadata

Include in staging columns + type conversion. EXCLUDE from MERGE ON, HASHBYTES, target.

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
