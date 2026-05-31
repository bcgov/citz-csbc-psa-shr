applyTo: "**/*.R"
R Script Standards

Use httr2 (not httr) for HTTP requests
Use resp_body_json() instead of resp_body_string() + fromJSON()
Use dplyr::mutate(across(...)) for type conversions, not per-column assignment
Use intersect(expected_cols, names(df)) for safe column selection
Handle OData pagination with fallback: @odata.nextLink then odata.nextLink
Normalize empty JSON objects {} to NA


JSON Field Renaming

NEVER use bare dplyr::rename(NewName = old_name, ...)
ALWAYS use rename(any_of(rename_map))

Example:
rename_map <- c(
PosRole = "pos role"
)
df <- df |> dplyr::rename(any_of(rename_map))

any_of() avoids hard failure when columns are missing
Place rename BEFORE column validation
Include all fields, including report metadata


Missing Column Handling (CRITICAL)
After renaming, backfill missing columns instead of failing:
missing_cols <- setdiff(expected, names(df))
if (length(missing_cols) > 0) {
warning(paste(
"Columns absent from API response (backfilled as NA):",
paste(missing_cols, collapse = ", ")
))
df[missing_cols] <- NA
}
Rules:

NEVER stop on missing non-key columns
ONLY stop if a business key column is missing


Business Key Validation (CRITICAL)

Hard stop ONLY if the primary identity column is missing or NULL
Secondary key columns may allow NULL (depending on design)

Example rule:

PosPosition → REQUIRED → stop if NULL
EmplId → OPTIONAL → normalize NULL


Deduplication (CRITICAL)
Some APIs return duplicate rows due to reporting artifacts.
Rules

Deduplicate BEFORE dbWriteTable()
Deduplicate ONLY on business key
Keep last record using fromLast = TRUE
Log number of duplicates removed
NEVER include attribute columns in dedup


Dedup Pattern (SO001HRORG STANDARD)
1. Drop invalid key rows (mandatory field)
invalid_rows <- sum(is.na(df$PosPosition) | df$PosPosition == "")
if (invalid_rows > 0) {
warning(paste("Dropping rows with NULL PosPosition:", invalid_rows))
df <- df[!(is.na(df$PosPosition) | df$PosPosition == ""), ]
}
2. Normalize nullable key column (vacant positions)
df$EmplId[is.na(df$EmplId)] <- ""
3. Deduplicate on composite business key
original_count <- nrow(df)
df <- df[!duplicated(paste(df$PosPosition, df$EmplId, sep="|"), fromLast = TRUE), ]
cat("Duplicates removed:", original_count - nrow(df), "\n")

Deduplication Rationale

Some APIs are report-style outputs (not true relational entities)
Duplicate rows may represent:

report artifacts
multi-valued attributes
data modeling artifacts



Example: SO001HRORG
Duplicate rows occur because:

Same employee + position
Different FutureTermReason (Redundant vs Retired)

These are NOT separate business records
Decision:

Business key = PosPosition + EmplId
FutureTermReason is NOT part of key
Deduplicate before staging load


Staging Load Rules

Perform ALL cleanup BEFORE dbWriteTable()
Staging table must receive:

valid keys
deduplicated rows
correctly typed columns




SQL Execution Rules

Use dbExecute() for DDL/DML
Use dbGetQuery() for SELECT
Do NOT mix the two


Environment Configuration

Read credentials using Sys.getenv() only
Load environment file using:

readRenviron(".Renviron.prod")
or
readRenviron(".Renviron.test")

Validate required variables:

required <- c("PSA_API_BASE_URL", "PSA_API_USERNAME", "PSA_API_PROD_PASSWORD")
missing <- required[Sys.getenv(required) == ""]
if (length(missing) > 0) {
stop(paste("Missing environment variables:", paste(missing, collapse = ", ")))
}

HTTP Method Handling

Read from schema discovery
If POST required:

req <- request(url) |> req_method("POST")

If GET → default behavior


Pagination Rules

Always handle pagination
Check both:

@odata.nextLink
odata.nextLink

Use:

Sys.sleep(0.2)
between calls

Report Metadata Handling

Include metadata fields in expected column list
Include in type conversion
Include in staging

BUT:

Do NOT use in:

MERGE ON
HASHBYTES
Target table




Connection Handling

Always close connection:

dbDisconnect(con)

Never leave open connections


Licensing

Include Apache 2.0 header at top of every script

