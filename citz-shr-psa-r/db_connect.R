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
# db_connect.R
#
# Shared SQL Server connection helper for all PSA ETL scripts.
# Sourced at the top of every ETL script AFTER bootstrap_env.R via:
#
#   source(file.path(script_dir, "db_connect.R"))
#
# CONTRACT: bootstrap_env.R MUST be sourced before this file so that
# PSA_SQL_SERVER, PSA_SQL_DATABASE, PSA_SQL_USERNAME, and PSA_SQL_PASSWORD
# are available in the environment.
#
# Sets in the caller's environment:
#   con  -- open DBI connection object (must be closed with dbDisconnect(con))
#
# SQL AUTHENTICATION POLICY:
#   Trusted_Connection = "No" is REQUIRED for Task Scheduler execution.
#
#   Trusted_Connection = "Yes" (Windows/Kerberos auth) fails when the task
#   runs non-interactively because the service account has no Kerberos ticket:
#     "Login failed for user 'NT AUTHORITY\ANONYMOUS LOGON'"
#
#   SQL credentials (PSA_SQL_USERNAME / PSA_SQL_PASSWORD) come from SYSTEM
#   environment variables on the Windows host -- never from .Renviron.* files.
# ============================================================================

library(DBI)
library(odbc)

# --- Open SQL Server connection ----------------------------------------------

con <- tryCatch(
  dbConnect(
    odbc(),
    Driver                 = "ODBC Driver 17 for SQL Server",
    Server                 = Sys.getenv("PSA_SQL_SERVER"),
    Database               = Sys.getenv("PSA_SQL_DATABASE"),
    UID                    = Sys.getenv("PSA_SQL_USERNAME"),
    PWD                    = Sys.getenv("PSA_SQL_PASSWORD"),
    Trusted_Connection     = "No",
    Encrypt                = "Yes",
    TrustServerCertificate = "Yes"
  ),
  error = function(e) {
    stop(paste(
      "SQL Server connection failed.",
      "Server:", Sys.getenv("PSA_SQL_SERVER"),
      "Database:", Sys.getenv("PSA_SQL_DATABASE"),
      "\nCheck PSA_SQL_USERNAME / PSA_SQL_PASSWORD system env vars.",
      "\nError:", conditionMessage(e)
    ))
  }
)

# --- Validate connection succeeded ------------------------------------------

if (!dbIsValid(con)) {
  stop(paste(
    "SQL Server connection object is invalid after connect.",
    "Server:", Sys.getenv("PSA_SQL_SERVER")
  ))
}

cat("Connected to SQL Server:", Sys.getenv("PSA_SQL_SERVER"),
    "/", Sys.getenv("PSA_SQL_DATABASE"), "\n")
cat("Connection established at:", format(Sys.time()), "\n")
