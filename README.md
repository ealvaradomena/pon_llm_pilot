# PON Governance LLM Pilot

README file created with generative AI for exceptional documentation depth.
See: https://github.com/ealvaradomena/my-prompts/tree/main/prompts/readme-builder

This repository reconstructs, audits, and extends a December 2024 proof-of-concept study of large-language-model coding of governance features in purpose-oriented networks (PONs). The principal analysis holds the recovered December 24, 2024 step-by-step (SBS) protocol fixed across five PONs and compares frozen GPT-4 Turbo responses with completed GPT-5.4 nano and GPT-5.6 Luna runs against the same confirmed three-human reference.

Project website: https://ealvaradomena.github.io/pon_llm_pilot/

## Overview

The repository separates historical evidence from contemporary extensions. The original 2024 LLM outputs are treated as read-only artifacts; downstream reconstruction and evaluation are local; new API-backed runs are isolated in timestamped directories and require explicit execution flags.

The principal five-PON comparison includes IRG, EUHC, cOAlition S (COAS), CAN, and CEER. BEREC remains in the archival corpus but is analyzed separately because its preserved December 23 output predates the final December 24 request implementation and the exact historical BEREC interaction cannot be reconstructed with enough confidence for a strict six-PON comparison.

The three principal model arms are:

| Model arm | Identifier / evidence | Role |
|---|---|---|
| GPT-4 Turbo | Historical requests used `gpt-4-turbo`; analysis uses frozen Dec. 24, 2024 `*_sbs.txt` outputs | Historical benchmark |
| GPT-5.4 nano | `gpt-5.4-nano-2026-03-17` | Completed contemporary SBS arm |
| GPT-5.6 Luna | `gpt-5.6-luna` | Completed contemporary SBS arm; undated model ID |

OpenAI's GPT-5.6 Luna documentation was checked on 2026-08-31. Its Snapshots section exposed `gpt-5.6-luna` but no dated Luna snapshot, so the project records that identifier as `undated_model_id` with `snapshot_status: no_dated_snapshot_exposed`. Each Luna run also preserves the request timestamp and requested and returned model identifiers.

Plain-zero-shot (`*_z.txt`) and `improved-v1` materials are retained for provenance but are not part of the principal revised comparison.

## Key analytical decisions and results

The computational instrument contains 15 ordered binary questions. Manuscript Table A5 contains 14 prompts because computational question 10, concerning working groups, is omitted from the manuscript-facing table. The project preserves the 15-question computational instrument and reconstructs Table A5 using the corresponding 14-question subset without renumbering the original questions.

The confirmed human reference is `input/reference/legacy_human_responses_confirmed.csv`. Its three individual coders are displayed as HBM, ASC, and JNG, and the human final vote is their majority classification. Model agreement is evaluated against that majority; precision, recall, specificity, and F1 are reference-based diagnostics rather than claims of external ground-truth accuracy.

Across the 75 five-PON/question classifications, the frozen GPT-4 Turbo SBS output agrees with the confirmed human reference in **86.7%** of cases and the completed GPT-5.4 nano arm in **78.7%**. GPT-5.6 Luna is evaluated by the same stored-run pipeline, and the website reads its results from generated `sbs_model_*` outputs rather than manually transcribing them into documentation. These figures describe this fixed reconstructed experiment, not a general benchmark of either model family.

### Table A5 reconstruction

The historical four-coder object is HBM + ASC + JNG + the frozen GPT-4 Turbo SBS response. The surviving coder-level data reproduce **67 of 70** manuscript Table A5 cells. Three cells report `2-2` in the manuscript even though the surviving responses reconstruct a 3-to-1 split:

| PON | Manuscript prompt | HBM | ASC | JNG | Frozen GPT-4 Turbo SBS | Surviving pattern | Table A5 |
|---|---:|---|---|---|---|---|---|
| IRG | 3 | FALSE | FALSE | TRUE | FALSE | 1 TRUE / 3 FALSE | `2-2` |
| cOAlition S | 8 | FALSE | TRUE | TRUE | TRUE | 3 TRUE / 1 FALSE | `2-2` |
| CEER | 6 | TRUE | FALSE | TRUE | TRUE | 3 TRUE / 1 FALSE | `2-2` |

These are recorded as **Table A5 discrepancies relative to the surviving coder-level data**. No source response is changed to force agreement with the manuscript table. The cOAlition S discrepancy is also consistent with manuscript prose describing a 3-to-1 decision with a human outlier. See [`provenance/TABLE_A5_REPLICATION.md`](provenance/TABLE_A5_REPLICATION.md).

## Repository structure

```text
pon_llm_pilot/
├── README.md
├── _quarto.yml                     # Quarto website configuration
├── index.qmd                       # Website landing page
├── config/
│   └── config.yml                  # Paths, protocols, model registry, and entity registry
├── input/
│   ├── boundary_objects/           # Archival PON source documents
│   └── reference/                  # Questions, human coding, and manuscript-audit inputs
├── output/
│   ├── [frozen 2024 outputs]       # Historical LLM response artifacts
│   ├── current/                    # Timestamped contemporary SBS runs
│   ├── improved/                   # Archival improved-v1 runs
│   └── berec_replication/          # Dedicated BEREC reconstruction runs
├── derived/                        # Generated tables, metrics, audits, and figures
├── R/
│   ├── analysis.R                  # Shared parsing, evaluation, and plotting functions
│   └── audit.R                     # Human-response provenance audit
├── python/
│   ├── llm_extract.py              # Shared prompt, execution, and run-finalization helpers
│   └── berec_replication.py        # BEREC-specific execution safeguards
├── scripts/                        # R/Python workflow entry points
├── reports/                        # Quarto analytical pages
└── provenance/                     # Reconstruction and methodological notes
```

`derived/`, `_site/`, runtime environments, and other local artifacts are excluded from version control by `.gitignore`. Preserved and completed run artifacts must therefore be available in the working copy before downstream analyses that depend on them can be regenerated.

## Requirements

The project uses Python, R, and Quarto. Python dependencies are declared in `requirements.txt`. R code uses `dplyr`, `ggplot2`, `jsonlite`, `knitr`, `purrr`, `readr`, `readxl`, `scales`, `stringr`, `tibble`, `tidyr`, and `yaml`.

An `OPENAI_API_KEY` is required **only** for an explicitly authorized API-backed execution. Protocol inspection, historical evaluation, Table A5 reconstruction, model comparison from completed runs, BEREC comparison, and website rendering do not themselves require API calls.

## Installation and setup

Clone the repository and enter its root directory. These commands are the same on macOS and Windows PowerShell:

```text
git clone https://github.com/ealvaradomena/pon_llm_pilot.git
cd pon_llm_pilot
```

### Python environment

#### macOS

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

#### Windows PowerShell

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### R packages

From an R session on either platform:

```r
install.packages(c(
  "dplyr",
  "ggplot2",
  "jsonlite",
  "knitr",
  "purrr",
  "readr",
  "readxl",
  "scales",
  "stringr",
  "tibble",
  "tidyr",
  "yaml"
))
```

### API credentials

Credentials are needed only for a deliberately authorized new API run. Copy `.env.example` to `.env`, then replace the placeholder with your own key.

#### macOS

```bash
cp .env.example .env
```

#### Windows PowerShell

```powershell
Copy-Item .env.example .env
```

`.env` is ignored by Git. Never commit API credentials.

## Reproduce the current analysis without new API calls

Run commands from the repository root. The normal reproduction path reuses the frozen historical outputs and already-completed contemporary runs.

### 1. Inspect the reconstructed SBS protocol

```text
python scripts/00_check_protocol.py
```

This local check reports the 15-question computational instrument, the 14-question Table A5 subset, five-PON scope, historical and contemporary model identifiers, Luna identifier provenance, endpoint, SBS suffix, and reconstructed prompt hash. It makes **no API calls**.

### 2. Reconstruct manuscript Table A5

```text
Rscript scripts/02_reconstruct_table_a5.R
```

This writes:

- `derived/table_a5_replication.csv`
- `derived/table_a5_discrepancies.csv`
- `derived/sbs_coder_comparison_extended.csv`

The historical Table A5 object remains HBM + ASC + JNG + frozen GPT-4 Turbo. The adjacent `new_llm_*` fields preserve the original configured GPT-5.4 nano extension; GPT-5.6 Luna belongs to the separate multi-model comparison layer.

### 3. Rebuild the frozen GPT-4 Turbo/human evaluation

```text
Rscript scripts/02_evaluate_preserved_outputs.R
```

This writes `derived/legacy_sbs_human_evaluation.csv`, `derived/legacy_sbs_human_metrics.csv`, and the legacy-named disagreement file `derived/legacy_sbs_human_errors.csv`. The filename is preserved for compatibility; project-facing documentation describes these rows as disagreements rather than external ground-truth errors.

### 4. Rebuild the three-model SBS comparison

```text
Rscript scripts/05_compare_scenarios.R
```

The script discovers one completed run for each model registered under `comparison.comparison_models`, combines those runs with the frozen GPT-4 Turbo SBS benchmark, validates the expected 75 decisions per model, and writes the `derived/sbs_model_*` tables and agreement figures. It makes **no API calls**.

`scripts/04_compare_models.R` is retained as a compatibility entry point and delegates to `scripts/05_compare_scenarios.R`.

### 5. Rebuild the local BEREC comparison

```text
python scripts/08_compare_berec.py
```

This compares the preserved historical BEREC artifact, the completed best-evidenced December 23 GPT-4 Turbo reconstruction, and the completed retrospective December 24 SBS GPT-5.4 nano application. It writes `derived/berec_three_way_comparison.csv`, `derived/berec_three_way_summary.csv`, and `derived/berec_sources.csv` without making API calls.

### 6. Render the website

```text
quarto render
```

Quarto renders the pages registered in `_quarto.yml` and writes the site to `_site/`. The populated analytical pages depend on the generated `derived/` products described above.

## API-backed execution safeguards

New API calls are **not** part of the normal reproduction path above.

### Principal contemporary SBS runner

`scripts/03_run_current_model.py` is dry-run by default, refuses legacy GPT-4 Turbo identifiers, excludes BEREC, and writes executions only to new timestamped directories under `output/current/`.

Dry-run example:

```text
python scripts/03_run_current_model.py --model EXACT_MODEL_ID
```

An API call occurs only when `--execute` is explicitly supplied. Completed GPT-5.4 nano and GPT-5.6 Luna arms should be reused rather than rerun merely to regenerate downstream analysis.

If an API execution completed its per-PON outputs but failed before writing `run_manifest.json`, the runner also supports local-only recovery through `--finalize-existing-run`. That path validates the existing raw/metadata pairs and writes the completion manifest without making another API call.

### Historical compatibility guard

`scripts/01_run_llm_extraction.py` intentionally refuses regeneration of the preserved historical outputs and directs contemporary work to the current-model runner.

### Archival improved-v1 workflow

`scripts/04_run_improved_protocol.py` retains the secondary improved-protocol experiment. It is dry-run by default. Any historical GPT-4 Turbo execution additionally requires the explicit `ARCHIVAL-GPT4` confirmation token, and all generated material is isolated under `output/improved/`.

## BEREC reconstruction boundary

BEREC is not a sixth case in the principal aggregate comparison. Dedicated BEREC execution is hard-guarded to `input/boundary_objects/BO1B.txt` and writes only beneath `output/berec_replication/`.

The dedicated scripts are dry-run by default and require both `--execute` and `--confirm-api-call BEREC` before making their single planned request:

```text
python scripts/06_run_berec_2024_reconstruction.py
python scripts/07_run_berec_sbs_current_model.py
```

`scripts/06_run_berec_2024_reconstruction.py` targets `gpt-4-turbo-2024-04-09` as the best-supported dated GPT-4 Turbo reconstruction snapshot. This is a **best-evidenced reconstruction**, not proof of the exact December 23 serving state or request construction.

`scripts/07_run_berec_sbs_current_model.py` applies the recovered December 24 SBS protocol to `BO1B.txt` using the configured `comparison.current_model`, currently `gpt-5.4-nano-2026-03-17`. This is a retrospective protocol replication, not reconstruction of the uncertain December 23 request.

See [`provenance/BEREC_REPLICATION.md`](provenance/BEREC_REPLICATION.md) for the full claim boundary.

## Reproducibility boundaries

The project distinguishes three levels of reproducibility:

1. **Historical reanalysis:** frozen 2024 outputs can be parsed and evaluated repeatedly without contacting OpenAI.
2. **Downstream reconstruction:** Table A5, model-comparison tables, figures, and the website can be regenerated deterministically from the required stored inputs and completed model-run artifacts.
3. **New model execution:** API-backed generations create new timestamped evidence. They are not assumed to be bit-for-bit reproducible, especially when an undated model identifier such as `gpt-5.6-luna` is used.

The contemporary runner preserves prompt hashes, requested and returned model identifiers, timestamps, response metadata when available, raw outputs, and completion manifests so that downstream analyses can identify the exact stored artifacts they used.

## Documentation

Extended documentation is available in:

- [`provenance/RECONSTRUCTION.md`](provenance/RECONSTRUCTION.md) — recovered architecture, evidence, and analysis-integrity safeguards
- [`provenance/LEGACY_API_CALLS.md`](provenance/LEGACY_API_CALLS.md) — what is and is not recoverable about the 2024 OpenAI requests
- [`provenance/TABLE_A5_REPLICATION.md`](provenance/TABLE_A5_REPLICATION.md) — manuscript Table A5 reconstruction and discrepancies
- [`provenance/BEREC_REPLICATION.md`](provenance/BEREC_REPLICATION.md) — BEREC reconstruction boundary and execution safeguards
- [`reports/methods.qmd`](reports/methods.qmd) — principal study design and protocol reconstruction
- [`reports/results.qmd`](reports/results.qmd) — 2024/Table A5 replication results
- [`reports/model-comparison.qmd`](reports/model-comparison.qmd) — three-model SBS comparison
- [`reports/comparison-table.qmd`](reports/comparison-table.qmd) — complete human/LLM classification table
- [`reports/berec.qmd`](reports/berec.qmd) — auxiliary BEREC analysis

No repository license or formal citation file is present in the inspected project snapshot, so this README does not infer licensing or citation terms.
