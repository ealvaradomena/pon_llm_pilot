# PON Governance LLM Pilot

README file created with generative AI for exceptional documentation depth.
See: https://github.com/ealvaradomena/my-prompts/tree/main/prompts/readme-builder

This repository preserves the December 2024 computational evidence for the PON governance LLM pilot and supports a reproducible **step-by-step (SBS) model-generation comparison** without regenerating the historical LLM outputs.

The principal analysis holds the reconstructed December 24, 2024 SBS protocol fixed across five purpose-oriented networks (PONs)—IRG, EUHC, cOAlition S, CAN, and CEER—and compares the frozen 2024 GPT-4 Turbo responses with a newer pinned model.

## Overview

The revised workflow has four goals:

1. preserve the original 2024 LLM responses as immutable historical artifacts;
2. reconstruct and audit the manuscript-facing SBS protocol and Table A5;
3. run the same SBS protocol with `gpt-5.4-nano-2026-03-17`; and
4. compare both LLM generations with the confirmed three-human reference data.

The main comparison is:

| Model | Protocol | Source |
|---|---|---|
| GPT-4 Turbo | Reconstructed 2024 SBS | Frozen December 24, 2024 `*_sbs.txt` outputs |
| GPT-5.4 nano (`gpt-5.4-nano-2026-03-17`) | Reconstructed 2024 SBS | New timestamped run under `output/current/` |

Plain-zero-shot (`*_z.txt`) and `improved-v1` materials remain preserved for provenance but are not part of the principal revised analysis.

## Core analytical decisions

- **Historical benchmark:** manuscript-facing SBS rather than plain zero-shot
- **New model:** `gpt-5.4-nano-2026-03-17` for the principal new-model run
- **Human reference:** `input/reference/legacy_human_responses_confirmed.csv`
- **Human coder labels:** HBM, ASC, and JNG
- **Human-majority comparison:** both LLMs are explicitly evaluated against the majority response of HBM/ASC/JNG
- **Instrument:** the computational protocol retains 15 questions; manuscript Table A5 reconstruction uses the 14-question subset excluding computational question 10 (working groups)
- **BEREC:** excluded from the strict five-PON comparison and handled only through dedicated scripts using `input/boundary_objects/BO1B.txt`
- **Legacy-output policy:** original 2024 LLM responses are read-only historical evidence and must never be regenerated or overwritten

## Table A5 reconstruction

The project reconstructs the manuscript's historical four-coder agreement table from HBM + ASC + JNG + the frozen GPT-4 Turbo SBS responses. Project-facing outputs replace the manuscript's opaque `1`, `0`, `3-1`, and `2-2` shorthand with explicit counts such as `3 TRUE / 1 FALSE`. The original manuscript notation remains in a separate field for direct comparison.

Three manuscript cells do not match the surviving raw responses:

| PON | Prompt | HBM | ASC | JNG | Legacy LLM SBS | Surviving pattern | Table A5 |
|---|---:|---|---|---|---|---|---|
| IRG | 3 | FALSE | FALSE | TRUE | FALSE | 1 TRUE / 3 FALSE | `2-2` |
| cOAlition S | 8 | FALSE | TRUE | TRUE | TRUE | 3 TRUE / 1 FALSE | `2-2` |
| CEER | 6 | TRUE | FALSE | TRUE | TRUE | 3 TRUE / 1 FALSE | `2-2` |

The project records these as **Table A5 errors** without altering any source response. The cOAlition S case is additionally corroborated by the manuscript prose, which describes the case as a 3–1 decision with a human outlier. See [`provenance/TABLE_A5_REPLICATION.md`](provenance/TABLE_A5_REPLICATION.md).

## Repository structure

```text
pon_llm_pilot/
├── README.md
├── _quarto.yml                     # Quarto website configuration
├── index.qmd                       # Website landing page
├── config/
│   └── config.yml                  # Models, protocols, paths, and entity registry
├── input/
│   ├── boundary_objects/           # PON source documents
│   └── reference/                  # Questions, human coding, manuscript audit inputs
├── output/
│   ├── [frozen 2024 outputs]       # Immutable historical LLM responses
│   ├── current/                    # New timestamped SBS runs
│   ├── improved/                   # Archival/secondary improved-protocol runs
│   └── berec_replication/          # Dedicated BEREC reconstruction runs
├── derived/                        # Locally generated tables, metrics, and figures
├── R/
│   ├── analysis.R                  # Shared analysis functions
│   └── audit.R                     # Human-response provenance audit
├── python/
│   ├── llm_extract.py              # Shared extraction and run helpers
│   └── berec_replication.py        # BEREC-specific safety and execution helpers
├── scripts/                        # Executable analysis and API-run entry points
├── reports/                        # Quarto website/report source pages
└── provenance/                     # Historical reconstruction and audit notes
```

Generated `_site/` content is intentionally excluded from version control and should not be edited by hand.

## Requirements

The repository uses:

- Python with the packages listed in `requirements.txt`;
- R with `dplyr`, `ggplot2`, `jsonlite`, `knitr`, `purrr`, `readr`, `readxl`, `scales`, `stringr`, `tibble`, `tidyr`, and `yaml`;
- Quarto to render the website; and
- an OpenAI API key **only** for explicitly authorized new model calls.

Downstream audits and comparisons based on already-preserved outputs do not require an API call.

## Installation and setup

Run commands from the repository root.

### 1. Create a project-local Python environment

#### macOS

```bash
python3 -m venv .venv
source .venv/bin/activate
which python
python --version
python -m pip --version
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

#### Windows PowerShell

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
Get-Command python
python --version
python -m pip --version
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

The interpreter checks should resolve to the project-local `.venv` before dependencies are installed.

### 2. Install the required R packages

From an R session on either macOS or Windows:

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

### 3. Configure the OpenAI API key

This step is required only for new API-backed runs. Copy `.env.example` to `.env` and replace the placeholder value.

#### macOS

```bash
cp .env.example .env
```

#### Windows PowerShell

```powershell
Copy-Item .env.example .env
```

Then edit `.env` so it contains:

```text
OPENAI_API_KEY=YOUR_API_KEY_HERE
```

`.env` is excluded by `.gitignore`. Never commit API credentials.

## Reproduce the revised SBS analysis

The workflow is deliberately ordered so all local checks occur before any API execution.

### 1. Verify the reconstructed protocol — no API calls

```bash
python scripts/00_check_protocol.py
```

Expected output includes:

- 15 computational questions;
- 14 Table A5 questions;
- excluded computational question ID 10;
- five comparative PONs;
- historical alias `gpt-4-turbo`;
- best-supported dated GPT-4 Turbo snapshot `gpt-4-turbo-2024-04-09`;
- newer comparison model `gpt-5.4-nano-2026-03-17`; and
- the reconstructed SBS prompt SHA-256.

This command makes **zero API calls**.

### 2. Reconstruct the historical Table A5 audit — no API calls

```bash
Rscript scripts/02_reconstruct_table_a5.R
```

Expected outputs:

- `derived/table_a5_replication.csv`
- `derived/table_a5_discrepancies.csv`
- `derived/sbs_coder_comparison_extended.csv`

Before a completed new SBS run exists, the newer-model fields are written as `NA`. Re-run this script after the new-model execution to populate them.

### 3. Rebuild the frozen 2024 SBS human-reference evaluation — no API calls

```bash
Rscript scripts/02_evaluate_preserved_outputs.R
```

Expected outputs:

- `derived/legacy_sbs_human_evaluation.csv`
- `derived/legacy_sbs_human_metrics.csv`
- `derived/legacy_sbs_human_errors.csv`

### 4. Dry-run the newer SBS model — no API calls

The runner is dry-run by default:

```bash
python scripts/03_run_current_model.py \
  --model gpt-5.4-nano-2026-03-17
```

Expected dry-run information includes five planned requests, the SBS prompt hash, and the new-output root under `output/current/`. The runner refuses legacy GPT-4 Turbo model IDs and refuses BEREC.

### 5. Execute the newer SBS model

Only after reviewing the dry run:

```bash
python scripts/03_run_current_model.py \
  --model gpt-5.4-nano-2026-03-17 \
  --execute
```

Expected behavior:

- exactly **5 API requests**: IRG, EUHC, COAS, CAN, and CEER;
- one new timestamped directory below `output/current/`;
- five raw `*_sbs.txt` response files;
- five JSON metadata sidecars; and
- one `run_manifest.json`.

The preserved root-level `output/BO*-2024-*.txt` files remain untouched.

### 6. Rebuild the extended coder comparison — no API calls

```bash
Rscript scripts/02_reconstruct_table_a5.R
```

The output now includes the newer-model SBS response and explicit `legacy_llm_agrees_human_majority` and `new_llm_agrees_human_majority` fields.

### 7. Compare frozen legacy SBS with newer-model SBS — no API calls

```bash
Rscript scripts/05_compare_scenarios.R
```

Expected outputs include:

- `derived/sbs_model_sources.csv`
- `derived/sbs_model_evaluation_long.csv`
- `derived/sbs_model_metrics_by_pon.csv`
- `derived/sbs_model_metrics_overall.csv`
- `derived/sbs_model_question_performance.csv`
- `derived/sbs_model_response_prevalence.csv`
- `derived/sbs_model_stability_by_pon.csv`
- `derived/sbs_model_stability_overall.csv`
- `derived/sbs_output_format_diagnostics.csv`
- `derived/figures/sbs_model_disagreement_by_pon.png`
- `derived/figures/sbs_model_question_disagreement.png`

### 8. Render the website

```bash
quarto render
```

The website is generated from `_quarto.yml`, `index.qmd`, `reports/methods.qmd`, `reports/results.qmd`, and `reports/model-comparison.qmd`. Rendering writes the site to `_site/`.

### 9. Verify historical outputs were untouched

```bash
git status
```

No preserved root-level 2024 LLM response should appear as modified.

## BEREC replication

BEREC is intentionally isolated from the five-PON comparison. All dedicated BEREC execution uses **`input/boundary_objects/BO1B.txt`** and writes only beneath `output/berec_replication/`.

The dedicated scripts are dry-run by default and require both `--execute` and `--confirm-api-call BEREC` before making an API request. They plan exactly one request per execution and never write to the preserved historical BEREC output path.

### Replication status

The 2024 code requested the moving alias `gpt-4-turbo`. The preserved responses do not contain the returned snapshot ID. `gpt-4-turbo-2024-04-09` is recorded as the best-supported dated GPT-4 Turbo snapshot for controlled reconstruction, but the repository does **not** claim that the preserved artifact proves the exact serving snapshot or exact December 23 BEREC request state.

See [`provenance/BEREC_REPLICATION.md`](provenance/BEREC_REPLICATION.md).

### Best-evidenced December 23 reconstruction

Dry run — **no API call**:

```bash
python scripts/06_run_berec_2024_reconstruction.py
```

Explicit execution:

```bash
python scripts/06_run_berec_2024_reconstruction.py \
  --execute \
  --confirm-api-call BEREC
```

This uses `BO1B.txt` and the configured `gpt-4-turbo-2024-04-09` snapshot. It is labeled a **best-evidenced reconstruction**, not an exact-replication claim.

### Reconstructed December 24 SBS protocol applied to BEREC

Dry run — **no API call**:

```bash
python scripts/07_run_berec_sbs_current_model.py
```

Explicit execution:

```bash
python scripts/07_run_berec_sbs_current_model.py \
  --execute \
  --confirm-api-call BEREC
```

This is **protocol replication with the configured newer model**, not reconstruction of BEREC's uncertain December 23 request.

## Archival improved-protocol materials

`scripts/04_run_improved_protocol.py`, `output/improved/`, and the related derived products are retained for provenance. They are no longer part of the principal analysis or website narrative and do not need to be rerun for the revised SBS study.

## Documentation

Extended project documentation is available in:

- [`provenance/RECONSTRUCTION.md`](provenance/RECONSTRUCTION.md) — recovered historical workflow and evidence
- [`provenance/LEGACY_API_CALLS.md`](provenance/LEGACY_API_CALLS.md) — recovered 2024 API-call behavior
- [`provenance/TABLE_A5_REPLICATION.md`](provenance/TABLE_A5_REPLICATION.md) — manuscript Table A5 audit and discrepancies
- [`provenance/BEREC_REPLICATION.md`](provenance/BEREC_REPLICATION.md) — BEREC replication claims, limitations, and safeguards
- `reports/methods.qmd`, `reports/results.qmd`, and `reports/model-comparison.qmd` — source pages for the rendered analytical website

## Reproducibility boundaries

The repository separates three types of evidence:

- **frozen historical outputs**, which can be reanalyzed without another API call;
- **deterministic downstream analysis**, which can be regenerated from the preserved responses and reference files; and
- **new API-backed model runs**, which create new timestamped artifacts and should not be described as bit-for-bit reproducible model generations.

The workflow preserves model identifiers, prompt hashes, output files, and metadata so later comparisons can establish exactly which stored artifacts were analyzed without altering the historical record.
