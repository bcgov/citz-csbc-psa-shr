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
# Dataset: Department / Organization Levels (Org Hierarchy)
#
# This script:
#   1. Calls the PeopleSoft Analytics API (OData, Basic Auth)
#   2. Normalizes JSON (handles empty objects {} -> NA)
#   3. Loads into a SQL Server staging table (TRUNCATE + INSERT)
#   4. Executes a MERGE stored procedure (staging -> target + audit)
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

# --- Robust environment loading (Task Scheduler safe) ------------------------
# Task Scheduler launches Rscript.exe with an arbitrary working directory
# (typically system32), NOT the project root. RStudio masks this because it
# always launches with the project as the working directory. To behave
# identically in both contexts, this script:
#   1. Resolves project root from its own file path via commandArgs().
#   2. setwd()'s to project root before any relative path is used.
#   3. Loads .Renviron.<env> from an absolute path under project root.
#
# Secrets (PSA_API_*, PSA_SQL_USERNAME/PASSWORD) MUST come from SYSTEM or
# USER environment variables — they are never stored in .Renviron.* files.

args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args[grep("--file=", args)])

if (length(script_path) > 0) {
  script_dir <- dirname(normalizePath(script_path))
} else {
  script_dir <- getwd()
}

# Project root = parent of the citz-shr-psa-r/ folder.
project_root <- dirname(script_dir)
setwd(project_root)

cat("Working directory:", getwd(), "\n")
cat("Script directory:", script_dir, "\n")
cat("Project root:", project_root, "\n")

api_env <- toupper(Sys.getenv("PSA_API_ENV", unset = "PROD"))

env_file <- switch(api_env,
  "TEST" = file.path(project_root, ".Renviron.test"),
  "PROD" = file.path(project_root, ".Renviron.prod"),
  stop("PSA_API_ENV must be TEST or PROD; got: ", api_env)
)

if (!file.exists(env_file)) {
  stop("Env file not found: ", env_file,
       "\nCopy .Renviron.example to that path and fill in values.")
}

readRenviron(env_file)
cat("Loaded env file:", env_file, "\n")

# --- Configuration -----------------------------------------------------------

# From .Renviron file (non-sensitive config)
api_base_url <- Sys.getenv("PSA_API_BASE_URL")
sql_server   <- Sys.getenv("PSA_SQL_SERVER")
sql_database <- Sys.getenv("PSA_SQL_DATABASE")
proxy_host   <- Sys.getenv("PSA_PROXY_HOST")
proxy_port   <- as.integer(Sys.getenv("PSA_PROXY_PORT"))

# From system environment variables (sensitive credentials)
# NEVER stored in .Renviron.* — must be set as SYSTEM/USER env vars on the host.
psa_user <- Sys.getenv("PSA_API_USERNAME")
psa_pass <- Sys.getenv("PSA_API_PROD_PASSWORD")
sql_user <- Sys.getenv("PSA_SQL_USERNAME")
sql_pass <- Sys.getenv("PSA_SQL_PASSWORD")

# API name (not sensitive - this is the dataset identifier)
api_name <- "Datamart_CITZ_Report_vw_Dept_Org_Levels" 

# Full API URL (base + API name)
api_url <- paste0(api_base_url, api_name)

# Table names
staging_table <- "dbo.Stg_Peoplesoft_Dept_Org_Levels"
target_table  <- "dbo.Peoplesoft_Dept_Org_Levels"

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
  "PSA_API_PROD_PASSWORD",
  "PSA_SQL_USERNAME",
  "PSA_SQL_PASSWORD"
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

# --- Helper: fetch a single page from the API --------------------------------

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

# --- Fetch + parse + clean ---------------------------------------------------

df <- fetch_all(api_url)

if (nrow(df) == 0) stop("No rows returned from API.")

expected <- c(
  "DepartmentID", "Level1", "Level1Key", "Level2", "Level2Key",
  "Level3", "Level3Key", "Level4", "Level4Key", "Level5", "Level5Key",
  "Organization"
)

missing_cols <- setdiff(expected, names(df))
if (length(missing_cols) > 0) {
  stop(paste("Missing expected columns:", paste(missing_cols, collapse = ", ")))
}

for (col in expected) {
  df[[col]] <- lapply(df[[col]], normalize_cell)
  df[[col]] <- unlist(df[[col]], recursive = FALSE, use.names = FALSE)
}

# Type alignment (matches SQL Server table schema)
char_cols <- intersect(
  c("DepartmentID", "Level1", "Level2", "Level3", "Level4", "Level5", "Organization"),
  names(df)
)

int_cols <- intersect(
  c("Level1Key", "Level2Key", "Level3Key", "Level4Key", "Level5Key"),
  names(df)
)

df <- df |>
  dplyr::mutate(
    dplyr::across(all_of(char_cols), as.character),
    dplyr::across(all_of(int_cols), ~ suppressWarnings(as.integer(.x)))
  )

# --- Load to SQL Server staging table ----------------------------------------
# SQL Authentication is REQUIRED under Task Scheduler.
# Trusted_Connection = "Yes" causes "Login failed for user 'NT AUTHORITY\\ANONYMOUS LOGON'"
# when the task runs non-interactively (no Kerberos delegation).

con <- dbConnect(
  odbc(),
  Driver               = "ODBC Driver 17 for SQL Server",
  Server               = sql_server,
  Database             = sql_database,
  UID                  = sql_user,
  PWD                  = sql_pass,
  Trusted_Connection   = "No",
  Encrypt              = "Yes",
  TrustServerCertificate = "Yes"
)

dbBegin(con)

dbExecute(con, paste0("TRUNCATE TABLE ", staging_table, ";"))

dbWriteTable(
  con,
  name      = Id(schema = "dbo", table = "Stg_Peoplesoft_Dept_Org_Levels"),
  value     = df,
  append    = TRUE,
  row.names = FALSE
)

stg_cnt <- dbGetQuery(con, paste0("SELECT COUNT(*) AS StagingRows FROM ", staging_table, ";"))

dbCommit(con)

# --- Execute MERGE stored procedure (staging -> target + audit) ---------------

dbExecute(con, "EXEC dbo.usp_Merge_PeopleSoft_Dept_Org_Levels")

dbDisconnect(con)

# --- Summary ------------------------------------------------------------------

cat("===================================================\n")
cat("PSA Dept Org Levels ETL completed\n")
cat("Environment:", api_env, "\n")
cat("Config file:", env_file, "\n")
cat("API Name:", api_name, "\n")
cat("Staging rows loaded:", stg_cnt$StagingRows, "\n")
cat("Completed at:", format(Sys.time()), "\n")
cat("===================================================\n")