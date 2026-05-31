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
# Dataset: SO001HRORG (Employees and Positions / HR Org Structure)
#
# This script:
#   1. Calls the PeopleSoft Analytics API (OData, Basic Auth, POST method)
#   2. Normalizes JSON (handles empty objects {} -> NA)
#   3. Renames JSON fields (snake_case / spaced names) to SQL PascalCase column names
#   4. Loads into a SQL Server staging table (TRUNCATE + INSERT)
#   5. Executes a MERGE stored procedure (staging -> target + audit)
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
api_name <- "Datamart_CITZ_Report_usp_SO001HRORG"

# Full API URL (base + API name)
api_url <- paste0(api_base_url, api_name)

# Table names
staging_table <- "dbo.Stg_Peoplesoft_SO001HRORG"
target_table  <- "dbo.Peoplesoft_SO001HRORG"

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

# --- Helper: fetch a single page from the API (POST method) ------------------

fetch_page <- function(url) {
  req <- request(url) |>
    req_method("POST") |>
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
# JSON fields with spaces or snake_case are mapped to PascalCase SQL names.
# "report name", "sub title", "run date" are per-run metadata; stored in
# staging only and excluded from the target/audit tables.
#
# IMPORTANT: use any_of() so the rename is defensive against API schema drift.
# dplyr::rename() throws a hard error if a named column is absent; any_of()
# silently skips missing columns. This matters because fields that are always
# NULL / empty-object ({}) can be dropped by bind_rows() in some dplyr versions,
# and live API responses may omit fields that appear in the schema sample.
# Field names are sourced from the schema JSON (value[0] keys).

json_to_sql <- c(
  Organization        = "organization",
  Level1              = "level1",
  Level2              = "level2",
  Level3              = "level3",
  PosBusinessUnit     = "pos_business_unit",
  PosBU               = "pos_bu",
  PosDepartment       = "pos_department",
  PosDeptId           = "pos_deptid",
  PosPosition         = "pos_position",
  Title               = "title",
  PosRole             = "pos role",
  PosJobCode          = "pos_jobcode",
  PosClassification   = "pos_classification",
  SupervisorPos       = "supervisor_pos",
  SupervisorName      = "supervisor_name",
  Direct              = "direct",
  Indirect            = "indirect",
  City                = "city",
  Status              = "status",
  RT                  = "rt",
  FP                  = "fp",
  Budgetted           = "budgetted",
  Empty               = "empty",
  Vacant              = "vacant",
  TrueVacancy         = "true_vacancy",
  Future              = "future",
  LastFilled          = "last_filled",
  LastFilledB         = "last_filled_b",
  LastFilledBase      = "last_filled_base",
  EmplBU              = "empl_bu",
  EmplDeptId          = "empl_deptid",
  JobRole             = "job role",
  EmplJobCode         = "empl_jobcode",
  EmplClassification  = "empl_classification",
  Grade               = "grade",
  Step                = "step",
  SalaryType          = "salary_type",
  Type                = "type",
  StandardHours       = "standard_hours",
  Base                = "base",
  Name                = "name",
  EmplId              = "emplid",
  EmplStatus          = "empl_status",
  Appt                = "appt",
  Age                 = "age",
  PosClassMax         = "posclass_max",
  JobClassMax         = "jobclass_max",
  Annual              = "annual",
  Abbr                = "abbr",
  AdminPlan           = "admin_plan",
  AMA                 = "ama",
  AMALimit            = "ama_limit",
  CAD                 = "cad",
  CADLimit            = "cad_limit",
  SPP                 = "spp",
  SPPLimit            = "spp_limit",
  TAJ                 = "taj",
  TAJLimit            = "taj_limit",
  FutureTermDate      = "future_term_date",
  FutureTermReason    = "future_term_reason",
  TAStatus            = "ta_status",
  TAStartDate         = "ta_start_date",
  TAReturnDate        = "ta_return_date",
  TAReturnTo          = "ta_return_to",
  TAReturnBU          = "ta_return_bu",
  TAReturnDeptId      = "ta_return_deptid",
  TAReturnJobCode     = "ta_return_jobcode",
  TAReturnGrade       = "ta_return_grade",
  TAReturnPosition    = "ta_return_position",
  TAReturnSupervisor  = "ta_return_supervisor",
  TAReturnAbbr        = "ta_return_abbr",
  LeaveReason         = "leave_reason",
  LeaveStart          = "leave_start",
  LeaveReturn         = "leave_return",
  Q                   = "q",
  MaildropCity        = "maildrop city",
  ReportName          = "report name",
  SubTitle            = "sub title",
  RunDate             = "run date"
)

df <- df |> dplyr::rename(any_of(json_to_sql))

# --- Validate expected columns -----------------------------------------------

expected <- c(
  "PosPosition",
  "Organization", "Level1", "Level2", "Level3",
  "PosBusinessUnit", "PosBU", "PosDepartment", "PosDeptId",
  "Title", "PosRole", "PosJobCode", "PosClassification",
  "SupervisorPos", "SupervisorName",
  "Direct", "Indirect",
  "City", "Status", "RT", "FP", "Budgetted", "Empty", "Vacant",
  "TrueVacancy", "Future", "LastFilled", "LastFilledB", "LastFilledBase",
  "EmplBU", "EmplDeptId", "JobRole", "EmplJobCode", "EmplClassification",
  "Grade", "Step", "SalaryType", "Type", "StandardHours", "Base",
  "Name", "EmplId", "EmplStatus", "Appt", "Age",
  "PosClassMax", "JobClassMax", "Annual", "Abbr", "AdminPlan",
  "AMA", "AMALimit", "CAD", "CADLimit", "SPP", "SPPLimit",
  "TAJ", "TAJLimit", "FutureTermDate", "FutureTermReason",
  "TAStatus", "TAStartDate", "TAReturnDate", "TAReturnTo",
  "TAReturnBU", "TAReturnDeptId", "TAReturnJobCode", "TAReturnGrade",
  "TAReturnPosition", "TAReturnSupervisor", "TAReturnAbbr",
  "LeaveReason", "LeaveStart", "LeaveReturn",
  "Q", "MaildropCity",
  "ReportName", "SubTitle", "RunDate"
)

# Hard-stop only if the business key is missing — that is unrecoverable.
if (!"PosPosition" %in% names(df)) {
  stop("Business key column PosPosition is missing from the API response.")
}

# Backfill any other expected columns absent from the API response.
# bind_rows() silently drops columns where every row returned {} (empty object),
# so those fields never land in df. We still need them in staging as NA.
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

char_cols <- intersect(
  c("PosPosition",
    "Organization", "Level1", "Level2", "Level3",
    "PosBusinessUnit", "PosBU", "PosDepartment", "PosDeptId",
    "Title", "PosRole", "PosJobCode", "PosClassification",
    "SupervisorPos", "SupervisorName",
    "City", "Status", "RT", "FP", "Budgetted", "Empty", "Vacant",
    "TrueVacancy", "Future", "LastFilled", "LastFilledB", "LastFilledBase",
    "EmplBU", "EmplDeptId", "JobRole", "EmplJobCode", "EmplClassification",
    "Grade", "Step", "SalaryType", "Type", "StandardHours", "Base",
    "Name", "EmplId", "EmplStatus", "Appt",
    "PosClassMax", "JobClassMax", "Annual", "Abbr", "AdminPlan",
    "AMA", "AMALimit", "CAD", "CADLimit", "SPP", "SPPLimit",
    "TAJ", "TAJLimit", "FutureTermDate", "FutureTermReason",
    "TAStatus", "TAStartDate", "TAReturnDate", "TAReturnTo",
    "TAReturnBU", "TAReturnDeptId", "TAReturnJobCode", "TAReturnGrade",
    "TAReturnPosition", "TAReturnSupervisor", "TAReturnAbbr",
    "LeaveReason", "LeaveStart", "LeaveReturn",
    "Q", "MaildropCity",
    "ReportName", "SubTitle", "RunDate"),
  names(df)
)

int_cols <- intersect(
  c("Direct", "Indirect", "Age"),
  names(df)
)

df <- df |>
  dplyr::mutate(
    dplyr::across(all_of(char_cols), as.character),
    dplyr::across(all_of(int_cols), ~ suppressWarnings(as.integer(.x)))
  )

# Select only staging columns in schema order
df <- df[, expected]

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
  name      = Id(schema = "dbo", table = "Stg_Peoplesoft_SO001HRORG"),
  value     = df,
  append    = TRUE,
  row.names = FALSE
)

stg_cnt <- dbGetQuery(con, paste0("SELECT COUNT(*) AS StagingRows FROM ", staging_table, ";"))

dbCommit(con)

# --- Execute MERGE stored procedure (staging -> target + audit) ---------------

dbExecute(con, "EXEC dbo.usp_Merge_PeopleSoft_SO001HRORG")

dbDisconnect(con)

# --- Summary ------------------------------------------------------------------

cat("===================================================\n")
cat("PSA SO001HRORG ETL completed\n")
cat("Environment:", api_env, "\n")
cat("Config file:", env_file, "\n")
cat("API Name:", api_name, "\n")
cat("Staging rows loaded:", stg_cnt$StagingRows, "\n")
cat("Completed at:", format(Sys.time()), "\n")
cat("===================================================\n")
