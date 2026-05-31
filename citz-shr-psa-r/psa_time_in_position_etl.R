# Copyright 2024 Province of British Columbia
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

# =============================================================================
# psa_time_in_position_etl.R
# ETL script: Datamart_CITZ_Report_TimeInPositionEmployee
# API method: GET (paginated)
# Business key: EmployeeId + Position + EntryDate + EntrySeq
# Target table: dbo.Peoplesoft_TIP
# =============================================================================

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
  library(dplyr)
  library(purrr)
  library(DBI)
  library(odbc)
})

# -----------------------------------------------------------------------------
# Configuration (no credentials or server names stored here)
# -----------------------------------------------------------------------------
api_url    <- Sys.getenv("PSA_API_TIP_URL")
api_token  <- Sys.getenv("PSA_API_TOKEN")
db_dsn     <- Sys.getenv("PSA_DB_DSN")

stopifnot(
  nchar(api_url)   > 0,
  nchar(api_token) > 0,
  nchar(db_dsn)    > 0
)

# -----------------------------------------------------------------------------
# Helper: normalise a single cell value
# {} (empty list/object from JSON) -> NA_character_
# -----------------------------------------------------------------------------
normalize_cell <- function(x) {
  if (is.list(x) && length(x) == 0) return(NA_character_)
  if (is.null(x))                    return(NA_character_)
  as.character(x)
}

# -----------------------------------------------------------------------------
# Paginated fetch
# -----------------------------------------------------------------------------
fetch_all_pages <- function(url, token) {
  records <- list()
  next_url <- url

  repeat {
    req <- request(next_url) |>
      req_headers(Authorization = paste("Bearer", token),
                  Accept        = "application/json")

    resp <- req_perform(req)

    if (resp_status(resp) != 200) {
      stop(sprintf("API returned HTTP %d for URL: %s", resp_status(resp), next_url))
    }

    body <- resp_body_json(resp, simplifyVector = FALSE)
    page_records <- body[["value"]]

    if (!is.null(page_records) && length(page_records) > 0) {
      records <- c(records, page_records)
    }

    # Check for next page (both OData 4 and OData 3 link names)
    next_link <- body[["@odata.nextLink"]] %||% body[["odata.nextLink"]]
    if (is.null(next_link) || nchar(next_link) == 0) break

    next_url <- next_link
    Sys.sleep(0.2)
  }

  records
}

message(sprintf("[%s] Fetching TimeInPositionEmployee from API...", Sys.time()))
raw_records <- fetch_all_pages(api_url, api_token)
message(sprintf("[%s] Fetched %d raw records.", Sys.time(), length(raw_records)))

# -----------------------------------------------------------------------------
# Normalise to data frame
# -----------------------------------------------------------------------------
df_raw <- purrr::map(raw_records, function(rec) {
  purrr::map(rec, normalize_cell) |> as.data.frame(stringsAsFactors = FALSE)
}) |> dplyr::bind_rows()

message(sprintf("[%s] Normalised to %d rows x %d columns.", Sys.time(), nrow(df_raw), ncol(df_raw)))

# -----------------------------------------------------------------------------
# Rename JSON keys to SQL column names
# NOTE: "core" is lowercase in the JSON payload — must be listed exactly.
# -----------------------------------------------------------------------------
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
  PositionCurrentClassificationGroup = "Position_Current_ClassificationGroup",
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
  Core                                = "core"        # lowercase in JSON
)

df <- df_raw |> dplyr::rename(dplyr::any_of(json_to_sql))

# Backfill any columns missing from this API response
all_sql_cols <- names(json_to_sql)
missing_cols <- setdiff(all_sql_cols, names(df))
if (length(missing_cols) > 0) {
  message(sprintf("[%s] Backfilling %d missing column(s): %s",
                  Sys.time(), length(missing_cols), paste(missing_cols, collapse = ", ")))
  df[missing_cols] <- NA_character_
}
df <- df[all_sql_cols]

# -----------------------------------------------------------------------------
# Type alignment
# -----------------------------------------------------------------------------
char_cols <- c(
  "EmployeeId", "Position",
  "EmployeeName",
  "EntryAction", "EntryReason", "EntryReasonDescr",
  "ExitAction", "ExitReason", "ExitReasonDescr",
  "ClassificationGroupAtEntry", "JobCodeAtEntry", "JobCodeDescAtEntry", "JobCodeDescGroupAtEntry",
  "CurrentApptStat", "CurrentBase", "CurrentDeptDescr", "CurrentDeptId",
  "CurrentJobFunction", "CurrentJobcode", "CurrentJobcodeDescr",
  "CurrentOrHistorical", "CurrentOrganization", "CurrentPosition",
  "CurrentProgram", "CurrentProgramBranch", "CurrentProgramDivision", "CurrentStatus",
  "PositionCurrentClassificationGroup", "PositionCurrentJobCode",
  "PositionCurrentJobCodeDesc", "PositionCurrentJobCodeDescGroup", "PositionTitle",
  "Department", "DeptId", "Organization", "Level1", "Level2", "Level3", "Core"
)

int_cols <- c(
  "EmployeeRcd", "EntryRownumber", "EntrySeq", "EntryStdHours",
  "ExitSeq", "ExitStdHours",
  "DaysInPosition", "IncumbentCountAfterEntry"
)

dec_cols <- c(
  "YearsInPosition", "AccumulatedYearsInPositions", "AgeAtEntry", "AgeAtExit"
)

date_cols <- c(
  "Birthdate", "EntryDate", "ExitDate", "FirstDateInPosition"
)

df <- df |>
  dplyr::mutate(
    dplyr::across(dplyr::all_of(char_cols), as.character),
    dplyr::across(dplyr::all_of(int_cols),  as.integer),
    dplyr::across(dplyr::all_of(dec_cols),  as.numeric),
    dplyr::across(dplyr::all_of(date_cols), ~ as.Date(as.character(.)))
  )

# Normalise EmployeeId: blank -> NA
df <- df |>
  dplyr::mutate(EmployeeId = dplyr::if_else(
    is.na(EmployeeId) | trimws(EmployeeId) == "", NA_character_, EmployeeId))

# -----------------------------------------------------------------------------
# Connect to database
# -----------------------------------------------------------------------------
con <- DBI::dbConnect(odbc::odbc(), dsn = db_dsn)
on.exit(DBI::dbDisconnect(con), add = TRUE)

# -----------------------------------------------------------------------------
# Capture NULL_EMPLOYEEID drops
# -----------------------------------------------------------------------------
null_key_rows <- df |> dplyr::filter(is.na(EmployeeId))

if (nrow(null_key_rows) > 0) {
  message(sprintf("[%s] Dropping %d row(s) with NULL EmployeeId.", Sys.time(), nrow(null_key_rows)))
  dropped_null <- null_key_rows |>
    dplyr::mutate(DropReason = "NULL_EMPLOYEEID",
                  LoadDtmUtc = as.character(Sys.time()))

  tryCatch(
    DBI::dbWriteTable(con, DBI::Id(schema = "dbo", table = "Stg_Peoplesoft_TIP_Dropped"),
                      dropped_null, append = TRUE, row.names = FALSE),
    error = function(e) warning(sprintf("Failed to write NULL_EMPLOYEEID dropped rows: %s", e$message))
  )
}

df <- df |> dplyr::filter(!is.na(EmployeeId))

# -----------------------------------------------------------------------------
# Deduplication on business key (keep last row per group)
# -----------------------------------------------------------------------------
key_cols <- c("EmployeeId", "Position", "EntryDate", "EntrySeq")

n_before <- nrow(df)

df <- df |>
  dplyr::group_by(dplyr::across(dplyr::all_of(key_cols))) |>
  dplyr::mutate(.row_n = dplyr::row_number()) |>
  dplyr::ungroup()

dup_rows <- df |> dplyr::filter(.row_n > 1) |> dplyr::select(-.row_n)

if (nrow(dup_rows) > 0) {
  message(sprintf("[%s] Dropping %d duplicate key row(s).", Sys.time(), nrow(dup_rows)))
  dropped_dup <- dup_rows |>
    dplyr::mutate(DropReason = "DUPLICATE_COMPOSITE_KEY",
                  LoadDtmUtc = as.character(Sys.time()))

  tryCatch(
    DBI::dbWriteTable(con, DBI::Id(schema = "dbo", table = "Stg_Peoplesoft_TIP_Dropped"),
                      dropped_dup, append = TRUE, row.names = FALSE),
    error = function(e) warning(sprintf("Failed to write DUPLICATE_COMPOSITE_KEY dropped rows: %s", e$message))
  )
}

df <- df |> dplyr::filter(.row_n == 1) |> dplyr::select(-.row_n)
n_after <- nrow(df)

message(sprintf("[%s] Rows after dedup: %d (removed %d duplicates).",
                Sys.time(), n_after, n_before - n_after))

# -----------------------------------------------------------------------------
# Sanity check: business key must be unique
# -----------------------------------------------------------------------------
n_unique_key <- df |>
  dplyr::distinct(dplyr::across(dplyr::all_of(key_cols))) |>
  nrow()

if (n_unique_key != nrow(df)) {
  stop(sprintf(
    "Business key is not unique after dedup! Rows: %d, Distinct keys: %d. ETL aborted.",
    nrow(df), n_unique_key
  ))
}

message(sprintf("[%s] Sanity check passed: %d rows, %d unique keys.",
                Sys.time(), nrow(df), n_unique_key))

# -----------------------------------------------------------------------------
# Load to staging
# -----------------------------------------------------------------------------
message(sprintf("[%s] Truncating staging table...", Sys.time()))
DBI::dbExecute(con, "TRUNCATE TABLE dbo.Stg_Peoplesoft_TIP")

message(sprintf("[%s] Writing %d rows to dbo.Stg_Peoplesoft_TIP...", Sys.time(), nrow(df)))
DBI::dbWriteTable(con, DBI::Id(schema = "dbo", table = "Stg_Peoplesoft_TIP"),
                  df, append = TRUE, row.names = FALSE)

# -----------------------------------------------------------------------------
# Execute MERGE
# -----------------------------------------------------------------------------
message(sprintf("[%s] Executing MERGE procedure...", Sys.time()))
DBI::dbGetQuery(con, "EXEC dbo.usp_Merge_PeopleSoft_TIP")

message(sprintf("[%s] ETL complete for TimeInPositionEmployee.", Sys.time()))
