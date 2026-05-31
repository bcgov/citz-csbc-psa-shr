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
# Dataset: SHR010HRORG (Employee HeadCount by Classification)
#
# This script:
#   1. Calls the PeopleSoft Analytics API (OData, Basic Auth, GET method)
#   2. Normalizes JSON (handles empty objects {} -> NA, e.g. Future_Return_Date)
#   3. Renames JSON fields (mixed case / ALLCAPS names) to SQL PascalCase names
#   4. Converts types: DATE columns -> Date, DECIMAL columns -> numeric,
#      INT columns -> integer, all others -> character
#   5. Captures NULL/blank EmplId rows to a separate dropped-records table
#      (precautionary — not observed in production data)
#   6. Loads into SQL Server staging table (TRUNCATE + INSERT)
#   7. Executes MERGE stored procedure (staging -> target + audit)
#
# Key facts about this API (from schema discovery and key_analysis):
#   - HTTP method: GET
#   - Rows: ~2,764
#   - Business key: EmplId (single column, 100% unique, 0 nulls)
#   - No deduplication needed (no duplicates observed)
#   - Report metadata: AsOfDate (1 distinct value per run = snapshot date)
#     -> Stored in staging ONLY; excluded from target/audit/HASHBYTES
#     -> Storing it in HASHBYTES would cause ALL rows to update every daily run
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

api_base_url <- Sys.getenv("PSA_API_BASE_URL")
sql_server   <- Sys.getenv("PSA_SQL_SERVER")
sql_database <- Sys.getenv("PSA_SQL_DATABASE")
proxy_host   <- Sys.getenv("PSA_PROXY_HOST")
proxy_port   <- as.integer(Sys.getenv("PSA_PROXY_PORT"))

psa_user <- Sys.getenv("PSA_API_USERNAME")
psa_pass <- Sys.getenv("PSA_API_PROD_PASSWORD")

api_name      <- "Datamart_CITZ_Report_SHR010HRORG"
api_url       <- paste0(api_base_url, api_name)
staging_table <- "dbo.Stg_Peoplesoft_SHR010HRORG"
target_table  <- "dbo.Peoplesoft_SHR010HRORG"
dropped_table <- "dbo.Stg_Peoplesoft_SHR010HRORG_Dropped"

# --- Validate required variables ---------------------------------------------

config_vars <- c("PSA_API_BASE_URL", "PSA_SQL_SERVER", "PSA_SQL_DATABASE", "PSA_PROXY_HOST")
credential_vars <- c("PSA_API_USERNAME", "PSA_API_PROD_PASSWORD")

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
# Some nullable fields return {} (empty object) when no value is present.
# Affected columns: FutureReturnDate, LayoffLeaveStopPayReason,
# LayoffLeaveStopPayStartDate

normalize_cell <- function(x) {
  if (is.list(x) && length(x) == 0) return(NA)
  x
}

# --- Helper: fetch a single page from the API (GET method) -------------------

fetch_page <- function(url) {
  req <- request(url) |>
    req_auth_basic(psa_user, psa_pass) |>
    req_headers(Accept = "application/json") |>
    req_timeout(120) |>
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

cat("Rows fetched from API:", nrow(df), "\n")

# --- Rename JSON field names to SQL PascalCase column names ------------------
# IMPORTANT: use any_of() so the rename is defensive against API schema drift.
# See staging DDL (01_stage.sql) for the authoritative JSON -> SQL name mapping.
# Note: "Core_Government_" has a trailing underscore in the JSON key.

json_to_sql <- c(
  # Business key
  EmplId                      = "emplid",
  # Employee identity
  Name                        = "name",
  Idir                        = "IDIR",
  EmailId                     = "EMAILID",
  EmplStatus                  = "empl_status",
  EmplType                    = "empl_type",
  EmplCtg                     = "empl_ctg",
  EmplCtgL1                   = "empl_ctg_l1",
  EmplRcd                     = "empl_rcd",
  ApptStatus                  = "Appt_Status",
  ApptStatusCode              = "Appt_Status_Code",
  # Dates
  Birthdate                   = "BIRTHDATE",
  HireDt                      = "HIRE_DT",
  LastHireDt                  = "LAST_HIRE_DT",
  MostHistoricDate            = "Most_Historic_Date",
  FirstDateInOrganization     = "First_Date_In_Organization",
  FirstDateInPosition         = "First_Date_in_Position",
  FutureReturnDate            = "Future_Return_Date",
  # Position / job
  PositionNbr                 = "position_nbr",
  TgbBasePosition             = "tgb_base_position",
  PositionDataDescr           = "PositionData_DESCR",
  JobCode                     = "jobcode",
  JobCodeDescr                = "Jobcode_DESCR",
  JobFunction                 = "job_function",
  SalAdminPlan                = "sal_admin_plan",
  Grade                       = "grade",
  Step                        = "step",
  StdHours                    = "std_hours",
  # Compensation
  AnnualRt                    = "ANNUAL_RT",
  CompRate                    = "COMPRATE",
  HourlyRt                    = "HOURLY_RT",
  # Organization
  Organization                = "Organization",
  BusinessUnit                = "business_unit",
  DeptId                      = "deptid",
  DeptDescr                   = "DEPT_DESCR",
  Level1                      = "Level1",
  Level2                      = "Level2",
  Level3                      = "Level3",
  Descr                       = "descr",
  Core                        = "core",
  CoreGovernment              = "Core_Government_",    # NOTE: trailing underscore in JSON key
  Sector                      = "Sector",
  PublicService               = "Public_Service",
  PublicServiceAct            = "Public_Service_Act",
  TreasuryBoard               = "Treasury_Board",
  OfficerCode                 = "OFFICER_CODE",
  NocCode                     = "NOC_Code",
  NocCodeDescr                = "NOC_Code_Descr",
  ReportsTo                   = "reports_to",
  # Location
  Location                    = "location",
  LocationCity                = "Location_City",
  # Demographics
  AgeGroup1                   = "Age_Group_1",
  AgeGroup2                   = "Age_Group_2",
  Age                         = "Age",
  Generation                  = "Generation",
  EligibleForPension          = "Eligible_for_Pension",
  EligibleForUnreducedPension = "Eligible_for_Unreduced_Pension",
  # Supervisor
  Supervisor                  = "SUPERVISOR",
  SupervEmail                 = "SUPERV_EMAIL",
  SupervSalPlan               = "SUPERV_SAL_PLAN",
  SupervisorStatus            = "Supervisor_Status",
  # Leave / layoff
  LayoffLeaveStopPayReason    = "Layoff_Leave_Stop_Pay_Reason",
  LayoffLeaveStopPayStartDate = "Layoff_Leave_Stop_Pay_Start_Date",
  # Report metadata (staging only — excluded from target/audit/HASHBYTES)
  AsOfDate                    = "As_of_Date"
)

df <- df |> dplyr::rename(any_of(json_to_sql))

# --- Validate expected columns -----------------------------------------------

expected <- c(
  # Business key
  "EmplId",
  # Employee identity
  "Name", "Idir", "EmailId", "EmplStatus", "EmplType",
  "EmplCtg", "EmplCtgL1", "EmplRcd", "ApptStatus", "ApptStatusCode",
  # Dates
  "Birthdate", "HireDt", "LastHireDt", "MostHistoricDate",
  "FirstDateInOrganization", "FirstDateInPosition", "FutureReturnDate",
  # Position / job
  "PositionNbr", "TgbBasePosition", "PositionDataDescr",
  "JobCode", "JobCodeDescr", "JobFunction",
  "SalAdminPlan", "Grade", "Step", "StdHours",
  # Compensation
  "AnnualRt", "CompRate", "HourlyRt",
  # Organization
  "Organization", "BusinessUnit", "DeptId", "DeptDescr",
  "Level1", "Level2", "Level3", "Descr", "Core", "CoreGovernment",
  "Sector", "PublicService", "PublicServiceAct", "TreasuryBoard",
  "OfficerCode", "NocCode", "NocCodeDescr", "ReportsTo",
  # Location
  "Location", "LocationCity",
  # Demographics
  "AgeGroup1", "AgeGroup2", "Age", "Generation",
  "EligibleForPension", "EligibleForUnreducedPension",
  # Supervisor
  "Supervisor", "SupervEmail", "SupervSalPlan", "SupervisorStatus",
  # Leave / layoff
  "LayoffLeaveStopPayReason", "LayoffLeaveStopPayStartDate",
  # Report metadata (staging only)
  "AsOfDate"
)

# Hard-stop only if the business key is missing — that is unrecoverable.
if (!"EmplId" %in% names(df)) {
  stop("Business key column EmplId is missing from the API response.")
}

# Backfill any other expected columns absent from the API response.
# bind_rows() silently drops columns where every row returned {} (empty object).
missing_cols <- setdiff(expected, names(df))
if (length(missing_cols) > 0) {
  warning(paste(
    "Columns absent from API response (all rows were {} — backfilled as NA):",
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
# DATE columns use as.Date(as.character()) to handle API ISO-format strings.
# DECIMAL columns use as.numeric() — do NOT cast to character (SQL type is DECIMAL).
# INT columns use as.integer().
# All other columns are character.

char_cols <- intersect(
  c("EmplId",
    "Name", "Idir", "EmailId", "EmplStatus", "EmplType",
    "EmplCtg", "EmplCtgL1", "ApptStatus", "ApptStatusCode",
    "PositionNbr", "TgbBasePosition", "PositionDataDescr",
    "JobCode", "JobCodeDescr", "JobFunction",
    "SalAdminPlan", "Grade",
    "Organization", "BusinessUnit", "DeptId", "DeptDescr",
    "Level1", "Level2", "Level3", "Descr", "Core", "CoreGovernment",
    "Sector", "PublicService", "PublicServiceAct", "TreasuryBoard",
    "OfficerCode", "NocCode", "NocCodeDescr", "ReportsTo",
    "Location", "LocationCity",
    "AgeGroup1", "AgeGroup2", "Generation",
    "EligibleForPension", "EligibleForUnreducedPension",
    "Supervisor", "SupervEmail", "SupervSalPlan", "SupervisorStatus",
    "LayoffLeaveStopPayReason"),
  names(df)
)

int_cols <- intersect(
  c("EmplRcd", "Step"),
  names(df)
)

dec_cols <- intersect(
  c("Age", "AnnualRt", "CompRate", "HourlyRt", "StdHours"),
  names(df)
)

# Date columns: ISO 8601 strings from the API -> R Date -> SQL DATE
date_cols <- intersect(
  c("Birthdate", "HireDt", "LastHireDt", "MostHistoricDate",
    "FirstDateInOrganization", "FirstDateInPosition", "FutureReturnDate",
    "LayoffLeaveStopPayStartDate", "AsOfDate"),
  names(df)
)

df <- df |>
  dplyr::mutate(
    dplyr::across(all_of(char_cols), as.character),
    dplyr::across(all_of(int_cols),  ~ suppressWarnings(as.integer(.x))),
    dplyr::across(all_of(dec_cols),  ~ suppressWarnings(as.numeric(.x))),
    dplyr::across(all_of(date_cols), ~ suppressWarnings(as.Date(as.character(.x))))
  )

# Select only staging columns in schema order
df <- df[, expected]

cat("Rows after type alignment:", nrow(df), "\n")

# --- Capture and drop rows with NULL/blank EmplId ----------------------------
# EmplId = NULL/blank is a data anomaly that cannot be keyed in the MERGE.
# Precautionary check: not observed in production data (key_analysis: 0 nulls).

null_key_mask <- is.na(df$EmplId) | df$EmplId == ""
dropped_df    <- df[null_key_mask, ]
dropped_df$DropReason <- "NULL_EMPLID"

if (nrow(dropped_df) > 0) {
  warning(paste(
    nrow(dropped_df),
    "row(s) with NULL/blank EmplId captured for quality log and removed from pipeline."
  ))
  df <- df[!null_key_mask, ]
}

# --- No deduplication needed -------------------------------------------------
# key_analysis confirmed: EmplId is 100% unique (distinct=2764, total=2764).
# Unlike SO001HRORG, no composite key and no PeopleSoft reporting artifact dups.

cat("Rows to stage:", nrow(df), "\n")

# --- Connect to SQL Server ---------------------------------------------------

con <- dbConnect(
  odbc(),
  Driver   = "ODBC Driver 17 for SQL Server",
  Server   = sql_server,
  Database = sql_database,
  Trusted_Connection = "Yes"
)

dbBegin(con)

tryCatch({

  # --- TRUNCATE staging table ------------------------------------------------
  dbExecute(con, paste0("TRUNCATE TABLE ", staging_table))
  cat("Staging table truncated.\n")

  # --- Load to staging -------------------------------------------------------
  dbWriteTable(
    conn      = con,
    name      = DBI::Id(schema = "dbo", table = "Stg_Peoplesoft_SHR010HRORG"),
    value     = df,
    append    = TRUE,
    row.names = FALSE
  )
  cat("Rows loaded to staging:", nrow(df), "\n")

  dbCommit(con)
  cat("Staging load committed.\n")

}, error = function(e) {
  dbRollback(con)
  stop(paste("Staging load failed and rolled back:", conditionMessage(e)))
})

# --- Persist dropped records (best-effort; does NOT abort main pipeline) -----
# Append-only: do NOT truncate between runs — historical records are required
# for trend analysis (hc__dropped_records_trend.sql).

if (nrow(dropped_df) > 0) {
  tryCatch({
    dbWriteTable(
      conn      = con,
      name      = DBI::Id(schema = "dbo", table = "Stg_Peoplesoft_SHR010HRORG_Dropped"),
      value     = dropped_df,
      append    = TRUE,
      row.names = FALSE
    )
    cat("Dropped rows written to quality log:", nrow(dropped_df), "\n")
  }, error = function(e) {
    warning(paste("Failed to write dropped records (non-fatal):", conditionMessage(e)))
  })
} else {
  cat("No dropped records this run.\n")
}

# --- Execute MERGE stored procedure ------------------------------------------

cat("Executing MERGE procedure...\n")

merge_result <- dbGetQuery(
  con,
  "EXEC dbo.usp_Merge_PeopleSoft_SHR010HRORG"
)

cat("MERGE complete.\n")
if (nrow(merge_result) > 0) {
  print(merge_result)
}

# --- Disconnect --------------------------------------------------------------

dbDisconnect(con)
cat("Database connection closed.\n")

# --- Final summary -----------------------------------------------------------

cat("\n===================================================\n")
cat("SHR010HRORG ETL complete\n")
cat("API rows fetched  :", nrow(df) + nrow(dropped_df), "\n")
cat("Rows staged       :", nrow(df), "\n")
cat("Dropped (quality) :", nrow(dropped_df), "\n")
cat("Timestamp         :", format(Sys.time()), "\n")
cat("===================================================\n")
