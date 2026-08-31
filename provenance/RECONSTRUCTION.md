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

The surviving raw human data plus the frozen legacy SBS outputs reproduce 67 of 70 manuscript Table A5 cells. IRG prompt 3, cOAlition S prompt 8, and CEER prompt 6 reconstruct as 3-to-1 splits while Table A5 reports `2-2`. These are recorded as Table A5 errors without modifying any source response.

See `provenance/TABLE_A5_REPLICATION.md`.

## Current-model extension

The primary contemporary extension runs `gpt-5.4-nano-2026-03-17` under the same reconstructed Dec. 24 SBS protocol for IRG, EUHC, COAS, CAN, and CEER. The runner refuses legacy GPT-4 Turbo IDs and writes only to a new timestamped directory under `output/current/`.

## BEREC caveat and dedicated workflow

BEREC's preserved Dec. 23 response predates the final Dec. 24 request implementation. The exact request construction cannot be proven from the surviving artifacts. BEREC therefore remains outside strict five-PON aggregate comparisons and is handled only through dedicated, dry-run-by-default scripts using `BO1B.txt`.

See `provenance/BEREC_REPLICATION.md` and `LEGACY_API_CALLS.md`.
