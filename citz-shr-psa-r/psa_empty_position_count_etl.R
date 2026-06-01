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
# PeopleSoft API -> SQL Server ETL
# Dataset: EmptyPositionCount (Empty Position Count / EPC)
#
# This script:
#   1. Calls the PeopleSoft Analytics API (OData, Basic Auth, GET method)
#   2. Normalizes JSON (handles empty objects {} -> NA)
#   3. Renames JSON fields (mixed-case / spaced names) to SQL PascalCase
#   4. Loads into a SQL Server staging table (TRUNCATE + INSERT)
#   5. Executes a MERGE stored procedure (staging -> target + audit)
#
# Key notes:
#   - HTTP method: GET (unlike SO001HRORG which uses POST)
#   - URL includes ?$top=5000 page-size parameter
#   - Business key: Position (single column, 100% unique, 0 nulls observed)
#   - No deduplication required (Position is unique at source)
#   - Dropped records table exists as a protective guardrail (NULL_POSITION)
#   - Core JSON key is lowercase ("core") -- rename uses Core = "core"
#   - AsOfDate is report metadata (staging lineage only; excluded from target)
#
# Configuration:
#   - API credentials: system environment variables (PSA_API_USERNAME,
#     PSA_API_PROD_PASSWORD) - set via Windows System Environment Variables
#   - All other config: .Renviron.prod or .Renviron.test file
#   - See .Renviron.example for required variables
# ============================================================================

# --- Required packages -------------------------------------------------------

library(httr2)
library(jsonlite)
library(DBI)
library(odbc)
library(dplyr)
library(tibble)

# --- Load environment config file --------------------------------------------
# Determines which .Renviron file to load based on PSA_API_ENV.
# PSA_API_ENV can be set as a system env var, or defaults to PROD.
# Credentials (PSA_API_USERNAME, PSA_API_PROD_PASSWORD) remain in
# system environment variables and are NOT stored in .Renviron files.

api_env <- toupper(Sys.getenv("PSA_API_ENV", unset = "PROD"))

env_file <- switch(
  api_env,
  "TEST" = ".Renviron.test",
  "PROD" = ".Renviron.prod",
  stop(paste("Invalid PSA_API_ENV value:", api_env, "- must be TEST or PROD"))
)

if (!file.exists(env_file)) {
  stop(paste(
    "Environment config file not found:", env_file,
    "\nCopy .Renviron.example to", env_file, "and fill in values."
  ))
}

readRenviron(env_file)

# --- Configuration -----------------------------------------------------------

# From .Renviron file (non-sensitive config)
api_base_url <- Sys.getenv("PSA_API_BASE_URL")
sql_server   <- Sys.getenv("PSA_SQL_SERVER")
sql_database <- Sys.getenv("PSA_SQL_DATABASE")
proxy_host   <- Sys.getenv("PSA_PROXY_HOST")
proxy_port   <- as.integer(Sys.getenv("PSA_PROXY_PORT"))

# From system environment variables (sensitive credentials)
psa_user <- Sys.getenv("PSA_API_USERNAME")
psa_pass <- Sys.getenv("PSA_API_PROD_PASSWORD")

# API name (not sensitive - this is the dataset identifier)
api_name <- "Datamart_CITZ_Report_EmptyPositionCount"

# Full API URL (base + API name + page-size parameter)
# ?$top=5000 requests maximum page size to minimize pagination round-trips.
api_url <- paste0(api_base_url, api_name, "?$top=5000")

# Table names
staging_table <- "dbo.Stg_Peoplesoft_EPC"
target_table  <- "dbo.Peoplesoft_EPC"

# --- Validate required variables ---------------------------------------------

# Config from .Renviron file
config_vars <- c(
  "PSA_API_BASE_URL",
  "PSA_SQL_SERVER",
  "PSA_SQL_DATABASE",
  "PSA_PROXY_HOST"
)

# Credentials from system environment variables
credential_vars <- c(
  "PSA_API_USERNAME",
  "PSA_API_PROD_PASSWORD"
)

missing_config <- config_vars[Sys.getenv(config_vars) == ""]
missing_creds  <- credential_vars[Sys.getenv(credential_vars) == ""]

if (length(missing_config) > 0) {
  stop(paste(
    "Missing config in", env_file, ":",
    paste(missing_config, collapse = ", "),
    "\nSee .Renviron.example for required variables."
  ))
}

if (length(missing_creds) > 0) {
  stop(paste(
    "Missing credentials in system environment variables:",
    paste(missing_creds, collapse = ", "),
    "\nSet these via: Win+R -> sysdm.cpl -> Advanced -> Environment Variables"
  ))
}

cat("===================================================\n")
cat("PSA ETL starting\n")
cat("Environment:", api_env, "\n")
cat("Config file:", env_file, "\n")
cat("API Name:", api_name, "\n")
cat("Timestamp:", format(Sys.time()), "\n")
cat("===================================================\n")

# --- Helper: normalize empty JSON objects {} -> NA ---------------------------

normalize_cell <- function(x) {
  if (is.list(x) && length(x) == 0) return(NA)
  x
}

# --- Helper: fetch a single page from the API (GET method) -------------------

fetch_page <- function(url) {
  req <- request(url) |>
    req_auth_basic(psa_user, psa_pass) |>
    req_headers(Accept = "application/json") |>
    req_timeout(600) |>
    req_proxy(proxy_host, proxy_port)

  resp <- req_perform(req)
  resp_body_json(resp, simplifyVector = FALSE)
}

# --- Helper: fetch all pages (handles OData pagination) ----------------------

fetch_all <- function(start_url) {
  url   <- start_url
  pages <- list()
  i     <- 1

  repeat {
    raw <- fetch_page(url)

    if (!is.null(raw$value) && length(raw$value) > 0) {
      pages[[i]] <- raw$value
    }

    # Handle OData pagination (supports standard and non-standard key naming)
    next_link <- raw[["@odata.nextLink"]]
    if (is.null(next_link)) next_link <- raw[["odata.nextLink"]]

    if (is.null(next_link) || is.na(next_link) || next_link == "") break

    Sys.sleep(0.2)
    url <- next_link
    i   <- i + 1
  }

  if (length(pages) == 0) {
    return(tibble())
  }

  rows <- unlist(pages, recursive = FALSE)

  normalize_row <- function(x) {
    lapply(x, function(v) {
      if (is.list(v) && length(v) == 0) NA else v
    })
  }

  rows_norm <- lapply(rows, normalize_row)
  bind_rows(rows_norm)
}

# --- Fetch + parse -----------------------------------------------------------

df <- fetch_all(api_url)

if (nrow(df) == 0) stop("No rows returned from API.")

# --- Rename JSON field names to SQL PascalCase column names ------------------
# JSON fields use mixed casing (UPPER, Title_Case, snake_case, and one
# lowercase: "core").  All are mapped to PascalCase SQL column names.
# AsOfDate is report metadata (snapshot date; 1 distinct value per run);
# it is stored in staging for lineage but excluded from target/audit/MERGE.
#
# IMPORTANT: use any_of() so the rename is defensive against API schema drift.
# dplyr::rename() throws a hard error if a named column is absent; any_of()
# silently skips missing columns. This matters because fields that are always
# NULL / empty-object ({}) can be dropped by bind_rows() in some dplyr versions.
# Field names are sourced from the schema JSON (value[0] keys).

json_to_sql <- c(
  AsOfDate                 = "As_Of_Date",
  BaseIncumbents           = "BASE_INCUMBENTS",
  BusinessUnitDescr        = "Business_Unit_Descr",
  City                     = "CITY",
  ClassificationGroup      = "Classification_Group",
  Core                     = "core",
  CreateEffDt              = "Create_EFFDT",
  DeptId                   = "DEPTID",
  DeptIdDesc               = "DeptID_Desc",
  DevelopmentRegion        = "Development_Region",
  EmptyEffDt               = "Empty_EFFDT",
  EmptyPosition            = "Empty_Position",
  ExcludedOrIncluded       = "Excluded_or_Included",
  IncumbentCount           = "Incumbent_Count",
  Incumbents               = "Incumbents",
  JobCode                  = "Job_Code",
  JobCodeDesc              = "Job_Code_Desc",
  JobFunc                  = "Job_Func",
  JobReqOpenDate           = "Job_Req_Open_Date",
  JobReqStatus             = "Job_Req_Status",
  LastIncumbents           = "LAST_INCUMBENTS",
  Location                 = "LOCATION",
  NocCode                  = "NOC_Code",
  NocCodeDescr             = "NOC_Code_Descr",
  Organization             = "Organization",
  PosStatusDescr           = "Pos_Status_Descr",
  Position                 = "Position",
  PositionEmptyGt1Year     = "Position_Empty_Greater_Than_1_Year",
  PositionHasBaseIncumbent = "Position_Has_Base_Incumbent",
  PositionTitle            = "Position_Title",
  Program                  = "Program",
  ProgramBranch            = "Program_Branch",
  ProgramDivision          = "Program_Division",
  ProvincialQuadrant       = "Provincial_Quadrant",
  RegDistrictDesc          = "Reg_District_Desc",
  RegOrTempDescr           = "Reg_or_Temp_Descr",
  ReportsTo                = "Reports_To",
  Supervisor               = "Supervisor",
  YearsEmpty               = "Years_Empty"
)

df <- df |> dplyr::rename(any_of(json_to_sql))

# --- Validate expected columns -----------------------------------------------

expected <- c(
  "Position",
  "AsOfDate",
  "BaseIncumbents", "BusinessUnitDescr", "City", "ClassificationGroup",
  "Core", "CreateEffDt", "DeptId", "DeptIdDesc", "DevelopmentRegion",
  "EmptyEffDt", "EmptyPosition", "ExcludedOrIncluded",
  "IncumbentCount", "Incumbents",
  "JobCode", "JobCodeDesc", "JobFunc", "JobReqOpenDate", "JobReqStatus",
  "LastIncumbents", "Location", "NocCode", "NocCodeDescr",
  "Organization", "PosStatusDescr",
  "PositionEmptyGt1Year", "PositionHasBaseIncumbent", "PositionTitle",
  "Program", "ProgramBranch", "ProgramDivision", "ProvincialQuadrant",
  "RegDistrictDesc", "RegOrTempDescr", "ReportsTo", "Supervisor",
  "YearsEmpty"
)

# Hard-stop only if the business key is missing -- that is unrecoverable.
if (!"Position" %in% names(df)) {
  stop("Business key column Position is missing from the API response.")
}

# Backfill any other expected columns absent from the API response.
# bind_rows() silently drops columns where every row returned {} (empty object),
# so those fields never land in df. We still need them in staging as NA.
missing_cols <- setdiff(expected, names(df))
if (length(missing_cols) > 0) {
  warning(paste(
    "Columns absent from API response (all rows were {} -- backfilled as NA):",
    paste(missing_cols, collapse = ", ")
  ))
  df[missing_cols] <- NA
}

# Normalize any remaining list-columns to atomic values
for (col in expected) {
  df[[col]] <- lapply(df[[col]], normalize_cell)
  df[[col]] <- unlist(df[[col]], recursive = FALSE, use.names = FALSE)
}

# --- Type alignment (matches SQL Server staging schema) ----------------------

char_cols <- intersect(
  c("Position",
    "BaseIncumbents", "BusinessUnitDescr", "City", "ClassificationGroup",
    "Core", "DeptId", "DeptIdDesc", "DevelopmentRegion",
    "EmptyPosition", "ExcludedOrIncluded", "Incumbents",
    "JobCode", "JobCodeDesc", "JobFunc", "JobReqStatus",
    "LastIncumbents", "Location", "NocCode", "NocCodeDescr",
    "Organization", "PosStatusDescr",
    "PositionEmptyGt1Year", "PositionHasBaseIncumbent", "PositionTitle",
    "Program", "ProgramBranch", "ProgramDivision", "ProvincialQuadrant",
    "RegDistrictDesc", "RegOrTempDescr", "ReportsTo", "Supervisor"),
  names(df)
)

int_cols <- intersect(
  c("IncumbentCount"),
  names(df)
)

dec_cols <- intersect(
  c("YearsEmpty"),
  names(df)
)

date_cols <- intersect(
  c("AsOfDate", "CreateEffDt", "EmptyEffDt", "JobReqOpenDate"),
  names(df)
)

df <- df |>
  dplyr::mutate(
    dplyr::across(all_of(char_cols),  as.character),
    dplyr::across(all_of(int_cols),   ~ suppressWarnings(as.integer(.x))),
    dplyr::across(all_of(dec_cols),   ~ suppressWarnings(as.numeric(.x))),
    dplyr::across(all_of(date_cols),  ~ suppressWarnings(as.Date(.x)))
  )

# Select only staging columns in schema order
df <- df[, expected]

# --- Sanity check: row count must equal unique key count ---------------------
# Position is a single-column business key; uniqueness is guaranteed by the
# API (3859 rows, 3859 unique positions, 0 nulls confirmed in schema analysis).
# This check confirms the guarantee holds in the live API response.
unique_pos_count <- length(unique(df$Position[!is.na(df$Position)]))
if (nrow(df) != unique_pos_count) {
  stop(paste(
    "SANITY CHECK FAILED: nrow(df) =", nrow(df),
    "but unique Position count =", unique_pos_count,
    "-- unexpected duplicates in API response. Investigate before merging."
  ))
}

# --- Capture and drop rows with NULL/blank Position --------------------------
# NULL Position rows are data anomalies that cannot be keyed in the MERGE.
# Capture them for quality tracking BEFORE dropping from the main pipeline.
null_pos_mask <- is.na(df$Position) | df$Position == ""
null_pos_rows <- df[null_pos_mask, ]
null_pos_rows$DropReason <- "NULL_POSITION"

if (nrow(null_pos_rows) > 0) {
  warning(paste(
    nrow(null_pos_rows),
    "row(s) with NULL/blank Position captured for quality log and removed from pipeline."
  ))
  df <- df[!null_pos_mask, ]
}

# --- Combine all dropped rows for quality persistence ------------------------
dropped_df <- null_pos_rows
cat("Dropped rows captured for quality log:", nrow(dropped_df),
    "(NULL_POSITION:", nrow(null_pos_rows), ")\n")

# --- Load to SQL Server staging table ----------------------------------------

con <- dbConnect(
  odbc(),
  Driver                 = "ODBC Driver 17 for SQL Server",
  Server                 = sql_server,
  Database               = sql_database,
  Trusted_Connection     = "Yes",
  Encrypt                = "Yes",
  TrustServerCertificate = "Yes"
)

dbBegin(con)

dbExecute(con, paste0("TRUNCATE TABLE ", staging_table, ";"))

dbWriteTable(
  con,
  name      = Id(schema = "dbo", table = "Stg_Peoplesoft_EPC"),
  value     = df,
  append    = TRUE,
  row.names = FALSE
)

stg_cnt <- dbGetQuery(con, paste0("SELECT COUNT(*) AS StagingRows FROM ", staging_table, ";"))

dbCommit(con)

# --- Persist dropped records to quality tracking table (best-effort) ---------
# Dropped rows are appended to Stg_Peoplesoft_EPC_Dropped for SHR upstream
# data issue reporting and trend analysis across ETL runs.
# Failure here does NOT block the main pipeline -- wrapped in tryCatch.
if (nrow(dropped_df) > 0) {
  tryCatch({
    dbWriteTable(
      con,
      name      = Id(schema = "dbo", table = "Stg_Peoplesoft_EPC_Dropped"),
      value     = dropped_df,
      append    = TRUE,
      row.names = FALSE
    )
    cat("Dropped rows persisted to quality log:", nrow(dropped_df), "\n")
    drop_summary <- as.data.frame(table(dropped_df$DropReason))
    for (i in seq_len(nrow(drop_summary))) {
      cat(" ", drop_summary$Var1[i], ":", drop_summary$Freq[i], "\n")
    }
  }, error = function(e) {
    warning(paste("Best-effort quality log failed (pipeline continues):", conditionMessage(e)))
  })
} else {
  cat("No dropped rows to persist to quality log.\n")
}

# --- Execute MERGE stored procedure (staging -> target + audit) ---------------

dbExecute(con, "EXEC dbo.usp_Merge_PeopleSoft_EPC")

dbDisconnect(con)

# --- Summary ------------------------------------------------------------------

cat("===================================================\n")
cat("PSA EmptyPositionCount ETL completed\n")
cat("Environment:", api_env, "\n")
cat("Config file:", env_file, "\n")
cat("API Name:", api_name, "\n")
cat("Staging rows loaded:", stg_cnt$StagingRows, "\n")
cat("Completed at:", format(Sys.time()), "\n")
cat("===================================================\n")
