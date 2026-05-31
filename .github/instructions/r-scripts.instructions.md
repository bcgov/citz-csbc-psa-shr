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
- Read credentials from `Sys.getenv()` only
- Read config from `.Renviron.prod` / `.Renviron.test` via `readRenviron()`
- Validate required environment variables at script start with `stop()` on missing
- Always include Apache 2.0 license header
- Always call `dbDisconnect(con)` at end of script
- Use `dbExecute()` for DDL/DML, `dbGetQuery()` for SELECT