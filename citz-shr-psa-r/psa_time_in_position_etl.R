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
# Dataset: Datamart_CITZ_Report_TimeInPositionEmployee (TIP)
# HTTP method: GET (paginated via @odata.nextLink)
# Business key: EmployeeId + Position + EntryDate + EntrySeq
# Dedup: YES -- deduplicate on the business key before load;
#        keep last row; dropped rows written to Dropped table
# Notes:
#   - JSON key "core" is lowercase (must be mapped exactly)
#   - ~2,764 rows have NULL ExitDate -- employees still in current position
#     (expected, not a data quality issue)
#
# Configuration:
#   - API credentials: PSA_API_USERNAME, PSA_API_PROD_PASSWORD (System Env Vars)
#   - All other config: .Renviron.prod or .Renviron.test
# ============================================================================

library(httr2)
library(jsonlite)
library(DBI)
library(odbc)
library(dplyr)
library(tibble)

# --- Load env config based on PSA_API_ENV (TEST or PROD, default PROD) -------

api_env <- toupper(Sys.getenv("PSA_API_ENV", unset = "PROD"))
env_file <- switch(api_env,
  "TEST" = ".Renviron.test",
  "PROD" = ".Renviron.prod",
  stop("PSA_API_ENV must be TEST or PROD; got: ", api_env)
)
if (!file.exists(env_file)) {
  stop("Env file not found: ", env_file)
}
readRenviron(env_file)

# --- Configuration (from .Renviron) ------------------------------------------

api_base_url <- Sys.getenv("PSA_API_BASE_URL")
sql_server   <- Sys.getenv("PSA_SQL_SERVER")
sql_database <- Sys.getenv("PSA_SQL_DATABASE")
proxy_host   <- Sys.getenv("PSA_PROXY_HOST")
proxy_port   <- as.integer(Sys.getenv("PSA_PROXY_PORT"))

# Credentials (from system env vars, NOT .Renviron)
psa_user <- Sys.getenv("PSA_API_USERNAME")
psa_pass <- Sys.getenv("PSA_API_PROD_PASSWORD")

api_name <- "Datamart_CITZ_Report_TimeInPositionEmployee"

# Full API URL (base + API name)
api_url <- paste0(api_base_url, api_name)

# Table names
staging_table <- "dbo.Stg_Peoplesoft_TIP"
dropped_table <- "dbo.Stg_Peoplesoft_TIP_Dropped"

# --- Validate required variables ---------------------------------------------

config_vars <- c(
  "PSA_API_BASE_URL",
  "PSA_SQL_SERVER",
  "PSA_SQL_DATABASE",
  "PSA_PROXY_HOST"
)

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
cat("PSA TIP ETL starting\n")
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
    req_method("GET") |>
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

cat("Raw rows fetched:", nrow(df), "\n")

# --- Rename JSON field names to SQL PascalCase column names ------------------
# NOTE: "core" is lowercase in the JSON payload -- must be listed exactly.

json_to_sql <- c(
  EmployeeId                          = "EmployeeID",
  Position                            = "Position",
  EntryDate                           = "Entry_Date",
  EntrySeq                            = "Entry_Seq",
  EmployeeName                        = "Employee_Name",
  EmployeeRcd                         = "Employee_Rcd",
  Birthdate                           = "Birthdate",
  EntryAction                         = "Entry_Action",
  EntryReason                         = "Entry_Reason",
  EntryReasonDescr                    = "Entry_Reason_Descr",
  EntryRownumber                      = "Entry_Rownumber",
  EntryStdHours                       = "Entry_Std_Hours",
  FirstDateInPosition                 = "First_Date_In_Position",
  IncumbentCountAfterEntry            = "Incumbent_Count_After_Entry",
  ExitAction                          = "Exit_Action",
  ExitDate                            = "Exit_Date",
  ExitReason                          = "Exit_Reason",
  ExitReasonDescr                     = "Exit_Reason_Descr",
  ExitSeq                             = "Exit_Seq",
  ExitStdHours                        = "Exit_Std_Hours",
  DaysInPosition                      = "Days_in_Position",
  YearsInPosition                     = "Years_in_Position",
  AccumulatedYearsInPositions         = "Accumulated_Years_in_Positions",
  AgeAtEntry                          = "Age_at_Entry",
  AgeAtExit                           = "Age_at_Exit",
  ClassificationGroupAtEntry          = "ClassificationGroup_at_Entry",
  JobCodeAtEntry                      = "Job_Code_at_Entry",
  JobCodeDescAtEntry                  = "JobCodeDesc_at_Entry",
  JobCodeDescGroupAtEntry             = "JobCodeDescGroup_at_Entry",
  CurrentApptStat                     = "Current_Appt_Stat",
  CurrentBase                         = "Current_Base",
  CurrentDeptDescr                    = "Current_Dept_Descr",
  CurrentDeptId                       = "Current_DeptID",
  CurrentJobFunction                  = "Current_Job_Function",
  CurrentJobcode                      = "Current_Jobcode",
  CurrentJobcodeDescr                 = "Current_Jobcode_Descr",
  CurrentOrHistorical                 = "Current_or_Historical",
  CurrentOrganization                 = "Current_Organization",
  CurrentPosition                     = "Current_Position",
  CurrentProgram                      = "Current_Program",
  CurrentProgramBranch                = "Current_Program_Branch",
  CurrentProgramDivision              = "Current_Program_Division",
  CurrentStatus                       = "Current_Status",
  PositionCurrentClassificationGroup  = "Position_Current_ClassificationGroup",
  PositionCurrentJobCode              = "Position_Current_Job_Code",
  PositionCurrentJobCodeDesc          = "Position_Current_JobCodeDesc",
  PositionCurrentJobCodeDescGroup     = "Position_Current_JobCodeDescGroup",
  PositionTitle                       = "Position_Title",
  Department                          = "Department",
  DeptId                              = "DEPTID",
  Organization                        = "Organization",
  Level1                              = "Level1",
  Level2                              = "Level2",
  Level3                              = "Level3",
  Core                                = "core"
)

df <- df |> dplyr::rename(any_of(json_to_sql))

# --- Validate expected columns -----------------------------------------------

expected <- names(json_to_sql)

# Hard-stop only if any business key column is missing -- unrecoverable.
key_cols <- c("EmployeeId", "Position", "EntryDate", "EntrySeq")
absent_keys <- setdiff(key_cols, names(df))
if (length(absent_keys) > 0) {
  stop(paste(
    "Business key column(s) missing from API response:",
    paste(absent_keys, collapse = ", ")
  ))
}

# Backfill any other expected columns absent from the API response.
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
  c(
    "EmployeeId", "Position",
    "EmployeeName",
    "EntryAction", "EntryReason", "EntryReasonDescr",
    "ExitAction", "ExitReason", "ExitReasonDescr",
    "ClassificationGroupAtEntry", "JobCodeAtEntry", "JobCodeDescAtEntry",
    "JobCodeDescGroupAtEntry",
    "CurrentApptStat", "CurrentBase", "CurrentDeptDescr", "CurrentDeptId",
    "CurrentJobFunction", "CurrentJobcode", "CurrentJobcodeDescr",
    "CurrentOrHistorical", "CurrentOrganization", "CurrentPosition",
    "CurrentProgram", "CurrentProgramBranch", "CurrentProgramDivision",
    "CurrentStatus",
    "PositionCurrentClassificationGroup", "PositionCurrentJobCode",
    "PositionCurrentJobCodeDesc", "PositionCurrentJobCodeDescGroup",
    "PositionTitle",
    "Department", "DeptId", "Organization", "Level1", "Level2", "Level3", "Core"
  ),
  names(df)
)

int_cols <- intersect(
  c(
    "EmployeeRcd", "EntryRownumber", "EntrySeq", "EntryStdHours",
    "ExitSeq", "ExitStdHours",
    "DaysInPosition", "IncumbentCountAfterEntry"
  ),
  names(df)
)

dec_cols <- intersect(
  c(
    "YearsInPosition", "AccumulatedYearsInPositions",
    "AgeAtEntry", "AgeAtExit"
  ),
  names(df)
)

date_cols <- intersect(
  c("Birthdate", "EntryDate", "ExitDate", "FirstDateInPosition"),
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

# Normalize blank EmployeeId to NA so null-key capture catches it
df$EmployeeId <- ifelse(
  is.na(df$EmployeeId) | trimws(df$EmployeeId) == "",
  NA_character_,
  df$EmployeeId
)

# --- Capture and drop rows with NULL EmployeeId ------------------------------
# NULL EmployeeId rows cannot be keyed in the MERGE. Capture them for quality
# tracking BEFORE dropping from the main pipeline.
null_key_mask <- is.na(df$EmployeeId)
null_key_rows <- df[null_key_mask, ]
null_key_rows$DropReason <- "NULL_EMPLOYEEID"

if (nrow(null_key_rows) > 0) {
  warning(paste(
    nrow(null_key_rows),
    "row(s) with NULL EmployeeId captured for quality log and removed from pipeline."
  ))
  df <- df[!null_key_mask, ]
}

# --- Capture duplicate composite key rows before deduplication ---------------
# Business key: EmployeeId + Position + EntryDate + EntrySeq.
# Earlier occurrences of each key are dropped; the last row wins.
composite_key <- paste(df$EmployeeId, df$Position, df$EntryDate, df$EntrySeq, sep = "|")
dup_mask      <- duplicated(composite_key, fromLast = TRUE)  # TRUE = earlier occurrence
dup_rows      <- df[dup_mask, ]
dup_rows$DropReason <- "DUPLICATE_COMPOSITE_KEY"

if (nrow(dup_rows) > 0) {
  warning(paste(
    nrow(dup_rows),
    "duplicate (EmployeeId, Position, EntryDate, EntrySeq) row(s) captured for quality log and removed."
  ))
  df <- df[!dup_mask, ]
}

# --- Sanity check: business key must be unique after dedup -------------------
n_unique_key <- nrow(unique(df[, key_cols]))
if (n_unique_key != nrow(df)) {
  stop(sprintf(
    "Business key still not unique after dedup: %d rows vs %d distinct keys.",
    nrow(df), n_unique_key
  ))
}

# --- Combine all dropped rows for quality persistence ------------------------
dropped_df <- rbind(null_key_rows, dup_rows)
cat("Dropped rows captured for quality log:", nrow(dropped_df),
    "(NULL_EMPLOYEEID:", nrow(null_key_rows),
    "| DUPLICATE_COMPOSITE_KEY:", nrow(dup_rows), ")\n")

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
  name      = Id(schema = "dbo", table = "Stg_Peoplesoft_TIP"),
  value     = df,
  append    = TRUE,
  row.names = FALSE
)

stg_cnt <- dbGetQuery(con, paste0("SELECT COUNT(*) AS StagingRows FROM ", staging_table, ";"))

dbCommit(con)

# --- Persist dropped records to quality tracking table (best-effort) ---------

if (nrow(dropped_df) > 0) {
  tryCatch({
    dbWriteTable(
      con,
      name      = Id(schema = "dbo", table = "Stg_Peoplesoft_TIP_Dropped"),
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

# --- Execute MERGE stored procedure (staging -> target + audit) --------------

dbExecute(con, "EXEC dbo.usp_Merge_PeopleSoft_TIP")

dbDisconnect(con)

# --- Summary -----------------------------------------------------------------

cat("===================================================\n")
cat("PSA TIP ETL completed\n")
cat("Environment:", api_env, "\n")
cat("Config file:", env_file, "\n")
cat("API Name:", api_name, "\n")
cat("Staging rows loaded:", stg_cnt$StagingRows, "\n")
cat("Completed at:", format(Sys.time()), "\n")
cat("===================================================\n")
