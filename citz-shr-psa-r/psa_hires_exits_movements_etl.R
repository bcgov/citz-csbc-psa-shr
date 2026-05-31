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

# ============================================================================
# ETL: Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ
# Target table : dbo.Stg_Peoplesoft_HEM  (staging)
# Dropped table: dbo.Stg_Peoplesoft_HEM_Dropped
# HTTP method  : GET (paginated via @odata.nextLink)
# Business key : EmplId + EffDt + EffSeq + EmplRcd
#   - No single-column or 2-column natural key found by psa_key_discovery.R
#   - Using PeopleSoft standard JOB row key (4 columns)
# Dedup        : YES — deduplicate on (EmplId, EffDt, EffSeq, EmplRcd) before load;
#                keep last row; dropped rows written to Dropped table
# Notes:
#   - JSON fields "New_Level4" and "Prior_Level4" may return {} (empty object);
#     normalize_cell() converts empty lists to NA
#   - ~1 377 rows have NULL Prior_ columns (new hires, no prior event)
# ============================================================================

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
  library(dplyr)
  library(DBI)
  library(odbc)
  library(purrr)
})

# ── Connection ────────────────────────────────────────────────────────────────
con <- dbConnect(
  odbc(),
  Driver   = Sys.getenv("PSA_DB_DRIVER"),
  Server   = Sys.getenv("PSA_DB_SERVER"),
  Database = Sys.getenv("PSA_DB_NAME"),
  Trusted_Connection = "Yes"
)
on.exit(dbDisconnect(con), add = TRUE)

# ── API configuration ─────────────────────────────────────────────────────────
base_url  <- Sys.getenv("PSA_API_BASE_URL")
api_name  <- "Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ"
api_token <- Sys.getenv("PSA_API_TOKEN")

# ── Helper: normalize a single cell value ────────────────────────────────────
normalize_cell <- function(x) {
  if (is.list(x) && length(x) == 0) return(NA_character_)  # {} → NA
  if (is.null(x) || length(x) == 0) return(NA_character_)
  as.character(x[[1]])
}

# ── Fetch all pages ───────────────────────────────────────────────────────────
all_rows   <- list()
next_url   <- paste0(base_url, "/", api_name)

repeat {
  req <- request(next_url) |>
    req_auth_bearer_token(api_token) |>
    req_headers(Accept = "application/json") |>
    req_error(is_error = \(r) FALSE)

  resp <- req_perform(req)

  if (resp_status(resp) != 200L) {
    stop(sprintf("API request failed: HTTP %d — %s", resp_status(resp), next_url))
  }

  body    <- resp_body_string(resp)
  parsed  <- fromJSON(body, simplifyVector = FALSE)
  records <- parsed[["value"]]

  if (length(records) == 0L) break

  all_rows <- c(all_rows, records)

  next_link <- parsed[["@odata.nextLink"]] %||% parsed[["odata.nextLink"]]
  if (is.null(next_link) || nchar(next_link) == 0L) break
  next_url <- next_link
  Sys.sleep(0.2)
}

message(sprintf("[HEM] Pages fetched — total raw rows: %d", length(all_rows)))

if (length(all_rows) == 0L) {
  stop("No records returned from API. Aborting ETL.")
}

# ── Flatten to data frame ─────────────────────────────────────────────────────
df_raw <- map_dfr(all_rows, function(row) {
  as.data.frame(
    lapply(row, normalize_cell),
    stringsAsFactors = FALSE
  )
})

# ── Rename JSON keys → SQL column names ──────────────────────────────────────
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

df <- df_raw |> dplyr::rename(any_of(json_to_sql))

# ── Backfill missing columns as NA ────────────────────────────────────────────
expected_cols <- names(json_to_sql)
missing_cols  <- setdiff(expected_cols, names(df))
if (length(missing_cols) > 0L) {
  message(sprintf("[HEM] Backfilling %d missing columns: %s",
                  length(missing_cols), paste(missing_cols, collapse = ", ")))
  df[missing_cols] <- NA_character_
}

# ── Hard stop if business key column is absent ────────────────────────────────
key_cols <- c("EmplId", "EffDt", "EffSeq", "EmplRcd")
absent   <- setdiff(key_cols, names(df))
if (length(absent) > 0L) {
  stop(sprintf("FATAL: Business key column(s) missing from API response: %s",
               paste(absent, collapse = ", ")))
}

# ── Type alignment ────────────────────────────────────────────────────────────
char_cols <- c(
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
)

int_cols <- c(
  "EffSeq", "EmplRcd", "EstimatedYrsOfService", "EstimatedYearsOfService",
  "FiscalYear", "MoveType1Sort", "Seq",
  "NewEstimatedYearsInOrg", "NewEstimatedYearsInPos", "NewStep",
  "PriorEffSeq", "PriorEstimatedYearsInOrg", "PriorEstimatedYearsInPos",
  "PriorFiscalYear", "PriorSeq", "PriorStep"
)

dec_cols <- c(
  "NewAnnualRt", "NewCompRate", "NewHourlyRt", "NewMaxRtHourly", "NewStdHours",
  "PriorAnnualRt", "PriorCompRate", "PriorHourlyRt", "PriorMaxRtHourly",
  "PriorStdHours"
)

date_cols <- c(
  "EffDt", "FirstDateOfService", "LeaveServiceDt", "MostHistoricDate",
  "NewActionDt", "NewFirstDateInOrg", "NewFirstDateInPosition",
  "NewHireDate", "NewRehireDate",
  "PriorActionDt", "PriorEffDt", "PriorFirstDateInOrg", "PriorFirstDateInPosition",
  "PriorHireDate", "PriorRehireDate"
)

df <- df |>
  mutate(
    across(all_of(intersect(char_cols, names(df))), as.character),
    across(all_of(intersect(int_cols,  names(df))), ~ as.integer(suppressWarnings(as.integer(.)))),
    across(all_of(intersect(dec_cols,  names(df))), ~ as.numeric(suppressWarnings(as.numeric(.)))),
    across(all_of(intersect(date_cols, names(df))), ~ as.Date(as.character(.)))
  )

# ── Capture NULL EmplId rows before dedup ─────────────────────────────────────
df_null_key <- df |> filter(is.na(EmplId) | EmplId == "")

if (nrow(df_null_key) > 0L) {
  message(sprintf("[HEM] Dropping %d rows with NULL EmplId.", nrow(df_null_key)))
  df_null_key <- df_null_key |> mutate(DropReason = "NULL_EMPLID")
  tryCatch(
    dbWriteTable(con, "Stg_Peoplesoft_HEM_Dropped", df_null_key,
                 append = TRUE, row.names = FALSE),
    error = function(e) warning(sprintf("[HEM] Could not write NULL_EMPLID rows to Dropped: %s", e$message))
  )
}

df <- df |> filter(!is.na(EmplId) & EmplId != "")

# ── Deduplicate on business key ───────────────────────────────────────────────
# Keep last occurrence (last row wins). ~1 377 new-hire rows have NULL Prior_ columns —
# that is expected data, not a duplication issue.
n_before  <- nrow(df)
df_dedup  <- df |>
  group_by(EmplId, EffDt, EffSeq, EmplRcd) |>
  mutate(.row_n = row_number()) |>
  ungroup()

df_dropped_dup <- df_dedup |> filter(.row_n < max(.row_n), .by = c(EmplId, EffDt, EffSeq, EmplRcd))
df            <- df_dedup |> filter(.row_n == max(.row_n), .by = c(EmplId, EffDt, EffSeq, EmplRcd)) |>
  select(-.row_n)

n_after <- nrow(df)
if ((n_before - n_after) > 0L) {
  message(sprintf("[HEM] Dedup removed %d duplicate rows (kept %d).", n_before - n_after, n_after))
  df_dropped_dup <- df_dropped_dup |> select(-.row_n) |> mutate(DropReason = "DUPLICATE_COMPOSITE_KEY")
  tryCatch(
    dbWriteTable(con, "Stg_Peoplesoft_HEM_Dropped", df_dropped_dup,
                 append = TRUE, row.names = FALSE),
    error = function(e) warning(sprintf("[HEM] Could not write DUPLICATE rows to Dropped: %s", e$message))
  )
}

message(sprintf("[HEM] Rows after dedup: %d", nrow(df)))

# Sanity check: business key must be unique after dedup
n_unique_key <- df |> distinct(EmplId, EffDt, EffSeq, EmplRcd) |> nrow()
if (n_unique_key != nrow(df)) {
  stop(sprintf(
    "[HEM] Business key still not unique after dedup: %d rows vs %d distinct keys. Aborting.",
    nrow(df), n_unique_key
  ))
}

# ── Load to staging ───────────────────────────────────────────────────────────
dbExecute(con, "TRUNCATE TABLE dbo.Stg_Peoplesoft_HEM")

dbWriteTable(con, "Stg_Peoplesoft_HEM", df, append = TRUE, row.names = FALSE)

message(sprintf("[HEM] Staging load complete — %d rows loaded.", nrow(df)))

# ── Execute MERGE ─────────────────────────────────────────────────────────────
merge_result <- dbGetQuery(con, "EXEC dbo.usp_Merge_PeopleSoft_HEM")
message(sprintf(
  "[HEM] MERGE complete — Inserted: %d | Updated: %d | SoftDeleted: %d | Reactivated: %d | ActiveTarget: %d",
  merge_result$Inserted,
  merge_result$Updated,
  merge_result$SoftDeleted,
  merge_result$Reactivated,
  merge_result$ActiveTarget
))
