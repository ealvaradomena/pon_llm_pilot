# ////////////////////////////////////////////////////
#
#
# PON LLM Pilot - Human Response Audit
#
# Purpose:
# - Harmonize and compare multiple human-response datasets
# - Align external coder files to the canonical legacy question identifiers
# - Write the confirmed human-response reference used by the revised analysis
#
# Requirements:
# - Reference CSV and Excel files under input/reference/
# - R packages used through explicit namespace calls
#
# AI Disclosure:
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-r-scripts.md
#
# ////////////////////////////////////////////////////

# ////////////////////////////////////////////////////
#
#
# 1. Load reference data ----
#
#
# ////////////////////////////////////////////////////

# Legacy human responses
lhr_data <- readr::read_csv(
  file = "input/reference/legacy_human_responses.csv",
  show_col_types = FALSE
) |>
  as.data.frame()

# Create working copy
lhr_df <- lhr_data

# Legacy runs
lr_data <- readr::read_csv(
  file = "input/reference/legacy_runs.csv",
  show_col_types = FALSE
) |>
  as.data.frame()

# Create working copy
lr_df <- lr_data


# ////////////////////////////////////////////////////
#
#
# 2. Register external files ----
#
#
# ////////////////////////////////////////////////////

# Files received by email
files_received_by_email <- list(
  all_pons = list(
    google_file_id = "16TkhiyS987PtyuNQLW84WgzPZZ1YZM_ycjIUlcTH8_s",
    local_path = "input/reference/received_by_email/All PONs.xlsx",
    email_date = as.Date(NA), # YYYY-MM-DD
    email_subject = NA_character_,
    email_from = NA_character_
  ),
  grid_with_improved_suggestions_Juan = list(
    google_file_id = "1IrIRuFj3HVLuiUY74bRMH12dHTjJ7h_xcnTwq5-D_JY",
    local_path = "input/reference/received_by_email/Grid with improved suggestions (Juan).xlsx",
    email_date = as.Date("2024-12-11"), # YYYY-MM-DD
    email_subject = NA_character_,
    email_from = "Juan"
  )
)

# Files shared via Google Drive
files_shared_via_google_drive <- list(
  drive_human_response = list(
    google_file_id = "14pch0uaUue4VkrKtgKSZN7ySTcOlMEhuyVZuxSxqDfA",
    local_path = "input/reference/shared_via_Google_Drive/drive_human_response.xlsx",
    email_date = as.Date(NA), # YYYY-MM-DD
    email_subject = NA_character_,
    email_from = NA_character_
  )
)

# ////////////////////////////////////////////////////
#
#
# 3. Load external data ----
#
#
# ////////////////////////////////////////////////////

# Drive human responses
dhr_data <- readxl::read_excel(
  path = files_shared_via_google_drive$drive_human_response$local_path,
  sheet = 1
) |>
  as.data.frame()

# Create working copy
dhr_df <- dhr_data

# Grid with improved suggestions
gwisj_data <- readxl::read_excel(
  path = files_received_by_email$grid_with_improved_suggestions_Juan$local_path,
  sheet = 1
) |>
  as.data.frame()

# Create working copy
gwisj_df <- gwisj_data

# Remove separator rows between entity blocks
# and retain question, entity, and human-response columns
gwisj_df <- gwisj_df[
  -c(16, 32, 48, 64),
  c(1, 3:4)
]

# All PONs
ap_data <- readxl::read_excel(
  path = files_received_by_email$all_pons$local_path,
  sheet = 1
) |>
  as.data.frame()

# Create working copy
ap_df <- ap_data

# Retain relevant observations
ap_df <- ap_df[1:75, ]


# ////////////////////////////////////////////////////
#
#
# 4. Standardize variables ----
#
#
# ////////////////////////////////////////////////////

# Convert binary responses to logical
as_binary_logical <- function(x) {

  x <- as.character(x)

  dplyr::case_when(
    x %in% c("Yes", "1", "1.0", "TRUE") ~ TRUE,
    x %in% c("No", "0", "0.0", "FALSE") ~ FALSE,
    is.na(x) ~ NA,
    TRUE ~ NA
  )
}

# Normalize known non-substantive question differences
normalize_question <- function(x) {

  x |>
    trimws() |>
    gsub("\\s+", " ", x = _) |>
    gsub("\\s*/\\s*", "/", x = _) |>
    gsub(
      "organisations",
      "organizations",
      x = _,
      ignore.case = TRUE
    ) |>
    gsub(
      "consesus",
      "consensus",
      x = _,
      ignore.case = TRUE
    ) |>
    gsub(
      "fullful",
      "fulfil",
      x = _,
      ignore.case = TRUE
    )
}

# Harmonize source-specific entity names to canonical slugs
entity_slug_map <- c(
  "Independent Regulators Group" = "irg",
  "EU Health Coalition" = "euhc",
  "EU Health Comision" = "euhc",
  "cOAlition S" = "coas",
  "Climate Action Network" = "can",
  "Council of European Energy Regulators" = "ceer",
  "CEER" = "ceer"
)

# Use LHR as the canonical source of question IDs
lhr_question_lookup <- lhr_df |>
  dplyr::select(
    question_id,
    question
  ) |>
  dplyr::distinct() |>
  dplyr::mutate(
    question_normalized = normalize_question(question)
  ) |>
  dplyr::select(
    question_id,
    question_normalized
  )

# Confirm normalized question text maps uniquely to question IDs
stopifnot(
  anyDuplicated(lhr_question_lookup$question_normalized) == 0
)

# Document GWISJ questions with deliberately revised wording
gwisj_revised_question_ids <- c(
  4,
  5,
  6,
  8,
  14
)


# All PONs ----

# Align core variable names with legacy data
colnames(ap_df)[1:3] <- colnames(lhr_df)[1:3]

# Standardize response and annotator variable names
ap_df <- ap_df |>
  dplyr::rename(
    human_response = Human_Vote,
    coding_brint = Coding_Brint,
    coding_angel = Coding_Ángel,
    coding_juan = Coding_Juan
  )

# Create entity slug
ap_df$entity_slug <- unname(
  entity_slug_map[ap_df$entity]
)

# Confirm all entities were mapped
stopifnot(
  !any(is.na(ap_df$entity_slug))
)

# Standardize binary responses
ap_df <- ap_df |>
  dplyr::mutate(
    human_response = as_binary_logical(human_response),
    coding_brint = as_binary_logical(coding_brint),
    coding_angel = as_binary_logical(coding_angel),
    coding_juan = as_binary_logical(coding_juan)
  ) |>
  dplyr::select(
    question_id,
    question,
    entity,
    entity_slug,
    dplyr::everything()
  )


# Drive human responses ----

# Confirm required source variables are available
stopifnot(
  all(
    c(
      "question",
      "rule_type",
      "entity",
      "human_response"
    ) %in% colnames(dhr_df)
  )
)

# Create entity slug
dhr_df$entity_slug <- unname(
  entity_slug_map[dhr_df$entity]
)

# Confirm all entities were mapped
stopifnot(
  !any(is.na(dhr_df$entity_slug))
)

# Create normalized question text
dhr_df <- dhr_df |>
  dplyr::mutate(
    question_normalized = normalize_question(question)
  )

# Recover canonical question IDs from LHR question text
dhr_df <- dhr_df |>
  dplyr::left_join(
    lhr_question_lookup,
    by = "question_normalized"
  )

# Confirm all DHR questions were matched
stopifnot(
  !any(is.na(dhr_df$question_id))
)

# Standardize binary response and column order
dhr_df <- dhr_df |>
  dplyr::mutate(
    human_response = as_binary_logical(human_response)
  ) |>
  dplyr::select(
    question_id,
    question,
    rule_type,
    entity,
    entity_slug,
    human_response
  )


# Grid with improved suggestions ----

# Standardize variable names
gwisj_df <- gwisj_df |>
  dplyr::rename(
    question = Question
  )

# Confirm required source variables are available
stopifnot(
  all(
    c(
      "question",
      "entity",
      "human_response"
    ) %in% colnames(gwisj_df)
  )
)

# Create entity slug
gwisj_df$entity_slug <- unname(
  entity_slug_map[gwisj_df$entity]
)

# Confirm all entities were mapped
stopifnot(
  !any(is.na(gwisj_df$entity_slug))
)

# Create normalized question text
gwisj_df <- gwisj_df |>
  dplyr::mutate(
    question_normalized = normalize_question(question)
  )

# Recover canonical question IDs where wording matches LHR
gwisj_df <- gwisj_df |>
  dplyr::left_join(
    lhr_question_lookup,
    by = "question_normalized"
  )

# GWISJ deliberately revises the wording of questions
# 4, 5, 6, 8, and 14. Preserve the revised wording while
# assigning the corresponding canonical LHR question IDs
gwisj_df <- gwisj_df |>
  dplyr::mutate(
    question_id = dplyr::case_when(
      !is.na(question_id) ~ question_id,

      question_normalized ==
        "Are decisions normally made by consensus or unanimity by member organizations - regardless of any exceptions to the general rule specified in the text?" ~ 4,

      question_normalized ==
        "If the organization has both a plenary assembly and an executive board, are their default decision-making rules the same – regardless of any exceptions to the general rule specified in the text?”" ~ 5,

      question_normalized ==
        "Are there expert committees, expert groups, or equivalent bodies in the PON?" ~ 6,

      question_normalized ==
        "Does the organization have a plenary assembly (or an equivalent body, regardless of the name given in the document) where all members participate and which makes the constitutional decisions?" ~ 8,

      question_normalized ==
        "Is there a process for suspending or expelling members (or an equivalent process) from the PON?" ~ 14,

      TRUE ~ NA_real_
    )
  )

# Identify any remaining unmatched questions
gwisj_unmatched_questions <- gwisj_df |>
  dplyr::filter(
    is.na(question_id)
  ) |>
  dplyr::select(
    question,
    question_normalized,
    entity
  ) |>
  dplyr::distinct()

gwisj_unmatched_questions

# Confirm all GWISJ questions were matched
stopifnot(
  nrow(gwisj_unmatched_questions) == 0
)

# Standardize binary response and column order
gwisj_df <- gwisj_df |>
  dplyr::mutate(
    human_response = as_binary_logical(human_response)
  ) |>
  dplyr::select(
    question_id,
    question,
    entity,
    entity_slug,
    human_response
  )


# ////////////////////////////////////////////////////
#
#
# 5. Create entity-question identifiers ----
#
#
# ////////////////////////////////////////////////////

# Combine canonical entity slug and question ID to create
# a common observation-level identifier across datasets

# Legacy human responses
lhr_df <- lhr_df |>
  dplyr::mutate(
    entity_question_id = paste(
      entity_slug,
      question_id,
      sep = "_"
    )
  )

# Drive human responses
dhr_df <- dhr_df |>
  dplyr::mutate(
    entity_question_id = paste(
      entity_slug,
      question_id,
      sep = "_"
    )
  )

# Grid with improved suggestions
gwisj_df <- gwisj_df |>
  dplyr::mutate(
    entity_question_id = paste(
      entity_slug,
      question_id,
      sep = "_"
    )
  )

# All PONs
ap_df <- ap_df |>
  dplyr::mutate(
    entity_question_id = paste(
      entity_slug,
      question_id,
      sep = "_"
    )
  )


# ////////////////////////////////////////////////////
#
#
# 6. Validate harmonization ----
#
#
# ////////////////////////////////////////////////////

# Confirm entity-question IDs are unique
stopifnot(
  anyDuplicated(lhr_df$entity_question_id) == 0,
  anyDuplicated(dhr_df$entity_question_id) == 0,
  anyDuplicated(gwisj_df$entity_question_id) == 0
)

# Compare LHR-DHR coverage
lhr_entity_question_ids <- lhr_df |>
  dplyr::distinct(entity_question_id)

dhr_entity_question_ids <- dhr_df |>
  dplyr::distinct(entity_question_id)

# Identify observations available only in LHR
lhr_only_dhr_ids <- lhr_entity_question_ids |>
  dplyr::anti_join(
    dhr_entity_question_ids,
    by = "entity_question_id"
  )

# Identify observations available only in DHR
dhr_only_ids <- dhr_entity_question_ids |>
  dplyr::anti_join(
    lhr_entity_question_ids,
    by = "entity_question_id"
  )

# Confirm identical LHR-DHR coverage
stopifnot(
  nrow(lhr_only_dhr_ids) == 0,
  nrow(dhr_only_ids) == 0
)

# Compare LHR-GWISJ coverage
gwisj_entity_question_ids <- gwisj_df |>
  dplyr::distinct(entity_question_id)

# Identify observations available only in LHR
lhr_only_gwisj_ids <- lhr_entity_question_ids |>
  dplyr::anti_join(
    gwisj_entity_question_ids,
    by = "entity_question_id"
  )

# Identify observations available only in GWISJ
gwisj_only_ids <- gwisj_entity_question_ids |>
  dplyr::anti_join(
    lhr_entity_question_ids,
    by = "entity_question_id"
  )

# Confirm identical LHR-GWISJ coverage
stopifnot(
  nrow(lhr_only_gwisj_ids) == 0,
  nrow(gwisj_only_ids) == 0
)

# Compare LHR-DHR question text
dhr_question_comparison <- lhr_df |>
  dplyr::select(
    question_id,
    question_lhr = question
  ) |>
  dplyr::distinct() |>
  dplyr::left_join(
    dhr_df |>
      dplyr::select(
        question_id,
        question_dhr = question
      ) |>
      dplyr::distinct(),
    by = "question_id"
  ) |>
  dplyr::mutate(
    question_lhr_normalized = normalize_question(question_lhr),
    question_dhr_normalized = normalize_question(question_dhr),
    question_match = question_lhr_normalized == question_dhr_normalized
  )

# Identify unexpected LHR-DHR question mismatches
dhr_question_mismatches <- dhr_question_comparison |>
  dplyr::filter(
    is.na(question_match) | !question_match
  )

dhr_question_mismatches

# Confirm LHR-DHR question correspondence
stopifnot(
  nrow(dhr_question_mismatches) == 0
)

# Compare LHR-GWISJ question text
gwisj_question_comparison <- lhr_df |>
  dplyr::select(
    question_id,
    question_lhr = question
  ) |>
  dplyr::distinct() |>
  dplyr::left_join(
    gwisj_df |>
      dplyr::select(
        question_id,
        question_gwisj = question
      ) |>
      dplyr::distinct(),
    by = "question_id"
  ) |>
  dplyr::mutate(
    question_lhr_normalized = normalize_question(question_lhr),
    question_gwisj_normalized = normalize_question(question_gwisj),

    # Flag documented substantive wording revisions
    question_revised = question_id %in%
      gwisj_revised_question_ids,

    # Require exact normalized wording unless revision is documented
    question_match = (
      question_lhr_normalized == question_gwisj_normalized
    ) | question_revised
  )

# Identify unexpected LHR-GWISJ question mismatches
gwisj_question_mismatches <- gwisj_question_comparison |>
  dplyr::filter(
    is.na(question_match) | !question_match
  )

gwisj_question_mismatches

# Confirm all LHR-GWISJ differences are documented
stopifnot(
  nrow(gwisj_question_mismatches) == 0
)


# ////////////////////////////////////////////////////
#
#
# 7. Compare LHR and DHR human responses ----
#
#
# ////////////////////////////////////////////////////

dhr_response_comparison <- lhr_df |>
  dplyr::select(
    entity_question_id,
    question,
    human_response_lhr = human_response
  ) |>
  dplyr::left_join(
    dhr_df |>
      dplyr::select(
        entity_question_id,
        human_response_dhr = human_response
      ),
    by = "entity_question_id"
  ) |>
  dplyr::mutate(
    response_match = human_response_lhr == human_response_dhr
  )

# Identify response mismatches
dhr_response_mismatches <- dhr_response_comparison |>
  dplyr::filter(
    is.na(response_match) | !response_match
  )

dhr_response_mismatches[, c(
  "entity_question_id",
  "human_response_lhr",
  "human_response_dhr",
  "response_match"
)]


# ////////////////////////////////////////////////////
#
#
# 8. Summarize LHR-DHR agreement ----
#
#
# ////////////////////////////////////////////////////

dhr_response_agreement <- dhr_response_comparison |>
  dplyr::summarise(
    n = dplyr::n(),
    n_match = sum(response_match, na.rm = TRUE),
    n_mismatch = sum(!response_match, na.rm = TRUE),
    n_missing = sum(is.na(response_match)),
    agreement = mean(response_match, na.rm = TRUE)
  )

dhr_response_agreement


# ////////////////////////////////////////////////////
#
#
# 9. Compare LHR and GWISJ human responses ----
#
#
# ////////////////////////////////////////////////////

gwisj_response_comparison <- lhr_df |>
  dplyr::select(
    entity_question_id,
    question,
    human_response_lhr = human_response
  ) |>
  dplyr::left_join(
    gwisj_df |>
      dplyr::select(
        entity_question_id,
        human_response_gwisj = human_response
      ),
    by = "entity_question_id"
  ) |>
  dplyr::mutate(
    response_match = human_response_lhr == human_response_gwisj
  )

# Identify response mismatches
gwisj_response_mismatches <- gwisj_response_comparison |>
  dplyr::filter(
    is.na(response_match) | !response_match
  )

gwisj_response_mismatches[, c(
  "entity_question_id",
  "human_response_lhr",
  "human_response_gwisj",
  "response_match"
)]


# ////////////////////////////////////////////////////
#
#
# 10. Summarize LHR-GWISJ agreement ----
#
#
# ////////////////////////////////////////////////////

gwisj_response_agreement <- gwisj_response_comparison |>
  dplyr::summarise(
    n = dplyr::n(),
    n_match = sum(response_match, na.rm = TRUE),
    n_mismatch = sum(!response_match, na.rm = TRUE),
    n_missing = sum(is.na(response_match)),
    agreement = mean(response_match, na.rm = TRUE)
  )

gwisj_response_agreement


# ////////////////////////////////////////////////////
#
#
# 11. Compare LHR with individual annotators ----
#
#
# ////////////////////////////////////////////////////

lhr_annotator_comparison <- lhr_df |>
  dplyr::select(
    entity_question_id,
    question,
    human_response_lhr = human_response
  ) |>
  dplyr::left_join(
    ap_df |>
      dplyr::select(
        entity_question_id,
        coding_brint,
        coding_angel,
        coding_juan
      ),
    by = "entity_question_id"
  ) |>
  dplyr::mutate(
    brint_match = human_response_lhr == coding_brint,
    angel_match = human_response_lhr == coding_angel,
    juan_match = human_response_lhr == coding_juan
  )

lhr_annotator_comparison

# Summarize LHR agreement with annotators
lhr_annotator_agreement <- lhr_annotator_comparison |>
  dplyr::summarise(
    brint_agreement = mean(brint_match, na.rm = TRUE),
    angel_agreement = mean(angel_match, na.rm = TRUE),
    juan_agreement = mean(juan_match, na.rm = TRUE)
  )

lhr_annotator_agreement


# ////////////////////////////////////////////////////
#
#
# 12. Compare DHR with individual annotators ----
#
#
# ////////////////////////////////////////////////////

dhr_annotator_comparison <- dhr_df |>
  dplyr::select(
    entity_question_id,
    question,
    human_response_dhr = human_response
  ) |>
  dplyr::left_join(
    ap_df |>
      dplyr::select(
        entity_question_id,
        coding_brint,
        coding_angel,
        coding_juan
      ),
    by = "entity_question_id"
  ) |>
  dplyr::mutate(
    brint_match = human_response_dhr == coding_brint,
    angel_match = human_response_dhr == coding_angel,
    juan_match = human_response_dhr == coding_juan
  )

dhr_annotator_comparison

# Summarize DHR agreement with annotators
dhr_annotator_agreement <- dhr_annotator_comparison |>
  dplyr::summarise(
    brint_agreement = mean(brint_match, na.rm = TRUE),
    angel_agreement = mean(angel_match, na.rm = TRUE),
    juan_agreement = mean(juan_match, na.rm = TRUE)
  )

dhr_annotator_agreement


# ////////////////////////////////////////////////////
#
#
# 13. Compare GWISJ with individual annotators ----
#
#
# ////////////////////////////////////////////////////

gwisj_annotator_comparison <- gwisj_df |>
  dplyr::select(
    entity_question_id,
    question,
    human_response_gwisj = human_response
  ) |>
  dplyr::left_join(
    ap_df |>
      dplyr::select(
        entity_question_id,
        coding_brint,
        coding_angel,
        coding_juan
      ),
    by = "entity_question_id"
  ) |>
  dplyr::mutate(
    brint_match = human_response_gwisj == coding_brint,
    angel_match = human_response_gwisj == coding_angel,
    juan_match = human_response_gwisj == coding_juan
  )

gwisj_annotator_comparison

# Summarize GWISJ agreement with annotators
gwisj_annotator_agreement <- gwisj_annotator_comparison |>
  dplyr::summarise(
    brint_agreement = mean(brint_match, na.rm = TRUE),
    angel_agreement = mean(angel_match, na.rm = TRUE),
    juan_agreement = mean(juan_match, na.rm = TRUE)
  )

gwisj_annotator_agreement

# Save human responses
ap_df[, c(1, 2, 3, 4, 5, 7, 8, 9, 14)] |>
  write.csv(
    "input/reference/legacy_human_responses_confirmed.csv",
    row.names = FALSE
  )
# FINAL OUTPUT LINE
