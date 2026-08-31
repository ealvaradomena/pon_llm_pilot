# ////////////////////////////////////////////////////
#
#
# PON LLM Pilot - Compare Legacy and Newer SBS Models
#
# Purpose:
# - Compare frozen 2024 GPT-4 Turbo SBS outputs with the newer-model SBS run
# - Evaluate both generations against the confirmed human reference
# - Write model-comparison tables, diagnostics, and figures without API calls
#
# Requirements:
# - Project configuration in config/config.yml
# - Frozen legacy SBS outputs and a completed current-model SBS run
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
  library(ggplot2)
  library(jsonlite)
  library(purrr)
  library(readr)
  library(scales)
  library(stringr)
  library(tibble)
  library(tidyr)
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
study_entities <- unlist(cfg$comparison$study_entities)
current_model_id <- cfg$comparison$current_model

# ////////////////////////////////////////////////////
#
#
# 3. Register Frozen Legacy SBS Sources ----
#
#
# ////////////////////////////////////////////////////

legacy_sources <- tibble::tribble(
  ~entity_slug, ~path,
  "irg",  "output/BO2A-2024-12-24-2-55-3_irg_sbs.txt",
  "euhc", "output/BO3A-2024-12-24-2-55-18_euhc_sbs.txt",
  "coas", "output/BO4A-2024-12-24-2-55-51_coas_sbs.txt",
  "can",  "output/BO5A-2024-12-24-2-56-12_can_sbs.txt",
  "ceer", "output/BO6A-2024-12-24-2-56-33_ceer_sbs.txt"
) |>
  dplyr::mutate(
    model = "GPT-4 Turbo (2024 legacy)",
    model_id = cfg$legacy_protocol$model_alias,
    protocol = "2024 SBS",
    source_type = "Frozen legacy"
  )

missing_legacy <- legacy_sources$path[!file.exists(legacy_sources$path)]
if (length(missing_legacy) > 0) {
  stop("Missing frozen legacy SBS output(s): ", paste(missing_legacy, collapse = ", "))
}

# ////////////////////////////////////////////////////
#
#
# 4. Locate the Completed Newer-Model SBS Run ----
#
#
# ////////////////////////////////////////////////////

find_current_run <- function(model_id) {
  root <- cfg$project$current_output_dir
  if (!dir.exists(root)) {
    stop("Current-output directory does not exist: ", root)
  }
  dirs <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  matches <- purrr::keep(dirs, function(run_dir) {
    manifest_path <- file.path(run_dir, "run_manifest.json")
    if (!file.exists(manifest_path)) return(FALSE)
    manifest <- jsonlite::fromJSON(manifest_path)
    identical(manifest$status, "complete") &&
      identical(manifest$protocol, "2024-sbs") &&
      identical(manifest$requested_model, model_id)
  })
  if (length(matches) == 0) {
    stop(
      "No completed current-model SBS run found for ", model_id,
      ". Run scripts/03_run_current_model.py first."
    )
  }
  matches[order(file.info(matches)$mtime, decreasing = TRUE)][1]
}

`%||%` <- function(x, y) if (is.null(x)) y else x

current_run <- find_current_run(current_model_id)
current_files <- list.files(current_run, pattern = "_sbs\\.txt$", full.names = TRUE)

current_sources <- tibble::tibble(path = current_files) |>
  dplyr::mutate(
    entity_slug = stringr::str_match(
      basename(.data$path),
      "^BO[0-9A-Za-z]+_([^_]+)_sbs\\.txt$"
    )[, 2]
  ) |>
  dplyr::filter(.data$entity_slug %in% study_entities) |>
  dplyr::mutate(
    model = "GPT-5.4 nano",
    model_id = current_model_id,
    protocol = "2024 SBS",
    source_type = "New SBS run"
  )

if (nrow(current_sources) != length(study_entities)) {
  stop(
    sprintf(
      "Expected %s current SBS PON outputs in %s; found %s",
      length(study_entities), current_run, nrow(current_sources)
    )
  )
}

sources <- dplyr::bind_rows(legacy_sources, current_sources)

# ////////////////////////////////////////////////////
#
#
# 5. Evaluate Both Model Generations ----
#
#
# ////////////////////////////////////////////////////

model_evaluation <- purrr::pmap_dfr(
  sources,
  function(entity_slug, path, model, model_id, protocol, source_type) {
    evaluate_output(
      path = path,
      entity_slug = entity_slug,
      technique = "Step-by-step (SBS)",
      questions = questions,
      human = human
    ) |>
      dplyr::mutate(
        model = model,
        model_id = model_id,
        protocol = protocol,
        source_type = source_type,
        pon = pon_label(entity_slug)
      )
  }
)

metrics_by_pon <- model_evaluation |>
  dplyr::group_by(.data$model, .data$model_id, .data$entity_slug, .data$pon) |>
  dplyr::group_modify(~ compute_metrics(.x)) |>
  dplyr::ungroup()

overall_metrics <- model_evaluation |>
  dplyr::group_by(.data$model, .data$model_id) |>
  dplyr::group_modify(~ compute_metrics(.x)) |>
  dplyr::ungroup()

question_performance <- model_evaluation |>
  dplyr::group_by(.data$model, .data$question_id, .data$question) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    disagreements = sum(!.data$agreement),
    disagreement_rate = mean(!.data$agreement),
    .groups = "drop"
  )

response_prevalence <- model_evaluation |>
  dplyr::group_by(.data$model) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    true_responses = sum(.data$llm_response == "TRUE"),
    false_responses = sum(.data$llm_response == "FALSE"),
    true_rate = mean(.data$llm_response == "TRUE"),
    .groups = "drop"
  )

legacy_for_stability <- legacy_sources |>
  dplyr::select(.data$entity_slug, legacy_path = .data$path)
current_for_stability <- current_sources |>
  dplyr::select(.data$entity_slug, current_path = .data$path)

stability_long <- legacy_for_stability |>
  dplyr::inner_join(current_for_stability, by = "entity_slug") |>
  purrr::pmap_dfr(function(entity_slug, legacy_path, current_path) {
    compare_model_outputs(
      legacy_path = legacy_path,
      current_path = current_path,
      entity_slug = entity_slug,
      protocol = "2024 SBS",
      questions = questions
    ) |>
      dplyr::mutate(pon = pon_label(entity_slug))
  })

stability_by_pon <- stability_long |>
  dplyr::group_by(.data$entity_slug, .data$pon) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    same = sum(.data$agreement),
    changed = sum(!.data$agreement),
    agreement_rate = mean(.data$agreement),
    .groups = "drop"
  )

stability_overall <- stability_long |>
  dplyr::summarise(
    decisions = dplyr::n(),
    same = sum(.data$agreement),
    changed = sum(!.data$agreement),
    agreement_rate = mean(.data$agreement)
  )

format_diagnostics <- purrr::map_dfr(
  current_sources$path,
  diagnose_llm_output,
  questions = questions
)

# ////////////////////////////////////////////////////
#
#
# 6. Write Comparison Outputs ----
#
#
# ////////////////////////////////////////////////////

derived_dir <- cfg$project$derived_dir
figure_dir <- file.path(derived_dir, "figures")
dir.create(derived_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

readr::write_csv(sources, file.path(derived_dir, "sbs_model_sources.csv"))
readr::write_csv(model_evaluation, file.path(derived_dir, "sbs_model_evaluation_long.csv"))
readr::write_csv(metrics_by_pon, file.path(derived_dir, "sbs_model_metrics_by_pon.csv"))
readr::write_csv(overall_metrics, file.path(derived_dir, "sbs_model_metrics_overall.csv"))
readr::write_csv(question_performance, file.path(derived_dir, "sbs_model_question_performance.csv"))
readr::write_csv(response_prevalence, file.path(derived_dir, "sbs_model_response_prevalence.csv"))
readr::write_csv(stability_by_pon, file.path(derived_dir, "sbs_model_stability_by_pon.csv"))
readr::write_csv(stability_overall, file.path(derived_dir, "sbs_model_stability_overall.csv"))
readr::write_csv(format_diagnostics, file.path(derived_dir, "sbs_output_format_diagnostics.csv"))

p_pon <- ggplot2::ggplot(
  metrics_by_pon,
  ggplot2::aes(x = .data$pon, y = .data$disagreement_rate, group = .data$model, color = .data$model)
) +
  ggplot2::geom_line() +
  ggplot2::geom_point(size = 3) +
  ggplot2::scale_y_continuous(limits = c(0, 1), labels = scales::label_percent()) +
  ggplot2::labs(x = NULL, y = "Share disagreeing with human majority/reference", color = "Model") +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "top", panel.grid.minor = ggplot2::element_blank())

ggplot2::ggsave(
  file.path(figure_dir, "sbs_model_disagreement_by_pon.png"),
  p_pon, width = 8.6, height = 5, dpi = 180
)

p_question <- ggplot2::ggplot(
  question_performance,
  ggplot2::aes(x = factor(.data$question_id), y = .data$disagreement_rate, group = .data$model, color = .data$model)
) +
  ggplot2::geom_line() +
  ggplot2::geom_point() +
  ggplot2::scale_y_continuous(limits = c(0, 1), labels = scales::label_percent()) +
  ggplot2::labs(x = "Computational question ID", y = "Share disagreeing with human reference", color = "Model") +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "top", panel.grid.minor = ggplot2::element_blank())

ggplot2::ggsave(
  file.path(figure_dir, "sbs_model_question_disagreement.png"),
  p_question, width = 9.4, height = 5.4, dpi = 180
)

cat("Compared frozen 2024 GPT-4 Turbo SBS with newer GPT-5.4 nano SBS\n")
cat(sprintf("PONs: %s\n", length(study_entities)))
cat(sprintf("Questions per PON: %s\n", nrow(questions)))
cat(sprintf("Current run: %s\n", current_run))
cat(sprintf("Derived files written to %s\n", derived_dir))
cat("API calls: NONE\n")
