# PON Governance LLM Pilot

README file created with ChatGPT for exceptional documentation depth.

This repository preserves the December 2024 computational evidence for the PON governance LLM pilot and adds a reproducible zero-shot comparison across **model generation × protocol**. The comparative experiment uses five PONs: IRG, EUHC, COAS, CAN, and CEER.

The final design contains six scenarios:

| Model | Protocol | Source |
|---|---|---|
| GPT-4 Turbo | 2024 protocol | Preserved Dec. 24, 2024 zero-shot output |
| GPT-5.4 nano | 2024 protocol | Retained 2026 zero-shot run |
| GPT-5.4 mini | 2024 protocol | Retained 2026 zero-shot run |
| GPT-4 Turbo | Improved protocol | 2026 improved-protocol run |
| GPT-5.4 nano | Improved protocol | 2026 improved-protocol run |
| GPT-5.4 mini | Improved protocol | 2026 improved-protocol run |

Historical step-by-step outputs remain preserved for provenance, but they are no longer part of the analytical design or new API runs.

## Study logic

The comparison holds fixed the source documents, 15 binary governance questions, Chat Completions endpoint, system/user message roles, and zero-shot design. It varies only:

1. **Model** — GPT-4 Turbo, GPT-5.4 nano, or GPT-5.4 mini.
2. **Protocol** — the recovered 2024 prompt or a concise improved prompt.

The improved prompt adds an explicit source boundary, a clear TRUE/FALSE evidence threshold, a prohibition on unstated inference, and an exact CSV row contract. It does not add examples, chain-of-thought instructions, or structured-output API parameters.

## Important model provenance

The historical 2024 code requested the alias `gpt-4-turbo`; the surviving workspace does not record the returned snapshot ID. For the improved-protocol rerun, the project therefore pins `gpt-4-turbo-2024-04-09` as the closest reproducible counterpart. This is a reproducibility improvement, not proof that the 2024 alias resolved to an identical serving state.

The contemporary arms use the pinned snapshots `gpt-5.4-nano-2026-03-17` and `gpt-5.4-mini-2026-03-17` under both protocols.

If the API no longer permits the GPT-4 Turbo snapshot, report that limitation rather than silently substituting a different model.

## Project structure

```text
pon_llm_pilot/
├── README.md
├── _quarto.yml
├── index.qmd
├── config/
│   └── config.yml
├── input/
│   ├── boundary_objects/
│   └── reference/
├── output/
│   ├── [preserved 2024 outputs]
│   ├── current/
│   └── improved/
├── derived/
│   └── figures/
├── python/
│   └── llm_extract.py
├── R/
│   └── analysis.R
├── scripts/
│   ├── 00_check_protocol.py
│   ├── 02_evaluate_preserved_outputs.R
│   ├── 03_run_current_model.py
│   ├── 04_run_improved_protocol.py
│   └── 05_compare_scenarios.R
├── reports/
│   ├── methods.qmd
│   ├── results.qmd
│   └── model-comparison.qmd
└── provenance/
```

## Set up the OpenAI API key

Copy the template from the project root:

**macOS/Linux/Git Bash**

```bash
cp .env.example .env
```

**PowerShell**

```powershell
Copy-Item .env.example .env
```

Then set the key in `.env`:

```text
OPENAI_API_KEY=sk-your-real-key-here
```

`.env` is excluded by `.gitignore`. Never commit it.

## Create the Python environment before installing libraries

Create a dedicated project-local environment from the repository root:

```bash
python -m venv .venv
```

Activate it in Windows Git Bash:

```bash
source .venv/Scripts/activate
```

On macOS/Linux:

```bash
source .venv/bin/activate
```

Confirm that the active interpreter and `pip` belong to `.venv`:

```bash
which python
python --version
python -m pip --version
```

Upgrade `pip` and install the project dependencies:

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Use `python -m pip` rather than bare `pip` so installation is explicitly tied to the active Python interpreter. `.venv/` is ignored by Git and should not be committed.

In a later Git Bash session, reactivate with:

```bash
source .venv/Scripts/activate
```

When finished:

```bash
deactivate
```

## Verify the recovered protocol without API calls

```bash
python scripts/00_check_protocol.py
```

This prints the question count, PON count, historical model alias, endpoint, and prompt hash without contacting OpenAI.

## Stage 1: run contemporary models under the 2024 zero-shot protocol

The retained GPT-5.4 nano run uses:

```bash
python scripts/03_run_current_model.py \
  --model gpt-5.4-nano-2026-03-17
```

Without `--execute`, this is a dry run. The default comparative-study run covers IRG, EUHC, COAS, CAN, and CEER and requires **5 API requests**:

```bash
python scripts/03_run_current_model.py \
  --model gpt-5.4-nano-2026-03-17 \
  --execute
```

GPT-5.4 mini is run through the same preserved protocol:

```bash
python scripts/03_run_current_model.py \
  --model gpt-5.4-mini-2026-03-17 \
  --execute
```

Each model run makes 5 API requests. New outputs are written under `output/current/`. Existing 2024 outputs are never overwritten.

## Stage 2: run the improved protocol

First inspect the plan:

```bash
python scripts/04_run_improved_protocol.py
```

By default, this uses:

```text
GPT-4 Turbo:  gpt-4-turbo-2024-04-09
GPT-5.4 nano: gpt-5.4-nano-2026-03-17
```

The default improved-protocol batch contains **10 API requests**: 5 PONs × 2 configured models (GPT-4 Turbo and GPT-5.4 nano). The stage applies a **500-token output ceiling** to each improved-protocol request. The client uses the model-appropriate Chat Completions field (`max_tokens` for GPT-4 Turbo and `max_completion_tokens` for GPT-5.4 nano). This operational cap limits response reservation without changing the classification task.

Before any API call, the runner uses `tiktoken` to estimate each two-message request. For the GPT-4 Turbo arm it compares estimated input plus the output cap with the observed 30,000-token TPM ceiling and reserves 250 tokens of safety headroom. If any request is too close to that ceiling, the runner stops locally before creating a batch directory or spending an API request. The estimate is a guardrail rather than an exact server-side token count.

Execute it with:

```bash
python scripts/04_run_improved_protocol.py --execute
```

The default two-model batch is saved under a timestamped directory in `output/improved/`, with a batch manifest and per-model manifests. The configured cap can be overridden with `--max-output-tokens N`. If a batch fails, the directory receives `batch_failed.json` instead of `batch_manifest.json`, so downstream analysis will not mistake a partial batch for a completed one.

Run GPT-5.4 mini separately under the improved protocol so the completed GPT-4 Turbo and GPT-5.4 nano batch is not repeated:

```bash
python scripts/04_run_improved_protocol.py \
  --model gpt-5.4-mini-2026-03-17 \
  --execute
```

This adds 5 API requests and writes a separate completed run under `output/improved/`.

## Improved protocol

The improved system instruction is deliberately concise:

> Use only the supplied document. For each question, answer TRUE only if the text explicitly supports it; otherwise FALSE. Do not infer unstated rules or use outside knowledge. Return exactly 15 rows as question_id,response, preceded by that header. No other text.

The ordered questions are appended as numbered CSV-style rows. For the improved-protocol runs, the request supplies `model`, `messages`, and the common output-token ceiling explicitly. All other sampling and formatting parameters remain unspecified. The shorter instruction also reduces prompt overhead for large boundary objects without altering the evidence presented to the model.

## Stage 3: build the six-scenario comparison

After all three model arms have completed under both protocols:

```bash
Rscript scripts/05_compare_scenarios.R
```

The script resolves completed runs by **exact model ID**, which prevents a newer GPT-5.4 mini run from silently replacing the GPT-5.4 nano arm.

The comparison writes tables and figures under `derived/` and evaluates all six scenarios against the same recovered human-reference labels for IRG, EUHC, COAS, CAN, and CEER.

The main outputs include:

- overall and PON-level accuracy, precision, recall, specificity, and F1;
- disagreement rates, expressed as shares rather than raw counts;
- protocol effects within each model;
- model effects within each protocol;
- question-level disagreement rates;
- TRUE-response prevalence;
- model-generation stability under both protocols; and
- output-format diagnostics.

## Render the HTML reports

```bash
quarto render
```

The website reports include numbered tables and figures, concise question callouts before plots, PON acronyms in visual displays, and a GitHub link in the upper-right navbar.

## R requirements

Install once if needed:

```r
install.packages(c(
  "dplyr",
  "ggplot2",
  "jsonlite",
  "knitr",
  "purrr",
  "readr",
  "scales",
  "stringr",
  "tibble",
  "tidyr",
  "yaml"
))
```



## BEREC exclusion

BEREC remains in the repository as archival provenance, but it is not part of the comparative experiment. Its surviving Dec. 23, 2024 output predates the final Dec. 24 message-role implementation, and its boundary object is much larger than the other study documents. The default runners, tables, figures, aggregate statistics, and analytical denominators therefore use only IRG, EUHC, COAS, CAN, and CEER. Existing BEREC files are left untouched.

## Instrument provenance

The computational workspace contains **15** binary questions, while the manuscript later reports **14** prompts. The additional computational item asks about working groups. All six scenarios retain all 15 questions so the new comparison does not alter the historical outcome space.

The recovered baseline code contains one human-reference vector per organization for five PONs. These vectors should not be conflated with the later three-human-coder validation described in the manuscript.


