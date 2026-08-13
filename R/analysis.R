# ////////////////////////////////////////////////////
#
# PON LLM Pilot - Analysis Functions
#
# Purpose
# - Parse preserved and current LLM outputs
# - Evaluate four zero-shot model/protocol scenarios
# - Compare model-generation stability under each protocol
# - Produce concise, publication-ready visualizations
#
# ////////////////////////////////////////////////////

# 1. Parse LLM Output ----

extract_binary_responses <- function(raw_text) {
  # Remove Markdown code fences while preserving response content
  clean_text <- stringr::str_replace_all(
    raw_text,
    "(?m)^\\s*```[^\\n]*$",
    ""
  )

  # Extract explicit CSV answer cells and ignore header tokens such as TRUE_OR_FALSE
  matches <- stringr::str_match_all(
    clean_text,
    "(?i),\\s*\"?(TRUE|FALSE)\"?(?=\\s|$|[A-Z][a-z])"
  )[[1]]

  if (nrow(matches) == 0) {
    return(character())
  }

  toupper(matches[, 2])
}

parse_llm_output <- function(path, questions, response_name = "llm_response") {
  # Read the complete response so wrapped or concatenated CSV rows remain parseable
  raw_text <- paste(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )

  answers <- extract_binary_responses(raw_text)

  # Fail rather than truncate or infer when the response is not one-to-one with the instrument
  if (length(answers) != nrow(questions)) {
    stop(
      sprintf(
        "Expected %s binary responses in %s; found %s",
        nrow(questions),
        path,
        length(answers)
      )
    )
  }

  result <- tibble::tibble(
    question_id = questions$question_id,
    question = questions$question,
    response = answers
  )

  names(result)[names(result) == "response"] <- response_name
  result
}

# 2. Diagnose LLM Output Formatting ----

diagnose_llm_output <- function(path, questions) {
  lines <- readLines(
    path,
    warn = FALSE,
    encoding = "UTF-8"
  )

  raw_text <- paste(lines, collapse = "\n")
  answers <- extract_binary_responses(raw_text)

  concatenated_boundaries <- stringr::str_count(
    raw_text,
    "(?i)(TRUE|FALSE)(?=[A-Z][a-z])"
  )

  header <- if (length(lines) == 0) "" else lines[[1]]
  header_contains_binary_token <- stringr::str_detect(
    header,
    "(?i)TRUE|FALSE"
  )

  header_standard <- stringr::str_detect(
    stringr::str_trim(header),
    "(?i)^(question|question_id)\\s*,\\s*(answer|response|true_or_false)\\s*$"
  )

  tibble::tibble(
    file = basename(path),
    expected_responses = nrow(questions),
    recovered_responses = length(answers),
    parse_status = ifelse(
      length(answers) == nrow(questions),
      "OK",
      "Review"
    ),
    concatenated_row_boundaries = concatenated_boundaries,
    header_contains_binary_token = header_contains_binary_token,
    header_standard = header_standard,
    first_line = header
  )
}

# 3. Human-Reference Evaluation ----

classify_agreement <- function(llm_response, human_response) {
  dplyr::case_when(
    llm_response == "TRUE" & human_response == "TRUE" ~ "TP",
    llm_response == "FALSE" & human_response == "TRUE" ~ "FN",
    llm_response == "TRUE" & human_response == "FALSE" ~ "FP",
    llm_response == "FALSE" & human_response == "FALSE" ~ "TN",
    TRUE ~ NA_character_
  )
}

compute_metrics <- function(data) {
  counts <- data |>
    dplyr::count(eval, name = "n") |>
    tidyr::complete(
      eval = c("TP", "FP", "FN", "TN"),
      fill = list(n = 0)
    )

  n_for <- function(label) counts$n[counts$eval == label]

  tp <- n_for("TP")
  fp <- n_for("FP")
  fn <- n_for("FN")
  tn <- n_for("TN")
  n <- tp + fp + fn + tn

  accuracy <- if (n == 0) NA_real_ else (tp + tn) / n
  precision <- if ((tp + fp) == 0) NA_real_ else tp / (tp + fp)
  recall <- if ((tp + fn) == 0) NA_real_ else tp / (tp + fn)
  specificity <- if ((tn + fp) == 0) NA_real_ else tn / (tn + fp)

  f1 <- if (
    is.na(precision) ||
      is.na(recall) ||
      (precision + recall) == 0
  ) {
    NA_real_
  } else {
    2 * precision * recall / (precision + recall)
  }

  tibble::tibble(
    n = n,
    tp = tp,
    fp = fp,
    fn = fn,
    tn = tn,
    accuracy = accuracy,
    disagreement_rate = 1 - accuracy,
    precision = precision,
    recall = recall,
    specificity = specificity,
    f1 = f1
  )
}

evaluate_output <- function(path, entity_slug, technique, questions, human) {
  parsed <- parse_llm_output(
    path = path,
    questions = questions,
    response_name = "llm_response"
  )

  reference <- human |>
    dplyr::filter(.data$entity_slug == entity_slug) |>
    dplyr::select("question_id", "human_response")

  parsed |>
    dplyr::left_join(reference, by = "question_id") |>
    dplyr::mutate(
      entity_slug = entity_slug,
      technique = technique,
      eval = classify_agreement(.data$llm_response, .data$human_response),
      agreement = .data$llm_response == .data$human_response,
      source_file = basename(path)
    )
}

# 4. Model-to-Model Comparison ----

compare_model_outputs <- function(
  legacy_path,
  current_path,
  entity_slug,
  protocol,
  questions
) {
  legacy <- parse_llm_output(
    path = legacy_path,
    questions = questions,
    response_name = "legacy_response"
  )

  current <- parse_llm_output(
    path = current_path,
    questions = questions,
    response_name = "current_response"
  )

  legacy |>
    dplyr::left_join(
      current |>
        dplyr::select("question_id", "current_response"),
      by = "question_id"
    ) |>
    dplyr::mutate(
      entity_slug = entity_slug,
      protocol = protocol,
      agreement = .data$legacy_response == .data$current_response,
      flip = dplyr::case_when(
        .data$agreement ~ "No change",
        .data$legacy_response == "FALSE" & .data$current_response == "TRUE" ~ "FALSE → TRUE",
        .data$legacy_response == "TRUE" & .data$current_response == "FALSE" ~ "TRUE → FALSE",
        TRUE ~ NA_character_
      )
    )
}

# 5. Display Labels and Visual Style ----

pon_label <- function(entity_slug) {
  dplyr::recode(
    entity_slug,
    berec = "BEREC",
    irg = "IRG",
    euhc = "EUHC",
    coas = "COAS",
    can = "CAN",
    ceer = "CEER",
    .default = toupper(entity_slug)
  )
}

model_palette <- function() {
  c(
    "GPT-4 Turbo" = "#3B5B92",
    "GPT-5.4 nano" = "#C05A47",
    "GPT-5.4 mini" = "#2A7F62"
  )
}

protocol_shapes <- function() {
  c(
    "2024 protocol" = 16,
    "Improved protocol" = 17
  )
}

# 6. Model-by-Protocol Visualizations ----

plot_scenario_disagreement <- function(metrics_data) {
  plot_data <- metrics_data |>
    dplyr::mutate(
      pon = factor(
        pon_label(.data$entity_slug),
        levels = c("IRG", "EUHC", "COAS", "CAN", "CEER")
      ),
      protocol = factor(
        .data$protocol,
        levels = c("2024 protocol", "Improved protocol")
      )
    )

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = .data$pon,
      y = .data$disagreement_rate,
      color = .data$model,
      shape = .data$protocol,
      group = interaction(.data$model, .data$protocol)
    )
  ) +
    ggplot2::geom_point(
      size = 3.4,
      position = ggplot2::position_dodge(width = 0.45)
    ) +
    ggplot2::scale_color_manual(values = model_palette()) +
    ggplot2::scale_shape_manual(values = protocol_shapes()) +
    ggplot2::scale_y_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, by = 0.2),
      labels = scales::label_percent(accuracy = 1)
    ) +
    ggplot2::labs(
      x = NULL,
      y = "Share disagreeing with human reference",
      color = "Model",
      shape = "Protocol"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "top",
      panel.grid.minor = ggplot2::element_blank()
    )
}

plot_scenario_accuracy <- function(metrics_data) {
  plot_data <- metrics_data |>
    dplyr::mutate(
      pon = factor(
        pon_label(.data$entity_slug),
        levels = c("IRG", "EUHC", "COAS", "CAN", "CEER")
      ),
      protocol = factor(
        .data$protocol,
        levels = c("2024 protocol", "Improved protocol")
      )
    )

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = .data$pon,
      y = .data$accuracy,
      color = .data$model,
      shape = .data$protocol,
      group = interaction(.data$model, .data$protocol)
    )
  ) +
    ggplot2::geom_point(
      size = 3.4,
      position = ggplot2::position_dodge(width = 0.45)
    ) +
    ggplot2::scale_color_manual(values = model_palette()) +
    ggplot2::scale_shape_manual(values = protocol_shapes()) +
    ggplot2::scale_y_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, by = 0.2),
      labels = scales::label_percent(accuracy = 1)
    ) +
    ggplot2::labs(
      x = NULL,
      y = "Agreement with human reference",
      color = "Model",
      shape = "Protocol"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "top",
      panel.grid.minor = ggplot2::element_blank()
    )
}

plot_question_disagreement <- function(question_data) {
  plot_data <- question_data |>
    dplyr::mutate(
      question = factor(
        paste0("Q", .data$question_id),
        levels = paste0("Q", sort(unique(.data$question_id)))
      ),
      protocol = factor(
        .data$protocol,
        levels = c("2024 protocol", "Improved protocol")
      )
    )

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = .data$question,
      y = .data$disagreement_rate,
      color = .data$model,
      shape = .data$protocol,
      group = interaction(.data$model, .data$protocol)
    )
  ) +
    ggplot2::geom_line(linewidth = 0.65, alpha = 0.7) +
    ggplot2::geom_point(size = 2.6) +
    ggplot2::scale_color_manual(values = model_palette()) +
    ggplot2::scale_shape_manual(values = protocol_shapes()) +
    ggplot2::scale_y_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, by = 0.2),
      labels = scales::label_percent(accuracy = 1)
    ) +
    ggplot2::labs(
      x = "Governance question",
      y = "Share disagreeing with human reference",
      color = "Model",
      shape = "Protocol"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "top",
      panel.grid.minor = ggplot2::element_blank()
    )
}

plot_model_stability <- function(stability_data) {
  plot_data <- stability_data |>
    dplyr::mutate(
      pon = pon_label(.data$entity_slug),
      protocol = factor(
        .data$protocol,
        levels = c("2024 protocol", "Improved protocol")
      )
    )

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = .data$pon,
      y = .data$agreement_rate,
      color = .data$protocol,
      shape = .data$protocol
    )
  ) +
    ggplot2::geom_point(
      size = 3.4,
      position = ggplot2::position_dodge(width = 0.35)
    ) +
    ggplot2::scale_color_manual(
      values = c(
        "2024 protocol" = "#6A3D9A",
        "Improved protocol" = "#009E73"
      )
    ) +
    ggplot2::scale_shape_manual(values = protocol_shapes()) +
    ggplot2::scale_y_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, by = 0.2),
      labels = scales::label_percent(accuracy = 1)
    ) +
    ggplot2::labs(
      x = NULL,
      y = "Agreement between model generations",
      color = "Protocol",
      shape = "Protocol"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "top",
      panel.grid.minor = ggplot2::element_blank()
    )
}
