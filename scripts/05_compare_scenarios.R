# ////////////////////////////////////////////////////
#
# Compare Six Zero-Shot Model/Protocol Scenarios
#
# Purpose
# - Compare three model arms under the preserved 2024 and improved protocols
# - Use the same five PONs and 15 questions in every scenario
# - Evaluate each scenario against the recovered human reference
# - Estimate protocol effects within models and model effects within protocols
# - Compare pairwise model stability under each protocol
# - Save auditable tables and figures for the Quarto report
#
# Usage
# - Rscript scripts/05_compare_scenarios.R
#
# ////////////////////////////////////////////////////

# 1. Load Packages and Functions ----

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(jsonlite)
  library(purrr)
  library(readr)
  library(stringr)
  library(tibble)
  library(tidyr)
  library(yaml)
})

source("R/analysis.R")

# 2. Load Configuration and Reference Data ----

cfg <- yaml::read_yaml("config/config.yml")
study_entities <- unlist(cfg$comparison$study_entities, use.names = FALSE)

questions <- readr::read_csv(
  cfg$project$questions_file,
  show_col_types = FALSE
)

legacy_runs <- readr::read_csv(
  cfg$project$legacy_runs_file,
  show_col_types = FALSE
)

human <- readr::read_csv(
  cfg$project$human_responses_file,
  show_col_types = FALSE
)

model_registry <- tibble::tribble(
  ~model, ~model_id,
  "GPT-4 Turbo", cfg$comparison$legacy_model,
  "GPT-5.4 nano", cfg$comparison$current_model,
  "GPT-5.4 mini", cfg$comparison$mini_model
)

# 3. Resolve Completed Runs by Exact Model ID ----

read_manifest_if_complete <- function(run_dir, manifest_name) {
  manifest_path <- file.path(run_dir, manifest_name)

  if (!file.exists(manifest_path)) {
    return(NULL)
  }

  manifest <- jsonlite::fromJSON(manifest_path)

  if (!is.null(manifest$status) && !identical(manifest$status, "complete")) {
    return(NULL)
  }

  manifest
}

find_current_run <- function(model_id) {
  candidates <- list.dirs(
    cfg$project$current_output_dir,
    recursive = FALSE,
    full.names = TRUE
  )

  matches <- purrr::keep(
    candidates,
    function(run_dir) {
      manifest <- read_manifest_if_complete(run_dir, "run_manifest.json")

      !is.null(manifest) &&
        identical(manifest$requested_model, model_id)
    }
  )

  if (length(matches) == 0) {
    stop(sprintf("No completed 2024-protocol run found for model '%s'", model_id))
  }

  matches[order(file.info(matches)$mtime, decreasing = TRUE)][1]
}

find_improved_single_run <- function(model_id) {
  candidates <- list.dirs(
    cfg$project$improved_output_dir,
    recursive = FALSE,
    full.names = TRUE
  )

  matches <- purrr::keep(
    candidates,
    function(run_dir) {
      manifest <- read_manifest_if_complete(run_dir, "run_manifest.json")

      !is.null(manifest) &&
        identical(manifest$requested_model, model_id) &&
        identical(manifest$protocol, cfg$improved_protocol$name)
    }
  )

  if (length(matches) == 0) {
    return(NULL)
  }

  matches[order(file.info(matches)$mtime, decreasing = TRUE)][1]
}

find_improved_batch_model <- function(model_id) {
  batch_dirs <- list.dirs(
    cfg$project$improved_output_dir,
    recursive = FALSE,
    full.names = TRUE
  )

  rows <- purrr::map_dfr(
    batch_dirs,
    function(batch_dir) {
      manifest_path <- file.path(batch_dir, "batch_manifest.json")

      if (!file.exists(manifest_path)) {
        return(tibble::tibble())
      }

      manifest <- jsonlite::fromJSON(manifest_path)

      if (!is.null(manifest$status) && !identical(manifest$status, "complete")) {
        return(tibble::tibble())
      }

      models <- manifest$models

      if (
        is.null(models) ||
        !all(c("requested_model", "run_dir") %in% names(models))
      ) {
        return(tibble::tibble())
      }

      models |>
        dplyr::filter(.data$requested_model == .env$model_id) |>
        dplyr::transmute(
          batch_dir = batch_dir,
          run_dir = .data$run_dir
        )
    }
  )

  if (nrow(rows) == 0) {
    return(NULL)
  }

  rows |>
    dplyr::mutate(
      mtime = file.info(.data$batch_dir)$mtime
    ) |>
    dplyr::arrange(dplyr::desc(.data$mtime)) |>
    dplyr::slice(1) |>
    dplyr::pull(.data$run_dir)
}

resolve_improved_run <- function(model_id) {
  single_run <- find_improved_single_run(model_id)

  if (!is.null(single_run)) {
    return(single_run)
  }

  batch_run <- find_improved_batch_model(model_id)

  if (!is.null(batch_run)) {
    return(batch_run)
  }

  stop(sprintf("No completed improved-protocol run found for model '%s'", model_id))
}

# 4. Register Six Scenarios ----

legacy_zero <- legacy_runs |>
  dplyr::filter(
    .data$technique_code == "z",
    .data$strict_protocol_match,
    .data$entity_slug %in% study_entities
  ) |>
  dplyr::transmute(
    entity_slug = .data$entity_slug,
    path = .data$legacy_output,
    model = "GPT-4 Turbo",
    model_id = .data$legacy_model,
    protocol = "2024 protocol",
    scenario = "GPT-4 Turbo / 2024 protocol"
  )

index_run <- function(run_dir, model_label, model_id, protocol_label) {
  files <- list.files(
    run_dir,
    pattern = "_z\\.txt$",
    full.names = TRUE
  )

  indexed <- tibble::tibble(path = files) |>
    dplyr::mutate(
      entity_slug = stringr::str_match(
        basename(.data$path),
        "^BO[0-9A-Za-z]+_([^_]+)_z\\.txt$"
      )[, 2]
    ) |>
    dplyr::filter(.data$entity_slug %in% study_entities) |>
    dplyr::transmute(
      entity_slug = .data$entity_slug,
      path = .data$path,
      model = model_label,
      model_id = model_id,
      protocol = protocol_label,
      scenario = paste0(model_label, " / ", protocol_label)
    )

  if (nrow(indexed) != length(study_entities)) {
    stop(
      sprintf(
        "Expected %s PON outputs for %s / %s; found %s",
        length(study_entities),
        model_label,
        protocol_label,
        nrow(indexed)
      )
    )
  }

  indexed
}

nano_2024 <- index_run(
  find_current_run(cfg$comparison$current_model),
  "GPT-5.4 nano",
  cfg$comparison$current_model,
  "2024 protocol"
)

mini_2024 <- index_run(
  find_current_run(cfg$comparison$mini_model),
  "GPT-5.4 mini",
  cfg$comparison$mini_model,
  "2024 protocol"
)

turbo_improved <- index_run(
  resolve_improved_run(cfg$comparison$legacy_model),
  "GPT-4 Turbo",
  cfg$comparison$legacy_model,
  "Improved protocol"
)

nano_improved <- index_run(
  resolve_improved_run(cfg$comparison$current_model),
  "GPT-5.4 nano",
  cfg$comparison$current_model,
  "Improved protocol"
)

mini_improved <- index_run(
  resolve_improved_run(cfg$comparison$mini_model),
  "GPT-5.4 mini",
  cfg$comparison$mini_model,
  "Improved protocol"
)

scenario_sources <- dplyr::bind_rows(
  legacy_zero,
  nano_2024,
  mini_2024,
  turbo_improved,
  nano_improved,
  mini_improved
)

expected_sources <- 6 * length(study_entities)

if (nrow(scenario_sources) != expected_sources) {
  stop(
    sprintf(
      "Expected %s scenario/PON source files; found %s",
      expected_sources,
      nrow(scenario_sources)
    )
  )
}

# 5. Evaluate All Scenarios Against the Human Reference ----

scenario_evaluation <- purrr::pmap_dfr(
  scenario_sources,
  function(entity_slug, path, model, model_id, protocol, scenario) {
    evaluate_output(
      path = path,
      entity_slug = entity_slug,
      technique = "Zero-shot",
      questions = questions,
      human = human
    ) |>
      dplyr::mutate(
        model = model,
        model_id = model_id,
        protocol = protocol,
        scenario = scenario,
        pon = pon_label(entity_slug)
      )
  }
)

scenario_metrics <- scenario_evaluation |>
  dplyr::group_by(
    .data$model,
    .data$model_id,
    .data$protocol,
    .data$scenario,
    .data$entity_slug,
    .data$pon
  ) |>
  dplyr::group_modify(~ compute_metrics(.x)) |>
  dplyr::ungroup()

scenario_overall <- scenario_evaluation |>
  dplyr::group_by(
    .data$model,
    .data$model_id,
    .data$protocol,
    .data$scenario
  ) |>
  dplyr::group_modify(~ compute_metrics(.x)) |>
  dplyr::ungroup()

question_performance <- scenario_evaluation |>
  dplyr::group_by(
    .data$model,
    .data$protocol,
    .data$question_id,
    .data$question
  ) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    disagreements = sum(!.data$agreement),
    disagreement_rate = mean(!.data$agreement),
    .groups = "drop"
  )

response_prevalence <- scenario_evaluation |>
  dplyr::group_by(
    .data$model,
    .data$protocol
  ) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    true_responses = sum(.data$llm_response == "TRUE"),
    false_responses = sum(.data$llm_response == "FALSE"),
    true_rate = mean(.data$llm_response == "TRUE"),
    .groups = "drop"
  )

# 6. Estimate Protocol and Model Effects ----

protocol_effects <- scenario_metrics |>
  dplyr::select(
    .data$model,
    .data$entity_slug,
    .data$pon,
    .data$protocol,
    .data$accuracy
  ) |>
  tidyr::pivot_wider(
    names_from = "protocol",
    values_from = "accuracy"
  ) |>
  dplyr::mutate(
    accuracy_change = .data$`Improved protocol` - .data$`2024 protocol`
  )

model_effects <- scenario_metrics |>
  dplyr::select(
    .data$protocol,
    .data$entity_slug,
    .data$pon,
    .data$model,
    .data$accuracy
  ) |>
  tidyr::pivot_wider(
    names_from = "model",
    values_from = "accuracy"
  ) |>
  dplyr::mutate(
    nano_vs_turbo = .data$`GPT-5.4 nano` - .data$`GPT-4 Turbo`,
    mini_vs_turbo = .data$`GPT-5.4 mini` - .data$`GPT-4 Turbo`,
    mini_vs_nano = .data$`GPT-5.4 mini` - .data$`GPT-5.4 nano`
  )

# 7. Compare Pairwise Model Stability Within Each Protocol ----

build_pairwise_stability <- function(protocol_label) {
  sources <- scenario_sources |>
    dplyr::filter(.data$protocol == .env$protocol_label)

  model_pairs <- tibble::tribble(
    ~model_a, ~model_b,
    "GPT-4 Turbo", "GPT-5.4 nano",
    "GPT-4 Turbo", "GPT-5.4 mini",
    "GPT-5.4 nano", "GPT-5.4 mini"
  )

  purrr::pmap_dfr(
    model_pairs,
    function(model_a, model_b) {
      left <- sources |>
        dplyr::filter(.data$model == .env$model_a) |>
        dplyr::select(
          .data$entity_slug,
          path_a = .data$path
        )

      right <- sources |>
        dplyr::filter(.data$model == .env$model_b) |>
        dplyr::select(
          .data$entity_slug,
          path_b = .data$path
        )

      left |>
        dplyr::inner_join(right, by = "entity_slug") |>
        purrr::pmap_dfr(
          function(entity_slug, path_a, path_b) {
            compare_model_outputs(
              legacy_path = path_a,
              current_path = path_b,
              entity_slug = entity_slug,
              protocol = protocol_label,
              questions = questions
            ) |>
              dplyr::mutate(
                model_a = model_a,
                model_b = model_b,
                model_pair = paste(model_a, "vs", model_b)
              )
          }
        )
    }
  )
}

stability_long <- dplyr::bind_rows(
  build_pairwise_stability("2024 protocol"),
  build_pairwise_stability("Improved protocol")
)

stability_summary <- stability_long |>
  dplyr::group_by(
    .data$protocol,
    .data$model_pair,
    .data$model_a,
    .data$model_b,
    .data$entity_slug
  ) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    same = sum(.data$agreement),
    changed = sum(!.data$agreement),
    agreement_rate = mean(.data$agreement),
    .groups = "drop"
  ) |>
  dplyr::mutate(pon = pon_label(.data$entity_slug))

stability_overall <- stability_long |>
  dplyr::group_by(
    .data$protocol,
    .data$model_pair,
    .data$model_a,
    .data$model_b
  ) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    same = sum(.data$agreement),
    changed = sum(!.data$agreement),
    agreement_rate = mean(.data$agreement),
    .groups = "drop"
  )

# 8. Diagnose Newly Generated Output Formatting ----

new_output_files <- scenario_sources |>
  dplyr::filter(
    !(
      .data$model == "GPT-4 Turbo" &
        .data$protocol == "2024 protocol"
    )
  ) |>
  dplyr::pull(.data$path)

format_diagnostics <- purrr::map_dfr(
  new_output_files,
  diagnose_llm_output,
  questions = questions
)

# 9. Write Derived Tables ----

derived_dir <- cfg$project$derived_dir
figure_dir <- file.path(derived_dir, "figures")

dir.create(derived_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

readr::write_csv(
  scenario_sources,
  file.path(derived_dir, "scenario_sources.csv")
)

readr::write_csv(
  scenario_evaluation,
  file.path(derived_dir, "scenario_evaluation_long.csv")
)

readr::write_csv(
  scenario_metrics,
  file.path(derived_dir, "scenario_metrics_by_pon.csv")
)

readr::write_csv(
  scenario_overall,
  file.path(derived_dir, "scenario_metrics_overall.csv")
)

readr::write_csv(
  question_performance,
  file.path(derived_dir, "scenario_question_performance.csv")
)

readr::write_csv(
  response_prevalence,
  file.path(derived_dir, "scenario_response_prevalence.csv")
)

readr::write_csv(
  protocol_effects,
  file.path(derived_dir, "protocol_effects.csv")
)

readr::write_csv(
  model_effects,
  file.path(derived_dir, "model_effects.csv")
)

readr::write_csv(
  stability_summary,
  file.path(derived_dir, "model_stability_by_pon.csv")
)

readr::write_csv(
  stability_overall,
  file.path(derived_dir, "model_stability_overall.csv")
)

readr::write_csv(
  format_diagnostics,
  file.path(derived_dir, "output_format_diagnostics.csv")
)

# 10. Save Figures ----

ggplot2::ggsave(
  file.path(figure_dir, "scenario_disagreement_by_pon.png"),
  plot_scenario_disagreement(scenario_metrics),
  width = 8.6,
  height = 5,
  dpi = 180
)

ggplot2::ggsave(
  file.path(figure_dir, "scenario_question_disagreement.png"),
  plot_question_disagreement(question_performance),
  width = 9.4,
  height = 5.4,
  dpi = 180
)

cat("Compared six zero-shot model/protocol scenarios\n")
cat("Models: GPT-4 Turbo, GPT-5.4 nano, GPT-5.4 mini\n")
cat("Protocols: 2024 protocol, Improved protocol\n")
cat(sprintf("PONs per scenario: %s\n", length(study_entities)))
cat(sprintf("Derived files written to %s\n", derived_dir))
