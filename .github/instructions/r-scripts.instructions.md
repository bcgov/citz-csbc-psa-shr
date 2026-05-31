---
applyTo: "**/*.R"
---

# R Script Standards

- Use `httr2` (not `httr`) for HTTP requests
- Use `resp_body_json()` instead of `resp_body_string()` + `fromJSON()`
- Use `dplyr::mutate(across(...))` for type conversions, not per-column assignment
- Use `intersect(expected_cols, names(df))` for safe column selection
- Handle OData pagination with fallback: `@odata.nextLink` then `odata.nextLink`
- Normalize empty JSON objects `{}` to `NA`
- **Never use bare `dplyr::rename(NewName = old_name, ...)` for JSON field renaming.** Build a named character vector `c(NewName = "old_name")` and apply it with `dplyr::rename(any_of(rename_map))`. `any_of()` silently skips columns that are absent from the data frame; bare `rename()` throws a hard error. Fields that are always `{}` (empty object) in the API response can be dropped by `bind_rows()`, and live responses may omit fields present in the schema sample.
- Read credentials from `Sys.getenv()` only
- Read config from `.Renviron.prod` / `.Renviron.test` via `readRenviron()`
- Validate required environment variables at script start with `stop()` on missing
- Always include Apache 2.0 license header
- Always call `dbDisconnect(con)` at end of script
- Use `dbExecute()` for DDL/DML, `dbGetQuery()` for SELECT
- Use `Sys.sleep(0.2)` between paginated API calls (polite pacing)

## JSON Field Renaming
- When API returns snake_case or spaced field names, use `dplyr::rename()`
  to map them to PascalCase SQL column names
- Use backticks for field names with spaces: `\`pos role\`` -> PosRole
- Place rename BEFORE column validation
- Include all columns (including report metadata) in rename

## HTTP Method Detection
- Check the schema JSON `_discovery.method` field for GET or POST
- If POST: add `req_method("POST")` to the request pipeline
- If GET: no additional method setting needed (httr2 default)

## Report Metadata Handling
- Include report metadata columns in `expected` for validation
- Include in `char_cols` for type conversion
- Select staging columns with `df <- df[, expected]` to ensure correct order
- These columns exist in staging only — MERGE proc handles exclusion