# ////////////////////////////////////////////////////
#
#
# PON LLM Pilot - Reconstruct Manuscript Table A5
#
# Purpose:
# - Reconstruct the historical four-coder table from HBM, ASC, JNG, and frozen legacy SBS responses
# - Compare the reconstruction with the manuscript Table A5 transcription
# - Extend the audit with the configured GPT-5.4 nano SBS responses when available
#
# Requirements:
# - Project configuration in config/config.yml
# - Confirmed human-reference data and manuscript Table A5 transcription
# - Frozen 2024 *_sbs.txt outputs for the five comparative PONs
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
  library(jsonlite)
  library(purrr)
  library(readr)
  library(stringr)
  library(tibble)
  library(yaml)
})

source("R/analysis.R")

# ////////////////////////////////////////////////////
#
#
# 2. Load Configuration and Audit Inputs ----
#
#
# ////////////////////////////////////////////////////

cfg <- yaml::read_yaml("config/config.yml")
questions <- readr::read_csv(cfg$project$questions_file, show_col_types = FALSE)
human <- readr::read_csv(cfg$project$human_responses_file, show_col_types = FALSE)
manuscript <- readr::read_csv(
  "input/reference/manuscript_table_a5.csv",
  show_col_types = FALSE
)

study_entities <- unlist(cfg$comparison$study_entities)
excluded_id <- as.integer(cfg$comparison$manuscript_excluded_question_id)

# ////////////////////////////////////////////////////
#
#
# 3. Standardize Human Responses ----
#
#
# ////////////////////////////////////////////////////

as_tf <- function(x) {
  x <- toupper(as.character(x))
  dplyr::case_when(
    x %in% c("TRUE", "1", "YES") ~ "TRUE",
    x %in% c("FALSE", "0", "NO") ~ "FALSE",
    TRUE ~ NA_character_
  )
}

required_human_columns <- c(
  "question_id", "question", "entity_slug",
  "coding_brint", "coding_angel", "coding_juan"
)
missing_human_columns <- setdiff(required_human_columns, names(human))
if (length(missing_human_columns) > 0) {
  stop(
    "Confirmed human file is missing required columns: ",
    paste(missing_human_columns, collapse = ", ")
  )
}

human_long <- human |>
  dplyr::filter(.data$entity_slug %in% study_entities) |>
  dplyr::transmute(
    entity_slug = .data$entity_slug,
    question_id = as.integer(.data$question_id),
    question = .data$question,
    HBM = as_tf(.data$coding_brint),
    ASC = as_tf(.data$coding_angel),
    JNG = as_tf(.data$coding_juan)
  )

stopifnot(nrow(human_long) == length(study_entities) * nrow(questions))
stopifnot(!any(is.na(human_long[c("HBM", "ASC", "JNG")])))

# ////////////////////////////////////////////////////
#
#
# 4. Reconstruct the Historical Four-Coder Data ----
#
#
# ////////////////////////////////////////////////////

legacy_files <- tibble::tribble(
  ~entity_slug, ~path,
  "irg",  "output/BO2A-2024-12-24-2-55-3_irg_sbs.txt",
  "euhc", "output/BO3A-2024-12-24-2-55-18_euhc_sbs.txt",
  "coas", "output/BO4A-2024-12-24-2-55-51_coas_sbs.txt",
  "can",  "output/BO5A-2024-12-24-2-56-12_can_sbs.txt",
  "ceer", "output/BO6A-2024-12-24-2-56-33_ceer_sbs.txt"
)

missing_legacy <- legacy_files$path[!file.exists(legacy_files$path)]
if (length(missing_legacy) > 0) {
  stop("Missing frozen legacy SBS output(s): ", paste(missing_legacy, collapse = ", "))
}

legacy_llm <- purrr::pmap_dfr(
  legacy_files,
  function(entity_slug, path) {
    parse_llm_output(
      path = path,
      questions = questions,
      response_name = "legacy_llm_sbs"
    ) |>
      dplyr::mutate(entity_slug = entity_slug) |>
      dplyr::select(.data$entity_slug, .data$question_id, .data$legacy_llm_sbs)
  }
)

# ////////////////////////////////////////////////////
#
#
# 5. Extend with the Configured GPT-5.4 Nano SBS Model ----
#
#
# ////////////////////////////////////////////////////

find_latest_current_sbs_run <- function(model_id) {
  root <- cfg$project$current_output_dir

  # Return no candidate when the configured current-output root is absent
  if (!dir.exists(root)) {
    return(NULL)
  }

  dirs <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  matches <- purrr::keep(dirs, function(run_dir) {
    manifest_path <- file.path(run_dir, "run_manifest.json")

    # Ignore incomplete directories that do not contain a completion manifest
    if (!file.exists(manifest_path)) {
      return(FALSE)
    }

    manifest <- jsonlite::fromJSON(manifest_path)
    identical(manifest$status, "complete") &&
      identical(manifest$protocol, "2024-sbs") &&
      identical(manifest$requested_model, model_id)
  })

  # Return no candidate when the configured GPT-5.4 nano arm is unavailable
  if (length(matches) == 0) {
    return(NULL)
  }

  matches[order(file.info(matches)$mtime, decreasing = TRUE)][1]
}

new_run <- find_latest_current_sbs_run(cfg$comparison$current_model)
new_llm <- NULL
if (!is.null(new_run)) {
  new_files <- list.files(new_run, pattern = "_sbs\\.txt$", full.names = TRUE)
  indexed <- tibble::tibble(path = new_files) |>
    dplyr::mutate(
      entity_slug = stringr::str_match(
        basename(.data$path),
        "^BO[0-9A-Za-z]+_([^_]+)_sbs\\.txt$"
      )[, 2]
    ) |>
    dplyr::filter(.data$entity_slug %in% study_entities)

  if (nrow(indexed) != length(study_entities)) {
    stop("Latest current SBS run is incomplete: ", new_run)
  }

  new_llm <- purrr::pmap_dfr(
    indexed,
    function(path, entity_slug) {
      parse_llm_output(
        path = path,
        questions = questions,
        response_name = "new_llm_sbs"
      ) |>
        dplyr::mutate(entity_slug = entity_slug) |>
        dplyr::select(.data$entity_slug, .data$question_id, .data$new_llm_sbs)
    }
  )
}

count_label <- function(values) {
  n_true <- sum(values == "TRUE")
  n_false <- sum(values == "FALSE")
  sprintf("%s TRUE / %s FALSE", n_true, n_false)
}

manuscript_code <- function(HBM, ASC, JNG, legacy) {
  values <- c(HBM, ASC, JNG, legacy)
  n_true <- sum(values == "TRUE")
  if (n_true == 4) {
    return("1")
  }

  if (n_true == 0) {
    return("0")
  }

  if (n_true == 2) {
    return("2-2")
  }

  human_unanimous <- length(unique(c(HBM, ASC, JNG))) == 1

  if (human_unanimous && legacy != HBM) {
    return("3-1*")
  }

  "3-1"
}

dissenting_coder <- function(HBM, ASC, JNG, legacy) {
  values <- c(HBM = HBM, ASC = ASC, JNG = JNG, legacy_llm = legacy)
  tab <- table(values)
  if (length(tab) != 2 || !any(tab == 1)) return(NA_character_)
  minority <- names(tab)[tab == 1]
  names(values)[values == minority]
}

historical <- human_long |>
  dplyr::left_join(legacy_llm, by = c("entity_slug", "question_id")) |>
  dplyr::rowwise() |>
  dplyr::mutate(
    human_majority = ifelse(
      sum(c_across(c(HBM, ASC, JNG)) == "TRUE") >= 2,
      "TRUE", "FALSE"
    ),
    human_agreement = count_label(c_across(c(HBM, ASC, JNG))),
    legacy_llm_agrees_human_majority = .data$legacy_llm_sbs == .data$human_majority,
    historical_four_coder_pattern = count_label(
      c_across(c(HBM, ASC, JNG, legacy_llm_sbs))
    ),
    dissenting_coder = dissenting_coder(
      .data$HBM, .data$ASC, .data$JNG, .data$legacy_llm_sbs
    ),
    reconstructed_manuscript_code = manuscript_code(
      .data$HBM, .data$ASC, .data$JNG, .data$legacy_llm_sbs
    )
  ) |>
  dplyr::ungroup()

if (!is.null(new_llm)) {
  historical <- historical |>
    dplyr::left_join(new_llm, by = c("entity_slug", "question_id")) |>
    dplyr::mutate(
      new_llm_agrees_human_majority = .data$new_llm_sbs == .data$human_majority
    )
} else {
  historical <- historical |>
    dplyr::mutate(
      new_llm_sbs = NA_character_,
      new_llm_agrees_human_majority = NA
    )
}

manuscript_subset <- historical |>
  dplyr::filter(.data$question_id != excluded_id) |>
  dplyr::mutate(
    manuscript_question_id = dplyr::if_else(
      .data$question_id < excluded_id,
      .data$question_id,
      .data$question_id - 1L
    )
  ) |>
  dplyr::left_join(
    manuscript,
    by = c("manuscript_question_id", "entity_slug")
  ) |>
  dplyr::mutate(
    table_a5_match = .data$reconstructed_manuscript_code == .data$manuscript_agreement,
    notes = dplyr::case_when(
      .data$entity_slug == "irg" & .data$manuscript_question_id == 3L ~
        "Table A5 reports 2-2; surviving raw human + legacy SBS data reconstruct 3-1.",
      .data$entity_slug == "coas" & .data$manuscript_question_id == 8L ~
        "Table A5 reports 2-2; raw data reconstruct 3-1 and manuscript prose also describes a 3-1 human-outlier decision.",
      .data$entity_slug == "ceer" & .data$manuscript_question_id == 6L ~
        "Table A5 reports 2-2; surviving raw human + legacy SBS data reconstruct 3-1.",
      TRUE ~ NA_character_
    )
  ) |>
  dplyr::select(
    .data$entity_slug,
    .data$manuscript_question_id,
    computational_question_id = .data$question_id,
    .data$question,
    .data$HBM,
    .data$ASC,
    .data$JNG,
    .data$human_majority,
    .data$human_agreement,
    .data$legacy_llm_sbs,
    .data$legacy_llm_agrees_human_majority,
    .data$new_llm_sbs,
    .data$new_llm_agrees_human_majority,
    .data$historical_four_coder_pattern,
    .data$dissenting_coder,
    .data$manuscript_agreement,
    .data$reconstructed_manuscript_code,
    .data$table_a5_match,
    .data$notes
  ) |>
  dplyr::arrange(.data$manuscript_question_id, .data$entity_slug)

full_extended <- historical |>
  dplyr::select(
    .data$entity_slug, .data$question_id, .data$question,
    .data$HBM, .data$ASC, .data$JNG,
    .data$human_majority, .data$human_agreement,
    .data$legacy_llm_sbs, .data$legacy_llm_agrees_human_majority,
    .data$new_llm_sbs, .data$new_llm_agrees_human_majority,
    .data$historical_four_coder_pattern, .data$dissenting_coder
  )

# ////////////////////////////////////////////////////
#
#
# 6. Write Audit Outputs ----
#
#
# ////////////////////////////////////////////////////

derived_dir <- cfg$project$derived_dir
dir.create(derived_dir, recursive = TRUE, showWarnings = FALSE)

readr::write_csv(
  manuscript_subset,
  file.path(derived_dir, "table_a5_replication.csv")
)
readr::write_csv(
  dplyr::filter(manuscript_subset, !.data$table_a5_match),
  file.path(derived_dir, "table_a5_discrepancies.csv")
)
readr::write_csv(
  full_extended,
  file.path(derived_dir, "sbs_coder_comparison_extended.csv")
)

cat("Table A5 historical cells reconstructed: ", nrow(manuscript_subset), "\n", sep = "")
cat("Table A5 matches: ", sum(manuscript_subset$table_a5_match), "\n", sep = "")
cat("Table A5 discrepancies: ", sum(!manuscript_subset$table_a5_match), "\n", sep = "")
if (is.null(new_run)) {
  cat("Newer-model SBS run: not found; new-model columns written as NA.\n")
} else {
  cat("Newer-model SBS run: ", new_run, "\n", sep = "")
}
cat("API calls: NONE\n")
# FINAL OUTPUT LINE
