# Table A5 Replication

This note records the reproducible reconstruction of manuscript Table A5, *Coder agreement per prompt across PONs*.

## Inputs

The reconstruction uses:

- the three individual human coders in `input/reference/legacy_human_responses_confirmed.csv`, displayed as **HBM**, **ASC**, and **JNG**;
- the five frozen Dec. 24, 2024 step-by-step (`*_sbs.txt`) GPT-4 Turbo outputs in `output/`;
- the 14-question manuscript subset of the 15-question computational instrument; and
- `input/reference/manuscript_table_a5.csv`, a row-level transcription of the manuscript's published Table A5 agreement cells.

The working-groups item is computational question 10 and is excluded only from the Table A5 reconstruction. It remains part of the 15-question computational protocol.

## Clear agreement terminology

Project-facing outputs do not use the manuscript's opaque `1`, `0`, `3-1`, and `2-2` shorthand as the primary description. Instead they report explicit counts such as:

- `4 TRUE / 0 FALSE`;
- `3 TRUE / 1 FALSE`;
- `2 TRUE / 2 FALSE`;
- `1 TRUE / 3 FALSE`; and
- `0 TRUE / 4 FALSE`.

Human-only agreement is reported analogously across HBM, ASC, and JNG. The manuscript shorthand is retained in separate fields solely for faithful comparison. LLM agreement with the three-human majority vote is reported explicitly.

## Three Table A5 discrepancies

The surviving raw human data and frozen legacy SBS outputs reconstruct 67 of 70 Table A5 cells exactly. Three manuscript cells report `2-2` even though the surviving four responses produce a 3-to-1 split.

| PON | Manuscript prompt | HBM | ASC | JNG | Legacy LLM SBS | Surviving pattern | Table A5 | Conclusion |
|---|---:|---|---|---|---|---|---|---|
| IRG | 3 | FALSE | FALSE | TRUE | FALSE | 1 TRUE / 3 FALSE | `2-2` | Table A5 does not match the surviving raw data. |
| cOAlition S | 8 | FALSE | TRUE | TRUE | TRUE | 3 TRUE / 1 FALSE | `2-2` | Table A5 does not match the raw data; manuscript prose independently describes this as a 3-1 decision with a human outlier. |
| CEER | 6 | TRUE | FALSE | TRUE | TRUE | 3 TRUE / 1 FALSE | `2-2` | Table A5 does not match the surviving raw data. |

These are recorded as **Table A5 errors**. No source response is altered to force agreement with the manuscript table.

## Reproduce the audit

```bash
Rscript scripts/02_reconstruct_table_a5.R
```

The script makes no API calls and writes:

- `derived/table_a5_replication.csv` — all 70 manuscript cells;
- `derived/table_a5_discrepancies.csv` — the three discrepant cells; and
- `derived/sbs_coder_comparison_extended.csv` — all 15 computational questions, including human majority, legacy LLM agreement, and the newer-model SBS response when a completed newer-model run is available.

The historical Table A5 reconstruction always remains a four-coder object: HBM + ASC + JNG + frozen 2024 LLM. The newer model is added only as an adjacent extension and never retroactively folded into the manuscript's four-coder agreement pattern.
