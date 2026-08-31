# Reconstruction Notes

This working directory preserves the December 2024 PON governance LLM evidence while separating historical artifacts from reproducible contemporary extensions.

## Recovered source corpus

Six archival boundary objects are retained as `BO1A.txt` through `BO6A.txt`. The five-PON strict comparison uses IRG, EUHC, COAS, CAN, and CEER. BEREC is handled separately. A second BEREC source, `BO1B.txt`, is the required input for the dedicated BEREC replication scripts.

## Preserved model outputs

Eleven legacy response files are retained in `output/`:

- one BEREC binary output from Dec. 23, 2024; and
- ten Dec. 24, 2024 final-pipeline outputs covering five PONs under zero-shot and step-by-step prompting.

These files are historical artifacts. The repository's execution scripts do not rewrite them.

## Manuscript-facing protocol

The manuscript-facing Dec. 24 condition is the recovered prompt with the clause `Let's think step by step` appended. The frozen `*_sbs.txt` files are therefore the historical benchmark for the revised principal analysis.

The plain-zero-shot `*_z.txt` files remain preserved for provenance but are not the principal benchmark. The previously added `improved-v1` machinery also remains in the repository as archival/secondary material and is no longer part of the primary comparison.

## Instrument

The computational files contain 15 ordered binary questions. The manuscript's Table A5 contains 14 prompts because the working-groups item (computational question 10) is omitted. The project preserves both representations:

- 15 questions for computational protocol fidelity; and
- a 14-question manuscript subset for Table A5 replication.

## Human-reference data

The authoritative human-reference file is now `input/reference/legacy_human_responses_confirmed.csv`. It retains the three individual human coders used in the manuscript-facing validation. Project-facing labels are:

- HBM;
- ASC; and
- JNG.

The three-human majority vote is computed explicitly, and each LLM's agreement with that majority is reported separately.

## Table A5 audit

The surviving raw human data plus the frozen legacy SBS outputs reproduce 67 of 70 manuscript Table A5 cells. IRG prompt 3, cOAlition S prompt 8, and CEER prompt 6 reconstruct as 3-to-1 splits while Table A5 reports `2-2`. These are recorded as Table A5 discrepancies relative to the surviving coder-level data, without modifying any source response.

See `provenance/TABLE_A5_REPLICATION.md`.

## Contemporary-model extension

The primary contemporary comparison runs each registered model under the same reconstructed Dec. 24 SBS protocol for IRG, EUHC, COAS, CAN, and CEER. The registered arms are the pinned GPT-5.4 nano snapshot `gpt-5.4-nano-2026-03-17` and GPT-5.6 Luna using API model ID `gpt-5.6-luna`. Both completed arms were executed independently and are reused by downstream analysis. The runner refuses legacy GPT-4 Turbo IDs and writes every new execution only to a new timestamped directory under `output/current/`.

OpenAI's GPT-5.6 Luna model page was checked on **2026-08-31**. Its **Snapshots** section listed `gpt-5.6-luna` but did not expose a dated identifier analogous to `gpt-5.4-nano-2026-03-17`. The project therefore records `gpt-5.6-luna` as an **undated model ID**, not as a dated or immutable snapshot. The configuration stores the documentation URL and check date, and each execution preserves the UTC run timestamp plus the requested and API-returned model identifiers in its metadata and completion manifest. This is the strongest provenance currently available without inventing a snapshot that OpenAI does not expose.

## BEREC caveat and dedicated workflow

BEREC's preserved Dec. 23 response predates the final Dec. 24 request implementation. The exact request construction cannot be proven from the surviving artifacts. BEREC therefore remains outside strict five-PON aggregate comparisons and is handled only through dedicated, dry-run-by-default scripts using `BO1B.txt`.

See `provenance/BEREC_REPLICATION.md` and `LEGACY_API_CALLS.md`.

## Analysis-integrity safeguards

The five-PON model comparison is defined as 75 decisions per model: five PONs by 15 computational questions. The comparison script fails before writing results unless it finds exactly 75 decisions for every registered model, exactly 15 decisions per model/PON, unique model/PON/question keys, exactly 75 direct legacy-versus-contemporary comparisons for each contemporary arm, and matching human-reference values across model generations.

These checks were added after an evaluation join was found to have multiplied human-reference rows across PONs. The corrected PON-specific join uses the function argument explicitly (`.env$entity_slug`) and the corrected comparison contains 75 decisions per model rather than 375. Under the corrected evaluation, frozen GPT-4 Turbo SBS agrees with the confirmed human reference in 86.7% of classifications and GPT-5.4 nano in 78.7%; four of the 14 GPT-4-to-GPT-5.4 changes move toward the human reference and ten move away. GPT-5.6 Luna results are computed from its completed stored run by the same checks rather than inserted manually.
