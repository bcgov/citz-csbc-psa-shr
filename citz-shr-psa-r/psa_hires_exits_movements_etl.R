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
# Dataset: Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ (HEM)
# HTTP method: GET (paginated via @odata.nextLink)
# Business key: EmplId + EffDt + EffSeq + EmplRcd
#   - No single-column or 2-column natural key found by psa_key_discovery.R
#   - Using PeopleSoft standard JOB row key (4 columns)
# Dedup: YES -- deduplicate on (EmplId, EffDt, EffSeq, EmplRcd) before load;
#        keep last row; dropped rows written to Dropped table
# Notes:
#   - JSON fields "New_Level4" and "Prior_Level4" may return {} (empty object);
#     normalize_cell() converts empty lists to NA
#   - ~1,377 rows have NULL Prior_ columns (new hires, no prior event)
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

# Resolve script location (needed before sourcing bootstrap) -----------------
# bootstrap_env.R and db_connect.R live in the same directory (citz-shr-psa-r/).
# script_dir must be set before sourcing bootstrap_env.R.
args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args[grep("--file=", args)])
if (length(script_path) > 0) {
  script_dir <- dirname(normalizePath(script_path))
} else {
  script_dir <- getwd()
}

source(file.path(script_dir, "bootstrap_env.R"))
source(file.path(script_dir, "db_connect.R"))

# --- API and table configuration ---------------------------------------------

api_name <- "Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ"

# Full API URL (base + API name)
api_url       <- paste0(api_base_url, api_name)
staging_table <- "dbo.Stg_Peoplesoft_HEM"
dropped_table <- "dbo.Stg_Peoplesoft_HEM_Dropped"

cat("===================================================\n")
cat("PSA HEM ETL starting\n")
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

json_to_sql <- c(
  EmplId                        = "EmplID",
  EffDt                         = "EFFDT",
  EffSeq                        = "EFFSEQ",
  EmplRcd                       = "Empl_RCD",
  CompChange                    = "CompChange",
  EstimatedYrsOfService         = "Estimated_Years_of_Service",
  EstimatedYearsOfService       = "EstimatedYearsOfService",
  EstimatedYearsOfServiceStr    = "EstimatedYearsOfServiceString",
  FirstDateOfService            = "First_Date_of_Service",
  FiscalYear                    = "FiscalYear",
  LeaveServiceDt                = "Leave_Service_DT",
  MostHistoricDate              = "Most_Historic_Date",
  MoveType                      = "MoveType",
  MoveType1                     = "MoveType1",
  MoveType1Sort                 = "MoveType1_Sort",
  MoveType2                     = "MoveType2",
  Name                          = "Name",
  SameGroup                     = "SameGroup",
  SameLevel1                    = "SameLevel1",
  SameOrg                       = "SameOrg",
  Seq                           = "SEQ",
  SupervisorMove                = "SupervisorMove",
  NewAction                     = "New_Action",
  NewActionDt                   = "New_Action_DT",
  NewActionReason               = "New_ActionReason",
  NewActionReasonDescr          = "New_ActionReason_Descr",
  NewAnnualRt                   = "New_ANNUAL_RT",
  NewBusinessUnit               = "New_Business_Unit",
  NewBusinessUnitDescr          = "New_Business_Unit_Descr",
  NewCity                       = "New_City",
  NewClassificationGroup        = "New_Classification_Group",
  NewCompRate                   = "New_COMPRATE",
  NewCoreBu                     = "New_CoreBU",
  NewCoreOrg                    = "New_CoreOrg",
  NewDeptId                     = "New_DeptID",
  NewDeptIdDescr                = "New_DeptID_Descr",
  NewDevelopmentRegion          = "New_Development_Region",
  NewEmplCtg                    = "New_Empl_CTG",
  NewEmplCtgDescr               = "New_Empl_CTG_Descr",
  NewEmplStatus                 = "New_Empl_Status",
  NewEmplStatusDescr            = "New_Empl_Status_Descr",
  NewEndOfDayHrStatus           = "New_EndOfDayHR_Status",
  NewEndOfDayPerOrg             = "New_EndOfDayPER_ORG",
  NewEstimatedYearsInOrg        = "New_EstimatedYearsInOrganization",
  NewEstimatedYearsInOrgStr     = "New_EstimatedYearsInOrganizationString",
  NewEstimatedYearsInPos        = "New_EstimatedYearsInPosition",
  NewEstimatedYearsInPosStr     = "New_EstimatedYearsInPositionString",
  NewFirstDateInOrg             = "New_First_Date_in_Organization",
  NewFirstDateInPosition        = "New_First_Date_in_Position",
  NewGrade                      = "New_Grade",
  NewHireDate                   = "New_Hire_Date",
  NewHourlyRt                   = "New_HOURLY_RT",
  NewHrStatus                   = "New_HR_Status",
  NewIncludedOrExcluded         = "New_Included_or_Excluded",
  NewIsSupervisor               = "New_IsSupervisor",
  NewJobFunction                = "New_Job_Function",
  NewJobcode                    = "New_Jobcode",
  NewJobcodeDescr               = "New_Jobcode_Descr",
  NewLevel1                     = "New_Level1",
  NewLevel2                     = "New_Level2",
  NewLevel3                     = "New_Level3",
  NewLevel4                     = "New_Level4",
  NewLifeCycle                  = "New_Life_Cycle",
  NewLocation                   = "New_Location",
  NewLocationGroup              = "New_Location_Group",
  NewMaxRtHourly                = "New_MAX_RT_HOURLY",
  NewOrganization               = "New_Organization",
  NewPerOrg                     = "New_PER_ORG",
  NewPositionDescr              = "New_Position_Descr",
  NewPositionNbr                = "New_Position_NBR",
  NewPsa                        = "New_PSA",
  NewRegionalDistrict           = "New_Regional_District",
  NewRehireDate                 = "New_Rehire_Date",
  NewReportsTo                  = "New_Reports_to",
  NewSalAdminPlan               = "New_Sal_Admin_Plan",
  NewSelectedGroup              = "New_SelectedGroup",
  NewStdHours                   = "New_STD_HOURS",
  NewStep                       = "New_STEP",
  NewSupervisor                 = "New_Supervisor",
  PriorAction                   = "Prior_Action",
  PriorActionDt                 = "Prior_Action_DT",
  PriorActionReason             = "Prior_ActionReason",
  PriorActionReasonDescr        = "Prior_ActionReason_Descr",
  PriorAnnualRt                 = "Prior_ANNUAL_RT",
  PriorBusinessUnit             = "Prior_Business_Unit",
  PriorBusinessUnitDescr        = "Prior_Business_Unit_Descr",
  PriorCity                     = "Prior_City",
  PriorClassificationGroup      = "Prior_Classification_Group",
  PriorCompRate                 = "Prior_COMPRATE",
  PriorCoreBu                   = "Prior_CoreBU",
  PriorCoreOrg                  = "Prior_CoreOrg",
  PriorDeptId                   = "Prior_DeptID",
  PriorDeptIdDescr              = "Prior_DeptID_Descr",
  PriorDevelopmentRegion        = "Prior_Development_Region",
  PriorEffDt                    = "Prior_EFFDT",
  PriorEffSeq                   = "Prior_EFFSEQ",
  PriorEmplCtg                  = "Prior_Empl_CTG",
  PriorEmplCtgDescr             = "Prior_Empl_CTG_Descr",
  PriorEmplStatus               = "Prior_Empl_Status",
  PriorEmplStatusDescr          = "Prior_Empl_Status_Descr",
  PriorEndOfDayHrStatus         = "Prior_EndOfDayHR_Status",
  PriorEndOfDayPerOrg           = "Prior_EndOfDayPER_ORG",
  PriorEstimatedYearsInOrg      = "Prior_EstimatedYearsInOrganization",
  PriorEstimatedYearsInOrgStr   = "Prior_EstimatedYearsInOrganizationString",
  PriorEstimatedYearsInPos      = "Prior_EstimatedYearsInPosition",
  PriorEstimatedYearsInPosStr   = "Prior_EstimatedYearsInPositionString",
  PriorFirstDateInOrg           = "Prior_First_Date_in_Organization",
  PriorFirstDateInPosition      = "Prior_First_Date_in_Position",
  PriorFiscalYear               = "Prior_FiscalYear",
  PriorGrade                    = "Prior_Grade",
  PriorHireDate                 = "Prior_Hire_Date",
  PriorHourlyRt                 = "Prior_HOURLY_RT",
  PriorHrStatus                 = "Prior_HR_Status",
  PriorIncludedOrExcluded       = "Prior_Included_or_Excluded",
  PriorIsSupervisor             = "Prior_IsSupervisor",
  PriorJobFunction              = "Prior_Job_Function",
  PriorJobcode                  = "Prior_Jobcode",
  PriorJobcodeDescr             = "Prior_Jobcode_Descr",
  PriorLevel1                   = "Prior_Level1",
  PriorLevel2                   = "Prior_Level2",
  PriorLevel3                   = "Prior_Level3",
  PriorLevel4                   = "Prior_Level4",
  PriorLifeCycle                = "Prior_Life_Cycle",
  PriorLocation                 = "Prior_Location",
  PriorLocationGroup            = "Prior_Location_Group",
  PriorMaxRtHourly              = "Prior_MAX_RT_HOURLY",
  PriorOrganization             = "Prior_Organization",
  PriorPerOrg                   = "Prior_PER_ORG",
  PriorPositionDescr            = "Prior_Position_Descr",
  PriorPositionNbr              = "Prior_Position_NBR",
  PriorPsa                      = "Prior_PSA",
  PriorRegionalDistrict         = "Prior_Regional_District",
  PriorRehireDate               = "Prior_Rehire_Date",
  PriorReportsTo                = "Prior_Reports_to",
  PriorSalAdminPlan             = "Prior_Sal_Admin_Plan",
  PriorSelectedGroup            = "Prior_SelectedGroup",
  PriorSeq                      = "Prior_SEQ",
  PriorStdHours                 = "Prior_STD_HOURS",
  PriorStep                     = "Prior_STEP",
  PriorSupervisor               = "Prior_Supervisor"
)

df <- df |> dplyr::rename(any_of(json_to_sql))

# --- Validate expected columns -----------------------------------------------

expected <- names(json_to_sql)

# Hard-stop only if any business key column is missing -- unrecoverable.
key_cols <- c("EmplId", "EffDt", "EffSeq", "EmplRcd")
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
    "EmplId", "CompChange", "EstimatedYearsOfServiceStr", "MoveType", "MoveType1",
    "MoveType2", "Name", "SameGroup", "SameLevel1", "SameOrg", "SupervisorMove",
    "NewAction", "NewActionReason", "NewActionReasonDescr", "NewBusinessUnit",
    "NewBusinessUnitDescr", "NewCity", "NewClassificationGroup", "NewCoreBu",
    "NewCoreOrg", "NewDeptId", "NewDeptIdDescr", "NewDevelopmentRegion",
    "NewEmplCtg", "NewEmplCtgDescr", "NewEmplStatus", "NewEmplStatusDescr",
    "NewEndOfDayHrStatus", "NewEndOfDayPerOrg", "NewEstimatedYearsInOrgStr",
    "NewEstimatedYearsInPosStr", "NewGrade", "NewHrStatus",
    "NewIncludedOrExcluded", "NewIsSupervisor", "NewJobFunction", "NewJobcode",
    "NewJobcodeDescr", "NewLevel1", "NewLevel2", "NewLevel3", "NewLevel4",
    "NewLifeCycle", "NewLocation", "NewLocationGroup", "NewOrganization",
    "NewPerOrg", "NewPositionDescr", "NewPositionNbr", "NewPsa",
    "NewRegionalDistrict", "NewReportsTo", "NewSalAdminPlan", "NewSelectedGroup",
    "NewSupervisor",
    "PriorAction", "PriorActionReason", "PriorActionReasonDescr",
    "PriorBusinessUnit", "PriorBusinessUnitDescr", "PriorCity",
    "PriorClassificationGroup", "PriorCoreBu", "PriorCoreOrg", "PriorDeptId",
    "PriorDeptIdDescr", "PriorDevelopmentRegion", "PriorEmplCtg",
    "PriorEmplCtgDescr", "PriorEmplStatus", "PriorEmplStatusDescr",
    "PriorEndOfDayHrStatus", "PriorEndOfDayPerOrg", "PriorEstimatedYearsInOrgStr",
    "PriorEstimatedYearsInPosStr", "PriorGrade", "PriorHrStatus",
    "PriorIncludedOrExcluded", "PriorIsSupervisor", "PriorJobFunction",
    "PriorJobcode", "PriorJobcodeDescr", "PriorLevel1", "PriorLevel2",
    "PriorLevel3", "PriorLevel4", "PriorLifeCycle", "PriorLocation",
    "PriorLocationGroup", "PriorOrganization", "PriorPerOrg", "PriorPositionDescr",
    "PriorPositionNbr", "PriorPsa", "PriorRegionalDistrict", "PriorReportsTo",
    "PriorSalAdminPlan", "PriorSelectedGroup", "PriorSupervisor"
  ),
  names(df)
)

int_cols <- intersect(
  c(
    "EffSeq", "EmplRcd", "EstimatedYrsOfService", "EstimatedYearsOfService",
    "FiscalYear", "MoveType1Sort", "Seq",
    "NewEstimatedYearsInOrg", "NewEstimatedYearsInPos", "NewStep",
    "PriorEffSeq", "PriorEstimatedYearsInOrg", "PriorEstimatedYearsInPos",
    "PriorFiscalYear", "PriorSeq", "PriorStep"
  ),
  names(df)
)

dec_cols <- intersect(
  c(
    "NewAnnualRt", "NewCompRate", "NewHourlyRt", "NewMaxRtHourly", "NewStdHours",
    "PriorAnnualRt", "PriorCompRate", "PriorHourlyRt", "PriorMaxRtHourly",
    "PriorStdHours"
  ),
  names(df)
)

date_cols <- intersect(
  c(
    "EffDt", "FirstDateOfService", "LeaveServiceDt", "MostHistoricDate",
    "NewActionDt", "NewFirstDateInOrg", "NewFirstDateInPosition",
    "NewHireDate", "NewRehireDate",
    "PriorActionDt", "PriorEffDt", "PriorFirstDateInOrg", "PriorFirstDateInPosition",
    "PriorHireDate", "PriorRehireDate"
  ),
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

# --- Capture and drop rows with NULL/blank EmplId ----------------------------
# NULL EmplId rows cannot be keyed in the MERGE. Capture them for quality
# tracking BEFORE dropping from the main pipeline.
null_key_mask <- is.na(df$EmplId) | df$EmplId == ""
null_key_rows <- df[null_key_mask, ]
null_key_rows$DropReason <- "NULL_EMPLID"

if (nrow(null_key_rows) > 0) {
  warning(paste(
    nrow(null_key_rows),
    "row(s) with NULL/blank EmplId captured for quality log and removed from pipeline."
  ))
  df <- df[!null_key_mask, ]
}

# --- Capture duplicate composite key rows before deduplication ---------------
# Business key: EmplId + EffDt + EffSeq + EmplRcd (PeopleSoft JOB row key).
# Earlier occurrences of each key are dropped; the last row wins.
composite_key <- paste(df$EmplId, df$EffDt, df$EffSeq, df$EmplRcd, sep = "|")
dup_mask      <- duplicated(composite_key, fromLast = TRUE)  # TRUE = earlier occurrence
dup_rows      <- df[dup_mask, ]
dup_rows$DropReason <- "DUPLICATE_COMPOSITE_KEY"

if (nrow(dup_rows) > 0) {
  warning(paste(
    nrow(dup_rows),
    "duplicate (EmplId, EffDt, EffSeq, EmplRcd) row(s) captured for quality log and removed."
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
    "(NULL_EMPLID:", nrow(null_key_rows),
    "| DUPLICATE_COMPOSITE_KEY:", nrow(dup_rows), ")\n")

# --- Load to SQL Server staging table ----------------------------------------

dbBegin(con)

dbExecute(con, paste0("TRUNCATE TABLE ", staging_table, ";"))

dbWriteTable(
  con,
  name      = Id(schema = "dbo", table = "Stg_Peoplesoft_HEM"),
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
      name      = Id(schema = "dbo", table = "Stg_Peoplesoft_HEM_Dropped"),
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

dbExecute(con, "EXEC dbo.usp_Merge_PeopleSoft_HEM")

dbDisconnect(con)

# --- Summary -----------------------------------------------------------------

cat("===================================================\n")
cat("PSA HEM ETL completed\n")
cat("Environment:", api_env, "\n")
cat("Config file:", env_file, "\n")
cat("API Name:", api_name, "\n")
cat("Staging rows loaded:", stg_cnt$StagingRows, "\n")
cat("Completed at:", format(Sys.time()), "\n")
cat("===================================================\n")
