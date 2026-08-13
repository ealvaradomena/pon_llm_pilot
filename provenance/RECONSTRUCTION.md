# Reconstruction Notes

This working directory was reconstructed from the supplied legacy PON project while preserving the analytical logic used by the manuscript-facing computational pilot.

## Recovered source corpus

Six boundary objects were recovered and retained as `BO1A.txt` through `BO6A.txt`. `BO1A.txt` is BEREC. The remaining five map to IRG, EU Health Coalition, cOAlition S, CAN, and CEER.

## Preserved model outputs

Eleven legacy response files are retained in `output/`:

- one BEREC binary output from Dec. 23, 2024; and
- ten Dec. 24, 2024 final-pipeline outputs covering five PONs under zero-shot and step-by-step prompting.

These files are historical artifacts and are not rewritten by the repository's execution scripts.

## Instrument

The legacy computational files contain 15 ordered binary questions. The manuscript later reports 14 prompts; the working-groups question is the additional computational item. The repository keeps all 15 for protocol fidelity.

## Human-reference data

The recovered computational evaluation contains one human-reference vector per organization for the five PONs in the final Dec. 24 run. A manuscript-facing three-coder dataset was not recovered from the supplied computational workspace.

## BEREC caveat

BEREC was an early development case and is part of the source corpus. Earlier Quarto versions show a different system/user message-role layout during this stage. Because the precise code state that generated `BO1A-2024-12-23-55_cat.txt` cannot be established with confidence, BEREC's legacy/current comparison is preserved descriptively but is not pooled into strict same-protocol aggregate statistics.

## Current-model extension

The new execution layer asks how a different model behaves under the final 2024 protocol. It does not rerun or replace 2024 outputs. New raw responses and metadata are written only under `output/current/`, and derived comparisons are written under `derived/`.

See `LEGACY_API_CALLS.md` for recovered API-call details and remaining provenance gaps.
