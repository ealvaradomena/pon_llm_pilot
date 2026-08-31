# ////////////////////////////////////////////////////
#
# PON LLM Pilot - Compare Legacy and Contemporary SBS Models
#
# Purpose:
# - Compare frozen 2024 GPT-4 Turbo SBS outputs with all configured contemporary SBS runs
# - Evaluate every model against the same confirmed human reference
# - Write comparison tables, diagnostics, flip audits, and agreement figures without API calls
#
# Requirements:
# - Project configuration in config/config.yml
# - Frozen legacy SBS outputs and one completed run for every comparison model
# - Confirmed human-reference and question CSV files
#
# AI Disclosure:
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-r-scripts.md
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
# 1. Load Configuration and Reference Data ----
#
#
# ////////////////////////////////////////////////////
cfg <- yaml::read_yaml("config/config.yml")
questions <- readr::read_csv(cfg$project$questions_file, show_col_types = FALSE)
human <- readr::read_csv(cfg$project$human_responses_file, show_col_types = FALSE)
study_entities <- unlist(cfg$comparison$study_entities)

comparison_models <- purrr::map_dfr(
  cfg$comparison$comparison_models,
  ~ tibble::as_tibble(.x)
) |>
  dplyr::transmute(
    model_id = as.character(.data$model_id),
    model = as.character(.data$label)
  )

if (nrow(comparison_models) < 1L || anyDuplicated(comparison_models$model_id)) {
  stop("comparison.comparison_models must contain at least one unique model_id")
}

# ////////////////////////////////////////////////////
#
#
# 2. Register Frozen Legacy SBS Sources ----
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
    source_type = "Frozen legacy",
    run_dir = NA_character_
  )

missing_legacy <- legacy_sources$path[!file.exists(legacy_sources$path)]
if (length(missing_legacy) > 0) {
  stop("Missing frozen legacy SBS output(s): ", paste(missing_legacy, collapse = ", "))
}

# ////////////////////////////////////////////////////
#
#
# 3. Locate One Completed Run for Each Contemporary Model ----
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
      ". Run scripts/03_run_current_model.py for that model first."
    )
  }
  matches[order(file.info(matches)$mtime, decreasing = TRUE)][1]
}

current_sources <- purrr::pmap_dfr(
  comparison_models,
  function(model_id, model) {
    run_dir <- find_current_run(model_id)
    files <- list.files(run_dir, pattern = "_sbs\\.txt$", full.names = TRUE)
    indexed <- tibble::tibble(path = files) |>
      dplyr::mutate(
        entity_slug = stringr::str_match(
          basename(.data$path),
          "^BO[0-9A-Za-z]+_([^_]+)_sbs\\.txt$"
        )[, 2]
      ) |>
      dplyr::filter(.data$entity_slug %in% study_entities)

    if (nrow(indexed) != length(study_entities)) {
      stop(
        sprintf(
          "Expected %s SBS PON outputs for %s in %s; found %s",
          length(study_entities), model_id, run_dir, nrow(indexed)
        )
      )
    }

    indexed |>
      dplyr::mutate(
        model = model,
        model_id = model_id,
        protocol = "2024 SBS",
        source_type = "New SBS run",
        run_dir = run_dir
      )
  }
)

sources <- dplyr::bind_rows(legacy_sources, current_sources)

# ////////////////////////////////////////////////////
#
#
# 4. Evaluate All Model Generations ----
#
#
# ////////////////////////////////////////////////////
model_evaluation <- purrr::pmap_dfr(
  sources,
  function(entity_slug, path, model, model_id, protocol, source_type, run_dir) {
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
        run_dir = run_dir,
        pon = pon_label(entity_slug)
      )
  }
)

expected_models <- 1L + nrow(comparison_models)
expected_questions <- nrow(questions)
expected_pons <- length(study_entities)
expected_per_model <- expected_questions * expected_pons
expected_rows <- expected_models * expected_per_model

if (nrow(model_evaluation) != expected_rows) {
  stop(
    sprintf(
      "Expected %s model-evaluation rows; found %s",
      expected_rows,
      nrow(model_evaluation)
    )
  )
}

model_counts <- model_evaluation |>
  dplyr::count(.data$model_id, name = "n")
if (nrow(model_counts) != expected_models ||
    any(model_counts$n != expected_per_model)) {
  stop(
    sprintf(
      "Expected %s decisions per model across %s models",
      expected_per_model,
      expected_models
    )
  )
}

model_pon_counts <- model_evaluation |>
  dplyr::count(.data$model_id, .data$entity_slug, name = "n")
if (nrow(model_pon_counts) != expected_models * expected_pons ||
    any(model_pon_counts$n != expected_questions)) {
  stop(sprintf("Expected %s decisions for every model/PON combination", expected_questions))
}

model_key_counts <- model_evaluation |>
  dplyr::count(.data$model_id, .data$entity_slug, .data$question_id, name = "n")
if (any(model_key_counts$n != 1L)) {
  stop("Model/PON/question keys are not unique")
}

if (any(is.na(model_evaluation$human_response))) {
  stop("Missing human-reference response in model evaluation")
}

metrics_by_pon <- model_evaluation |>
  dplyr::group_by(.data$model, .data$model_id, .data$entity_slug, .data$pon) |>
  dplyr::group_modify(~ compute_metrics(.x)) |>
  dplyr::ungroup()

overall_metrics <- model_evaluation |>
  dplyr::group_by(.data$model, .data$model_id) |>
  dplyr::group_modify(~ compute_metrics(.x)) |>
  dplyr::ungroup()

question_performance <- model_evaluation |>
  dplyr::group_by(.data$model, .data$model_id, .data$question_id, .data$question) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    agreements = sum(.data$agreement),
    agreement_rate = mean(.data$agreement),
    disagreements = sum(!.data$agreement),
    disagreement_rate = mean(!.data$agreement),
    .groups = "drop"
  )

response_prevalence <- model_evaluation |>
  dplyr::group_by(.data$model, .data$model_id) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    true_responses = sum(.data$llm_response == "TRUE"),
    false_responses = sum(.data$llm_response == "FALSE"),
    true_rate = mean(.data$llm_response == "TRUE"),
    .groups = "drop"
  )

# ////////////////////////////////////////////////////
#
#
# 5. Compare Each Contemporary Model Directly with Frozen GPT-4 Turbo ----
#
#
# ////////////////////////////////////////////////////
legacy_for_stability <- legacy_sources |>
  dplyr::select(entity_slug, legacy_path = path)

stability_long <- current_sources |>
  dplyr::select(
    entity_slug,
    comparison_model = model,
    comparison_model_id = model_id,
    current_path = path
  ) |>
  dplyr::inner_join(legacy_for_stability, by = "entity_slug") |>
  purrr::pmap_dfr(
    function(
      entity_slug,
      comparison_model,
      comparison_model_id,
      current_path,
      legacy_path
    ) {
      compare_model_outputs(
        legacy_path = legacy_path,
        current_path = current_path,
        entity_slug = entity_slug,
        protocol = "2024 SBS",
        questions = questions
      ) |>
        dplyr::mutate(
          pon = pon_label(entity_slug),
          comparison_model = comparison_model,
          comparison_model_id = comparison_model_id
        )
    }
  )

expected_pair_rows <- nrow(comparison_models) * expected_per_model
if (nrow(stability_long) != expected_pair_rows) {
  stop(
    sprintf(
      "Expected %s model-to-model stability rows; found %s",
      expected_pair_rows,
      nrow(stability_long)
    )
  )
}

stability_key_counts <- stability_long |>
  dplyr::count(.data$comparison_model_id, .data$entity_slug, .data$question_id, name = "n")
if (any(stability_key_counts$n != 1L)) {
  stop("Model-to-model PON/question keys are not unique")
}

legacy_evaluation <- model_evaluation |>
  dplyr::filter(.data$model_id == cfg$legacy_protocol$model_alias) |>
  dplyr::select(
    entity_slug, pon, question_id, question, human_response,
    legacy_response = llm_response
  )

flip_audit <- model_evaluation |>
  dplyr::filter(.data$model_id %in% comparison_models$model_id) |>
  dplyr::transmute(
    comparison_model = .data$model,
    comparison_model_id = .data$model_id,
    entity_slug = .data$entity_slug,
    question_id = .data$question_id,
    current_human_response = .data$human_response,
    current_response = .data$llm_response
  ) |>
  dplyr::inner_join(legacy_evaluation, by = c("entity_slug", "question_id")) |>
  dplyr::mutate(
    human_reference_match = .data$human_response == .data$current_human_response,
    changed = .data$legacy_response != .data$current_response,
    direction = dplyr::case_when(
      !.data$changed ~ "No change",
      .data$legacy_response != .data$human_response &
        .data$current_response == .data$human_response ~ "Toward human",
      .data$legacy_response == .data$human_response &
        .data$current_response != .data$human_response ~ "Away from human",
      TRUE ~ "Unresolved"
    )
  )

if (nrow(flip_audit) != expected_pair_rows) {
  stop(sprintf("Expected %s flip-audit rows; found %s", expected_pair_rows, nrow(flip_audit)))
}
if (any(!flip_audit$human_reference_match)) {
  stop("Human-reference values differ between model generations")
}

if (any(flip_audit$direction == "Unresolved")) {
  stop("Encountered an unresolved model-flip direction")
}

flip_counts <- flip_audit |>
  dplyr::group_by(.data$comparison_model_id) |>
  dplyr::summarise(changed = sum(.data$changed), .groups = "drop")
stability_change_counts <- stability_long |>
  dplyr::group_by(.data$comparison_model_id) |>
  dplyr::summarise(changed = sum(!.data$agreement), .groups = "drop")
if (!identical(
  dplyr::arrange(flip_counts, .data$comparison_model_id),
  dplyr::arrange(stability_change_counts, .data$comparison_model_id)
)) {
  stop("Flip audit and direct model-stability comparison disagree")
}

stability_by_pon <- stability_long |>
  dplyr::group_by(
    .data$comparison_model,
    .data$comparison_model_id,
    .data$entity_slug,
    .data$pon
  ) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    same = sum(.data$agreement),
    changed = sum(!.data$agreement),
    agreement_rate = mean(.data$agreement),
    .groups = "drop"
  )

stability_overall <- stability_long |>
  dplyr::group_by(.data$comparison_model, .data$comparison_model_id) |>
  dplyr::summarise(
    decisions = dplyr::n(),
    same = sum(.data$agreement),
    changed = sum(!.data$agreement),
    agreement_rate = mean(.data$agreement),
    .groups = "drop"
  )

format_diagnostics <- purrr::pmap_dfr(
  current_sources |>
    dplyr::select(path, model, model_id),
  function(path, model, model_id) {
    diagnose_llm_output(path, questions = questions) |>
      dplyr::mutate(model = model, model_id = model_id)
  }
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
readr::write_csv(flip_audit, file.path(derived_dir, "sbs_model_flip_audit.csv"))
readr::write_csv(format_diagnostics, file.path(derived_dir, "sbs_output_format_diagnostics.csv"))

p_pon <- ggplot2::ggplot(
  metrics_by_pon,
  ggplot2::aes(x = .data$pon, y = .data$accuracy, fill = .data$model)
) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.7) +
  ggplot2::scale_y_continuous(limits = c(0, 1), labels = scales::label_percent()) +
  ggplot2::labs(x = NULL, y = "Agreement with human reference", fill = "Model") +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "top", panel.grid.minor = ggplot2::element_blank())

ggplot2::ggsave(
  file.path(figure_dir, "sbs_model_agreement_by_pon.png"),
  p_pon, width = 8.6, height = 5, dpi = 180
)

p_question <- ggplot2::ggplot(
  question_performance,
  ggplot2::aes(x = factor(.data$question_id), y = .data$agreement_rate, fill = .data$model)
) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.7) +
  ggplot2::scale_y_continuous(limits = c(0, 1), labels = scales::label_percent()) +
  ggplot2::labs(
    x = "Computational question ID",
    y = "Agreement with human reference",
    fill = "Model"
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "top", panel.grid.minor = ggplot2::element_blank())

ggplot2::ggsave(
  file.path(figure_dir, "sbs_model_question_agreement.png"),
  p_question, width = 9.4, height = 5.4, dpi = 180
)

cat("Compared frozen 2024 GPT-4 Turbo SBS with configured contemporary SBS models\n")
cat(sprintf("Models: %s\n", paste(c("GPT-4 Turbo", comparison_models$model), collapse = ", ")))
cat(sprintf("PONs: %s\n", length(study_entities)))
cat(sprintf("Questions per PON: %s\n", nrow(questions)))
for (model_id in comparison_models$model_id) {
  run_dir <- unique(current_sources$run_dir[current_sources$model_id == model_id])
  cat(sprintf("Run for %s: %s\n", model_id, run_dir))
}
cat(sprintf("Derived files written to %s\n", derived_dir))
cat("API calls: NONE\n")
# FINAL OUTPUT LINE
