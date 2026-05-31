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
# PeopleSoft API - Key Discovery Tool
#
# Purpose:
#   Fetches ALL data from a PeopleSoft API endpoint and analyzes
#   every column (and common multi-column combinations) to determine
#   which column(s) form a unique business key.
#
# This is a critical onboarding step - the business key determines:
#   - Primary key on staging/target tables
#   - MERGE ON clause
#   - Audit granularity
#
# Usage:
#   1. Set api_name below
#   2. Run this script
#   3. Review the output to identify the business key
#   4. Use the key when generating DDLs
#
# Output:
#   - Console report of uniqueness analysis
#   - JSON report saved to schemas/ folder
# ============================================================================

library(httr2)
library(jsonlite)
library(dplyr)
library(tibble)

# --- CONFIGURATION: Set your API name here -----------------------------------

api_name <- "Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ"

# --- Resolve project root and load environment config ------------------------

get_script_dir <- function() {
  if (interactive() && requireNamespace("rstudioapi", quietly = TRUE)) {
    path <- rstudioapi::getActiveDocumentContext()$path
    if (nchar(path) > 0) return(dirname(path))
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("--file=", "", file_arg))))
  }
  return(getwd())
}

script_dir   <- get_script_dir()
project_root <- dirname(script_dir)

api_env  <- toupper(Sys.getenv("PSA_API_ENV", unset = "PROD"))
env_file <- file.path(project_root, switch(
  api_env,
  "TEST" = ".Renviron.test",
  "PROD" = ".Renviron.prod",
  stop(paste("Invalid PSA_API_ENV:", api_env))
))

if (!file.exists(env_file)) {
  stop(paste("Environment config file not found:", env_file))
}

readRenviron(env_file)

# --- Load config -------------------------------------------------------------

api_base_url <- Sys.getenv("PSA_API_BASE_URL")
psa_user     <- Sys.getenv("PSA_API_USERNAME")
psa_pass     <- Sys.getenv("PSA_API_PROD_PASSWORD")
proxy_host   <- Sys.getenv("PSA_PROXY_HOST")
proxy_port   <- as.integer(Sys.getenv("PSA_PROXY_PORT", unset = "8080"))

required <- c("PSA_API_BASE_URL", "PSA_API_USERNAME", "PSA_API_PROD_PASSWORD", "PSA_PROXY_HOST")
missing  <- required[Sys.getenv(required) == ""]
if (length(missing) > 0) {
  stop(paste("Missing environment variables:", paste(missing, collapse = ", ")))
}

# --- Helper: normalize empty JSON objects {} -> NA ---------------------------

normalize_cell <- function(x) {
  if (is.list(x) && length(x) == 0) return(NA)
  x
}

# --- Helper: fetch a single page (tries GET then POST) -----------------------

fetch_page <- function(url) {
  # Try GET first
  req <- request(url) |>
    req_auth_basic(psa_user, psa_pass) |>
    req_headers(Accept = "application/json") |>
    req_timeout(120) |>
    req_proxy(proxy_host, proxy_port)
  
  result <- tryCatch(
    {
      resp <- req_perform(req)
      list(success = TRUE, data = resp_body_json(resp, simplifyVector = FALSE))
    },
    error = function(e) list(success = FALSE)
  )
  
  if (result$success) return(result$data)
  
  # Fallback to POST
  req_post <- request(url) |>
    req_method("POST") |>
    req_auth_basic(psa_user, psa_pass) |>
    req_headers(Accept = "application/json") |>
    req_timeout(120) |>
    req_proxy(proxy_host, proxy_port)
  
  resp <- req_perform(req_post)
  resp_body_json(resp, simplifyVector = FALSE)
}

# --- Helper: fetch all pages -------------------------------------------------

fetch_all <- function(start_url) {
  url   <- start_url
  pages <- list()
  i     <- 1
  
  repeat {
    cat("  Fetching page", i, "...\n")
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
  
  if (length(pages) == 0) return(tibble())
  
  rows <- unlist(pages, recursive = FALSE)
  
  normalize_row <- function(x) {
    lapply(x, function(v) {
      if (is.list(v) && length(v) == 0) NA else v
    })
  }
  
  rows_norm <- lapply(rows, normalize_row)
  bind_rows(rows_norm)
}

# --- Fetch all data ----------------------------------------------------------

api_url <- paste0(api_base_url, api_name)

cat("===================================================\n")
cat("PSA Key Discovery\n")
cat("API Name:", api_name, "\n")
cat("Environment:", api_env, "\n")
cat("===================================================\n\n")

cat("Fetching all data from API...\n")
df <- fetch_all(api_url)

if (nrow(df) == 0) stop("No rows returned from API.")

total_rows <- nrow(df)
cat("\nTotal rows returned:", total_rows, "\n")
cat("Total columns:", ncol(df), "\n\n")

# --- Analyze single-column uniqueness ----------------------------------------

cat("===================================================\n")
cat("SINGLE-COLUMN UNIQUENESS ANALYSIS\n")
cat("===================================================\n")
cat(sprintf("%-30s %10s %10s %8s %s\n", "Column", "Distinct", "Total", "Pct", "Unique?"))
cat(paste(rep("-", 75), collapse = ""), "\n")

single_results <- list()

for (col in names(df)) {
  vals <- df[[col]]
  
  # Skip list columns
  if (is.list(vals)) {
    non_null <- sum(!sapply(vals, is.null) & !sapply(vals, function(x) is.list(x) && length(x) == 0))
    distinct_count <- length(unique(as.character(vals)))
  } else {
    non_null <- sum(!is.na(vals))
    distinct_count <- length(unique(vals[!is.na(vals)]))
  }
  
  pct <- round(distinct_count / total_rows * 100, 1)
  is_unique <- distinct_count == total_rows
  null_count <- total_rows - non_null
  
  marker <- if (is_unique) "YES ***" else if (pct > 90) "HIGH" else ""
  
  cat(sprintf("%-30s %10d %10d %7.1f%% %s\n",
              col, distinct_count, total_rows, pct, marker))
  
  single_results[[col]] <- list(
    column         = col,
    distinct_count = distinct_count,
    total_rows     = total_rows,
    null_count     = null_count,
    is_unique      = is_unique,
    pct            = pct
  )
}

cat(paste(rep("-", 75), collapse = ""), "\n")

# --- Identify likely key columns (high cardinality) --------------------------

likely_key_cols <- names(single_results)[
  sapply(single_results, function(x) x$pct > 50 && !x$is_unique)
]

# Also include columns with "id", "key", "position", "empl" in the name
id_pattern_cols <- grep("(?i)(id|key|position|empl|name)", names(df), value = TRUE)
candidate_cols <- unique(c(likely_key_cols, id_pattern_cols))

# Filter to columns that actually exist and are not all NULL
candidate_cols <- candidate_cols[candidate_cols %in% names(df)]

cat("\n")
cat("===================================================\n")
cat("COMPOSITE KEY ANALYSIS\n")
cat("===================================================\n")
cat("Testing combinations of high-cardinality columns...\n\n")

cat(sprintf("%-50s %10s %8s %s\n", "Candidate Key", "Distinct", "Pct", "Unique?"))
cat(paste(rep("-", 80), collapse = ""), "\n")

composite_results <- list()

# Test pairs
if (length(candidate_cols) >= 2) {
  pairs <- combn(candidate_cols, 2, simplify = FALSE)
  
  # Limit to reasonable number of tests
  if (length(pairs) > 50) {
    pairs <- pairs[1:50]
    cat("(Testing first 50 of", length(pairs), "possible pairs)\n")
  }
  
  for (pair in pairs) {
    col1 <- pair[1]
    col2 <- pair[2]
    
    # Convert to character for safe concatenation
    key_vals <- paste(as.character(df[[col1]]), as.character(df[[col2]]), sep = "|")
    distinct_count <- length(unique(key_vals))
    pct <- round(distinct_count / total_rows * 100, 1)
    is_unique <- distinct_count == total_rows
    
    key_name <- paste(col1, "+", col2)
    marker <- if (is_unique) "YES ***" else ""
    
    cat(sprintf("%-50s %10d %7.1f%% %s\n",
                key_name, distinct_count, pct, marker))
    
    if (is_unique) {
      composite_results[[key_name]] <- list(
        columns  = pair,
        distinct = distinct_count,
        is_unique = TRUE
      )
    }
  }
}

# Test triples (only if no unique pair found)
if (length(composite_results) == 0 && length(candidate_cols) >= 3) {
  cat("\nNo unique pair found. Testing triples...\n\n")
  
  triples <- combn(candidate_cols, 3, simplify = FALSE)
  
  if (length(triples) > 30) {
    triples <- triples[1:30]
    cat("(Testing first 30 of", length(triples), "possible triples)\n")
  }
  
  for (triple in triples) {
    key_vals <- paste(
      as.character(df[[triple[1]]]),
      as.character(df[[triple[2]]]),
      as.character(df[[triple[3]]]),
      sep = "|"
    )
    distinct_count <- length(unique(key_vals))
    pct <- round(distinct_count / total_rows * 100, 1)
    is_unique <- distinct_count == total_rows
    
    key_name <- paste(triple, collapse = " + ")
    marker <- if (is_unique) "YES ***" else ""
    
    cat(sprintf("%-50s %10d %7.1f%% %s\n",
                key_name, distinct_count, pct, marker))
    
    if (is_unique) {
      composite_results[[key_name]] <- list(
        columns   = triple,
        distinct  = distinct_count,
        is_unique = TRUE
      )
    }
  }
}

cat(paste(rep("-", 80), collapse = ""), "\n")

# --- Show duplicates for the most likely key ----------------------------------

cat("\n")
cat("===================================================\n")
cat("DUPLICATE ANALYSIS (on most likely single key)\n")
cat("===================================================\n")

# Find the column with highest cardinality that's not unique
best_single <- names(single_results)[
  which.max(sapply(single_results, function(x) x$distinct_count))
]

dup_counts <- df |>
  group_by(across(all_of(best_single))) |>
  summarise(row_count = n(), .groups = "drop") |>
  filter(row_count > 1) |>
  arrange(desc(row_count))

cat("Most likely key column:", best_single, "\n")
cat("Duplicate values:", nrow(dup_counts), "\n")
cat("Max rows per key:", if (nrow(dup_counts) > 0) max(dup_counts$row_count) else 0, "\n\n")

if (nrow(dup_counts) > 0) {
  cat("Top 10 duplicates:\n")
  print(head(dup_counts, 10))
  
  # Show sample duplicate rows
  top_dup <- dup_counts[[best_single]][1]
  cat("\nSample duplicate rows for", best_single, "=", as.character(top_dup), ":\n")
  
  sample_rows <- df |>
    filter(.data[[best_single]] == top_dup) |>
    select(any_of(c(best_single, candidate_cols)))
  
  print(sample_rows)
}

# --- Summary ------------------------------------------------------------------

cat("\n")
cat("===================================================\n")
cat("KEY DISCOVERY SUMMARY\n")
cat("===================================================\n")
cat("API:", api_name, "\n")
cat("Total rows:", total_rows, "\n")
cat("Total columns:", ncol(df), "\n\n")

# Report unique single columns
unique_singles <- names(single_results)[
  sapply(single_results, function(x) x$is_unique)
]

if (length(unique_singles) > 0) {
  cat("UNIQUE single columns found:\n")
  for (col in unique_singles) {
    cat("  ***", col, "\n")
  }
} else {
  cat("No single column is unique.\n")
}

if (length(composite_results) > 0) {
  cat("\nUNIQUE composite keys found:\n")
  for (key_name in names(composite_results)) {
    cat("  ***", key_name, "\n")
  }
} else if (length(unique_singles) == 0) {
  cat("\nNo unique composite key found in tested combinations.\n")
  cat("You may need to:\n")
  cat("  1. Examine the data manually\n")
  cat("  2. Ask PSA data team for the business key\n")
  cat("  3. Consider using a synthetic/surrogate key\n")
}

cat("\n")
cat("RECOMMENDATION:\n")

if (length(unique_singles) > 0) {
  cat("  Use", unique_singles[1], "as the business key (single column, simplest)\n")
} else if (length(composite_results) > 0) {
  first_composite <- composite_results[[1]]
  cat("  Use composite key:", paste(first_composite$columns, collapse = " + "), "\n")
  cat("  Update DDLs and MERGE ON clause accordingly\n")
} else {
  cat("  No natural key found. Consider:\n")
  cat("    - Adding a HASHBYTES-based row key\n")
  cat("    - Using IDENTITY surrogate key\n")
  cat("    - Consulting PSA data team\n")
}

# --- Save results to JSON ----------------------------------------------------

api_folder <- api_name

output_dir <- file.path(
  project_root,
  "citz-shr-psa-sql",
  "PeopleSoftAPI",
  api_folder,
  "schemas"
)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

key_report <- list(
  api_name     = api_name,
  discovered   = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  environment  = api_env,
  total_rows   = total_rows,
  total_columns = ncol(df),
  single_column_analysis = single_results,
  unique_single_columns  = unique_singles,
  composite_keys_found   = composite_results,
  recommendation = if (length(unique_singles) > 0) {
    paste("Single key:", unique_singles[1])
  } else if (length(composite_results) > 0) {
    paste("Composite key:", paste(composite_results[[1]]$columns, collapse = " + "))
  } else {
    "No natural key found"
  }
)

output_file <- file.path(output_dir, paste0(api_name, "_key_analysis.json"))
writeLines(toJSON(key_report, pretty = TRUE, auto_unbox = TRUE), output_file)

cat("\n")
cat("Key analysis saved to:", output_file, "\n")
cat("===================================================\n")