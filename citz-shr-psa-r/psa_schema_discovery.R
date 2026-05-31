# Copyright 2026 Province of British Columbia
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ============================================================================
# PeopleSoft API - Schema Discovery Tool
#
# Purpose:
#   Fetches the FIRST element from a PeopleSoft Analytics API endpoint
#   and saves it as a formatted JSON schema file. This schema is used
#   to generate SQL Server DDLs (staging, target, audit tables).
#
# Supports:
#   - GET endpoints (standard OData)
#   - POST endpoints (some PeopleSoft APIs require POST)
#   - Endpoints that don't support $top (falls back gracefully)
#
# Outputs:
#   - Latest schema:   <api_name>_schema.json (always overwritten)
#   - Dated snapshot:  <api_name>_schema_<date>.json (append-only)
#   - Schema change detection (compares current vs previous latest)
#
# Usage:
#   1. Set the api_name variable below
#   2. Run this script (Source in RStudio or Rscript.exe)
#   3. Schema files saved to:
#      citz-shr-psa-sql/PeopleSoftAPI/<ApiFolder>/schemas/
# ============================================================================

library(httr2)
library(jsonlite)

# --- CONFIGURATION: Set your API name here -----------------------------------
# Change this value for each new API you want to discover.

api_name <- "Datamart_CITZ_Report_TimeInPositionEmployee"

# --- Resolve project root and load environment config ------------------------

get_script_dir <- function() {
  if (interactive() && requireNamespace("rstudioapi", quietly = TRUE)) {
    path <- rstudioapi::getActiveDocumentContext()$path
    if (nchar(path) > 0) return(dirname(path))
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("--file=", "", file_arg))))
  }
  return(getwd())
}

script_dir   <- get_script_dir()
project_root <- dirname(script_dir)

api_env  <- toupper(Sys.getenv("PSA_API_ENV", unset = "PROD"))
env_file <- file.path(project_root, switch(
  api_env,
  "TEST" = ".Renviron.test",
  "PROD" = ".Renviron.prod",
  stop(paste("Invalid PSA_API_ENV:", api_env))
))

if (!file.exists(env_file)) {
  stop(paste("Environment config file not found:", env_file))
}

readRenviron(env_file)

# --- Load config -------------------------------------------------------------

api_base_url <- Sys.getenv("PSA_API_BASE_URL")
psa_user     <- Sys.getenv("PSA_API_USERNAME")
psa_pass     <- Sys.getenv("PSA_API_PROD_PASSWORD")
proxy_host   <- Sys.getenv("PSA_PROXY_HOST")
proxy_port   <- as.integer(Sys.getenv("PSA_PROXY_PORT", unset = "8080"))

required <- c("PSA_API_BASE_URL", "PSA_API_USERNAME", "PSA_API_PROD_PASSWORD", "PSA_PROXY_HOST")
missing  <- required[Sys.getenv(required) == ""]
if (length(missing) > 0) {
  stop(paste("Missing environment variables:", paste(missing, collapse = ", ")))
}

# --- Helper: try an API call with error handling -----------------------------

try_api_call <- function(url, method = "GET") {
  req <- request(url) |>
    req_auth_basic(psa_user, psa_pass) |>
    req_headers(Accept = "application/json") |>
    req_timeout(120) |>
    req_proxy(proxy_host, proxy_port)
  
  if (toupper(method) == "POST") {
    req <- req |> req_method("POST")
  }
  
  tryCatch(
    {
      resp <- req_perform(req)
      list(
        success = TRUE,
        method  = method,
        url     = url,
        data    = resp_body_json(resp, simplifyVector = FALSE)
      )
    },
    error = function(e) {
      list(
        success = FALSE,
        method  = method,
        url     = url,
        error   = conditionMessage(e)
      )
    }
  )
}

# --- Try multiple strategies to fetch the first element ----------------------

cat("===================================================\n")
cat("PSA Schema Discovery\n")
cat("API Name:", api_name, "\n")
cat("Environment:", api_env, "\n")
cat("===================================================\n\n")

base_url <- paste0(api_base_url, api_name)

strategies <- list(
  list(url = paste0(base_url, "?$top=1"), method = "GET",  desc = "GET with $top=1"),
  list(url = base_url,                    method = "GET",  desc = "GET without $top"),
  list(url = paste0(base_url, "?$top=1"), method = "POST", desc = "POST with $top=1"),
  list(url = base_url,                    method = "POST", desc = "POST without $top")
)

result <- NULL

for (s in strategies) {
  cat("Trying:", s$desc, "...\n")
  attempt <- try_api_call(s$url, s$method)
  
  if (attempt$success) {
    cat("  -> SUCCESS (", s$method, ")\n\n")
    result <- attempt
    break
  } else {
    cat("  -> FAILED:", attempt$error, "\n")
  }
}

if (is.null(result)) {
  stop(paste(
    "\nAll strategies failed for API:", api_name,
    "\n\nPossible causes:",
    "\n  - API name is incorrect (check spelling and case)",
    "\n  - API requires specific query parameters or filters",
    "\n  - API requires a request body for POST",
    "\n  - Credentials don't have access to this endpoint",
    "\n\nTry accessing the API in a browser or Postman first."
  ))
}

# --- Extract first element ----------------------------------------------------

payload <- result$data

if (is.null(payload$value) || length(payload$value) == 0) {
  stop("API returned successfully but with no rows. Check if the API requires filters.")
}

first_element <- payload$value[[1]]

# --- Build schema object ------------------------------------------------------

schema <- list(
  `@odata.context` = payload$`@odata.context`,
  `_discovery` = list(
    api_name    = api_name,
    method      = result$method,
    url         = result$url,
    discovered  = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    environment = api_env
  ),
  value = list(first_element)
)

# --- Determine output path ---------------------------------------------------

# Use exact API name as folder name
api_folder <- api_name

output_dir <- file.path(
  project_root,
  "citz-shr-psa-sql",
  "PeopleSoftAPI",
  api_folder,
  "schemas"
)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  cat("Created directory:", output_dir, "\n")
}

# Latest schema (always overwritten - this is the "current" schema)
latest_file <- file.path(output_dir, paste0(api_name, "_schema.json"))

# Dated snapshot (append-only - for change detection)
date_stamp    <- format(Sys.Date(), "%Y-%m-%d")
snapshot_file <- file.path(output_dir, paste0(api_name, "_schema_", date_stamp, ".json"))

# --- Compare with previous latest (before overwriting) ------------------------

json_output <- toJSON(schema, pretty = TRUE, auto_unbox = TRUE)

schema_changed <- FALSE

if (file.exists(latest_file)) {
  old_content <- paste(readLines(latest_file, warn = FALSE), collapse = "\n")
  new_content <- json_output
  
  # Compare only the "value" portion (ignore discovery metadata like timestamp)
  old_parsed <- tryCatch(fromJSON(old_content, simplifyVector = FALSE), error = function(e) NULL)
  new_parsed <- tryCatch(fromJSON(new_content, simplifyVector = FALSE), error = function(e) NULL)
  
  if (!is.null(old_parsed) && !is.null(new_parsed)) {
    old_cols <- sort(names(old_parsed$value[[1]]))
    new_cols <- sort(names(new_parsed$value[[1]]))
    
    if (identical(old_cols, new_cols)) {
      cat("\n  Schema UNCHANGED from previous version.\n")
    } else {
      schema_changed <- TRUE
      added   <- setdiff(new_cols, old_cols)
      removed <- setdiff(old_cols, new_cols)
      
      cat("\n")
      cat("  ****************************************************\n")
      cat("  *** SCHEMA CHANGED from previous version! ***\n")
      cat("  ****************************************************\n")
      if (length(added) > 0)   cat("  Columns ADDED:  ", paste(added, collapse = ", "), "\n")
      if (length(removed) > 0) cat("  Columns REMOVED:", paste(removed, collapse = ", "), "\n")
      cat("  Review differences and update DDLs if needed.\n")
      cat("  ****************************************************\n")
    }
  }
} else {
  cat("\n  First discovery for this API (no previous schema to compare).\n")
}

# --- Write both files ---------------------------------------------------------

writeLines(json_output, latest_file)
writeLines(json_output, snapshot_file)

# --- Print to console ---------------------------------------------------------

cat("\n")
cat("=== JSON Schema (first element) ===\n")
cat(json_output)
cat("\n")
cat("===================================\n")

# --- Print column summary -----------------------------------------------------

cat("\n")
cat("=== Column Summary ===\n")
cat(sprintf("%-25s %-15s %-15s %s\n", "Column", "R Type", "SQL Suggestion", "Sample Value"))
cat(paste(rep("-", 85), collapse = ""), "\n")

for (col_name in names(first_element)) {
  val <- first_element[[col_name]]
  
  if (is.list(val) && length(val) == 0) {
    r_type  <- "empty_obj ({})"
    sql_sug <- "NULLABLE"
    sample  <- "{}"
  } else if (is.numeric(val)) {
    if (val == as.integer(val)) {
      r_type  <- "integer"
      sql_sug <- "INT"
    } else {
      r_type  <- "numeric"
      sql_sug <- "DECIMAL"
    }
    sample <- as.character(val)
  } else if (is.character(val)) {
    r_type  <- "character"
    sql_sug <- paste0("NVARCHAR(", max(50, nchar(val) * 2), ")")
    sample  <- if (nchar(val) > 30) paste0(substr(val, 1, 30), "...") else val
  } else if (is.logical(val)) {
    r_type  <- "logical"
    sql_sug <- "BIT"
    sample  <- as.character(val)
  } else if (is.null(val)) {
    r_type  <- "NULL"
    sql_sug <- "NULLABLE"
    sample  <- "NULL"
  } else {
    r_type  <- class(val)[1]
    sql_sug <- "NVARCHAR(255)"
    sample  <- as.character(val)
  }
  
  cat(sprintf("%-25s %-15s %-15s %s\n", col_name, r_type, sql_sug, sample))
}

cat(paste(rep("-", 85), collapse = ""), "\n")
cat("Total columns:", length(names(first_element)), "\n")
cat("HTTP Method used:", result$method, "\n")

cat("\n")
cat("===================================================\n")
cat("Schema discovery complete\n")
cat("  Latest:  ", latest_file, "\n")
cat("  Snapshot:", snapshot_file, "\n")
if (schema_changed) {
  cat("\n  *** ACTION REQUIRED: Schema has changed! ***\n")
  cat("  Update DDLs, MERGE proc, and ETL script.\n")
}
cat("\nNext steps:\n")
cat("  1. Review the JSON schema file\n")
cat("  2. Use it to generate DDLs (stage, target, audit)\n")
cat("  3. Create the MERGE stored procedure\n")
cat("  4. Create the ETL R script\n")
cat("===================================================\n")