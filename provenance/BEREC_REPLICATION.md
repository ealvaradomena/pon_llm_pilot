# BEREC Replication

BEREC is kept separate from the five-PON strict comparison because its preserved Dec. 23, 2024 output predates the final Dec. 24 implementation and the exact request state cannot be proven from the surviving artifacts.

## Required BEREC source

All dedicated BEREC replication scripts are hard-guarded to:

`input/boundary_objects/BO1B.txt`

They do **not** use `BO1A.txt` for new BEREC replication calls.

## Model provenance

The surviving 2024 source requested the moving alias `gpt-4-turbo`. It did not save the returned model identifier, request ID, `system_fingerprint`, or other serving metadata.

OpenAI's current GPT-4 Turbo documentation lists `gpt-4-turbo-2024-04-09` as the dated GPT-4 Turbo snapshot and still lists Chat Completions support. The snapshot is marked deprecated. As of 2026-08-30, it is therefore the best-supported dated snapshot for a controlled reconstruction and is still documented as callable, but the preserved Dec. 23 response itself does not prove that exact serving snapshot.

Reference: https://developers.openai.com/api/docs/models/gpt-4-turbo

## Replication claims

| Level | Definition | BEREC status |
|---|---|---|
| Exact replication | Same exact 2024 BEREC request protocol + same exact dated snapshot | **Not defensible from surviving evidence.** The dated snapshot is available, but the precise Dec. 23 BEREC prompt/message state is uncertain. |
| Model-family replication | Same exact BEREC protocol + GPT-4 Turbo family, different snapshot | The protocol uncertainty remains, so this cannot become a strict replication merely by changing snapshots. |
| Protocol replication | Recovered Dec. 24 SBS protocol + a currently available newer model | **Feasible.** This is explicitly a retrospective application of the recovered Dec. 24 SBS protocol to BEREC, not a claim about the original Dec. 23 call. |

The project therefore uses the term **best-evidenced Dec. 23 reconstruction** for the historical-snapshot experiment.

## Dedicated scripts and safeguards

### Best-evidenced Dec. 23 reconstruction

Dry run; no API call:

```bash
python scripts/06_run_berec_2024_reconstruction.py
```

The script pins `gpt-4-turbo-2024-04-09`, uses `BO1B.txt`, and reconstructs the best-evidenced early message-role layout: BEREC text as the system message and the reconstructed question prompt as the user message.

Execution requires **both** safeguards:

```bash
python scripts/06_run_berec_2024_reconstruction.py \
  --execute \
  --confirm-api-call BEREC
```

### Dec. 24 SBS protocol with the newer model

Dry run; no API call:

```bash
python scripts/07_run_berec_sbs_current_model.py
```

Execute only after reviewing the dry run:

```bash
python scripts/07_run_berec_sbs_current_model.py \
  --execute \
  --confirm-api-call BEREC
```

Both scripts plan exactly one API request, refuse any BEREC source other than `BO1B.txt`, write only to a new timestamped directory under `output/berec_replication/`, refuse overwriting existing run directories, and never write to the preserved root-level legacy BEREC artifact.
