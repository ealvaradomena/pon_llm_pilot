# ////////////////////////////////////////////////////
#
# Evaluate Preserved December 2024 Zero-Shot Outputs
#
# Purpose
# - Reconstruct the zero-shot baseline evaluation from preserved files
# - Never call the OpenAI API
# - Write derived tables outside the historical output set
#
# ////////////////////////////////////////////////////

# 1. Load Packages and Functions ----

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(tibble)
  library(yaml)
})

source("R/analysis.R")

# 2. Load Inputs ----

cfg <- yaml::read_yaml("config/config.yml")
questions <- readr::read_csv(
  cfg$project$questions_file,
  show_col_types = FALSE
)

human <- readr::read_csv(
  cfg$project$human_responses_file,
  show_col_types = FALSE
)

# 3. Register Preserved Final-Pipeline Zero-Shot Outputs ----

files <- tibble::tribble(
  ~entity_slug, ~path,
  "irg", "output/BO2A-2024-12-24-2-52-18_irg_z.txt",
  "euhc", "output/BO3A-2024-12-24-2-53-29_euhc_z.txt",
  "coas", "output/BO4A-2024-12-24-2-53-56_coas_z.txt",
  "can", "output/BO5A-2024-12-24-2-54-17_can_z.txt",
  "ceer", "output/BO6A-2024-12-24-2-54-38_ceer_z.txt"
)

# 4. Evaluate ----

evaluation <- purrr::pmap_dfr(
  files,
  function(entity_slug, path) {
    evaluate_output(
      path = path,
      entity_slug = entity_slug,
      technique = "Zero-shot",
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

# 5. Write Derived Outputs ----

derived_dir <- cfg$project$derived_dir
dir.create(derived_dir, recursive = TRUE, showWarnings = FALSE)

readr::write_csv(
  evaluation,
  file.path(derived_dir, "legacy_human_evaluation.csv")
)

readr::write_csv(
  metrics,
  file.path(derived_dir, "legacy_human_metrics.csv")
)

readr::write_csv(
  errors,
  file.path(derived_dir, "legacy_human_errors.csv")
)
