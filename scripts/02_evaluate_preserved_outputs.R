# ////////////////////////////////////////////////////
#
#
# PON LLM Pilot - Evaluate Preserved SBS Outputs
#
# Purpose:
# - Reconstruct the manuscript-facing SBS baseline from preserved files
# - Evaluate frozen 2024 SBS outputs against the confirmed human reference
# - Write derived evaluation, metric, and error tables without API calls
#
# Requirements:
# - Project configuration in config/config.yml
# - Frozen 2024 *_sbs.txt outputs for the five comparative PONs
# - Confirmed human-reference and question CSV files
#
# AI Disclosure:
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-r-scripts.md
#
# ////////////////////////////////////////////////////
# ////////////////////////////////////////////////////
#
#
# 1. Load Packages and Shared Functions ----
#
#
# ////////////////////////////////////////////////////

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(tibble)
  library(yaml)
})

source("R/analysis.R")

# ////////////////////////////////////////////////////
#
#
# 2. Load Configuration and Reference Data ----
#
#
# ////////////////////////////////////////////////////

cfg <- yaml::read_yaml("config/config.yml")
questions <- readr::read_csv(cfg$project$questions_file, show_col_types = FALSE)
human <- readr::read_csv(cfg$project$human_responses_file, show_col_types = FALSE)

# ////////////////////////////////////////////////////
#
#
# 3. Register Frozen SBS Outputs ----
#
#
# ////////////////////////////////////////////////////

files <- tibble::tribble(
  ~entity_slug, ~path,
  "irg",  "output/BO2A-2024-12-24-2-55-3_irg_sbs.txt",
  "euhc", "output/BO3A-2024-12-24-2-55-18_euhc_sbs.txt",
  "coas", "output/BO4A-2024-12-24-2-55-51_coas_sbs.txt",
  "can",  "output/BO5A-2024-12-24-2-56-12_can_sbs.txt",
  "ceer", "output/BO6A-2024-12-24-2-56-33_ceer_sbs.txt"
)

missing <- files$path[!file.exists(files$path)]
if (length(missing) > 0) {
  stop("Missing frozen legacy SBS output(s): ", paste(missing, collapse = ", "))
}

# ////////////////////////////////////////////////////
#
#
# 4. Evaluate Preserved Outputs ----
#
#
# ////////////////////////////////////////////////////

evaluation <- purrr::pmap_dfr(
  files,
  function(entity_slug, path) {
    evaluate_output(
      path = path,
      entity_slug = entity_slug,
      technique = "Step-by-step (SBS)",
      questions = questions,
      human = human
    )
  }
)

metrics <- evaluation |>
  dplyr::group_by(.data$entity_slug) |>
  dplyr::group_modify(~ compute_metrics(.x)) |>
  dplyr::ungroup()

errors <- evaluation |>
  dplyr::filter(!.data$agreement)

# ////////////////////////////////////////////////////
#
#
# 5. Write Derived Outputs ----
#
#
# ////////////////////////////////////////////////////

derived_dir <- cfg$project$derived_dir
dir.create(derived_dir, recursive = TRUE, showWarnings = FALSE)

readr::write_csv(evaluation, file.path(derived_dir, "legacy_sbs_human_evaluation.csv"))
readr::write_csv(metrics, file.path(derived_dir, "legacy_sbs_human_metrics.csv"))
readr::write_csv(errors, file.path(derived_dir, "legacy_sbs_human_errors.csv"))

cat("Evaluated five frozen 2024 SBS outputs; API calls: NONE\n")
