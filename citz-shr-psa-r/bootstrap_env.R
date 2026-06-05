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
# bootstrap_env.R
#
# Shared environment bootstrap for all PSA ETL scripts.
# Sourced at the top of every ETL script via:
#
#   source(file.path(script_dir, "bootstrap_env.R"))
#
# CONTRACT: The calling script MUST set `script_dir` before sourcing this
# file. `script_dir` must point to citz-shr-psa-r/ (the folder that
# contains this file and the calling ETL script).
#
# Sets in the caller's environment:
#   project_root  -- absolute path to the project root (parent of citz-shr-psa-r/)
#   api_env       -- "TEST" or "PROD" (from PSA_API_ENV, default PROD)
#   env_file      -- absolute path to the loaded .Renviron file
#   api_base_url  -- base URL for PeopleSoft API (from .Renviron)
#   sql_server    -- SQL Server hostname (from .Renviron)
#   sql_database  -- SQL Server database name (from .Renviron)
#   proxy_host    -- HTTP proxy hostname (from .Renviron)
#   proxy_port    -- HTTP proxy port as integer (from .Renviron)
#   psa_user      -- API username (from SYSTEM env var PSA_API_USERNAME)
#   psa_pass      -- API password (from SYSTEM env var PSA_API_PROD_PASSWORD)
#   sql_user      -- SQL Server login (from SYSTEM env var PSA_SQL_USERNAME)
#   sql_pass      -- SQL Server password (from SYSTEM env var PSA_SQL_PASSWORD)
#
# SECURITY NOTE:
#   sql_user / sql_pass and the API credentials come from SYSTEM or USER
#   environment variables on the Windows host -- NEVER from .Renviron.* files.
#   .Renviron.* files are for non-sensitive config only and may be viewed by
#   ops staff. The Windows ACL on SYSTEM env vars provides the security
#   boundary for credentials.
# ============================================================================

# --- Resolve project root from script_dir ------------------------------------
# script_dir is set by the calling ETL script (via commandArgs). It points to
# citz-shr-psa-r/. Project root is its parent directory.
#
# Task Scheduler launches Rscript.exe from an arbitrary working directory
# (typically system32), so we cannot rely on getwd(). RStudio always sets cwd
# to the project root, which masks the problem in interactive use.
# Using script_dir (caller-resolved) avoids any cwd dependency.

if (!exists("script_dir")) {
  stop(paste(
    "bootstrap_env.R requires 'script_dir' to be set before sourcing.",
    "Add the commandArgs resolver to your script before source(bootstrap_env.R).",
    sep = "\n"
  ))
}

project_root <- dirname(script_dir)
setwd(project_root)

cat("Working directory:", getwd(), "\n")
cat("Script directory:", script_dir, "\n")
cat("Project root:", project_root, "\n")

# --- Determine environment and load .Renviron --------------------------------
# PSA_API_ENV must be a SYSTEM env var (or omitted to default to PROD).
# It controls which .Renviron file is loaded: .Renviron.test or .Renviron.prod.

api_env <- toupper(Sys.getenv("PSA_API_ENV", unset = "PROD"))

env_file <- switch(api_env,
  "TEST" = file.path(project_root, ".Renviron.test"),
  "PROD" = file.path(project_root, ".Renviron.prod"),
  stop("PSA_API_ENV must be TEST or PROD; got: ", api_env)
)

if (!file.exists(env_file)) {
  stop("Env file not found: ", env_file,
       "\nCopy .Renviron.example to that path and fill in non-sensitive values.")
}

readRenviron(env_file)
cat("Loaded env file:", env_file, "\n")

# --- Read non-sensitive config from .Renviron --------------------------------

api_base_url <- Sys.getenv("PSA_API_BASE_URL")
sql_server   <- Sys.getenv("PSA_SQL_SERVER")
sql_database <- Sys.getenv("PSA_SQL_DATABASE")
proxy_host   <- Sys.getenv("PSA_PROXY_HOST")
proxy_port   <- as.integer(Sys.getenv("PSA_PROXY_PORT"))

# --- Read credentials from SYSTEM environment variables ----------------------
# These MUST be set as SYSTEM (or USER) env vars on the Windows host.
# They must NOT appear in any .Renviron.* file committed to this repo.
# Set via: Win+R -> sysdm.cpl -> Advanced -> Environment Variables

psa_user <- Sys.getenv("PSA_API_USERNAME")
psa_pass <- Sys.getenv("PSA_API_PROD_PASSWORD")
sql_user <- Sys.getenv("PSA_SQL_USERNAME")
sql_pass <- Sys.getenv("PSA_SQL_PASSWORD")

# --- Validate all required variables -----------------------------------------
# config_vars: expected in .Renviron.<env>
# credential_vars: expected as SYSTEM env vars (never in .Renviron.*)

config_vars <- c(
  "PSA_API_BASE_URL",
  "PSA_SQL_SERVER",
  "PSA_SQL_DATABASE",
  "PSA_PROXY_HOST"
)

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

cat("Environment variables loaded successfully\n")
