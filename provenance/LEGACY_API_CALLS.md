# 2024 OpenAI API Call Provenance

This note documents what can and cannot be recovered about the API calls that produced the preserved 2024 model outputs.

## High-confidence findings

The late-2024 Quarto source uses the OpenAI Python client with the `OpenAI()` client class and the Chat Completions endpoint:

```python
completion = client.chat.completions.create(
    model=models,
    messages=[
        {"role": "system", "content": prompt},
        {"role": "user", "content": text},
    ],
)
```

For the December 24 final pipeline:

- requested model alias: `gpt-4-turbo`;
- endpoint: Chat Completions (`/v1/chat/completions`);
- system message: the policy-analyst instruction plus the ordered binary questions;
- user message: the full boundary-object text;
- prompting conditions: zero-shot and the same prompt with `Let's think step by step` appended;
- explicit request arguments: `model` and `messages` only;
- no explicit `temperature`, `top_p`, `max_tokens`, `seed`, `response_format`, tool configuration, or other generation parameters;
- response text saved from `completion.choices[0].message.content`;
- output filenames contain local datetimes generated with Python `datetime.now()`; timezone information was not recorded.

The preserved Dec. 24 output set covers IRG, EU Health Coalition, cOAlition S, CAN, and CEER under both prompting conditions.

## BEREC provenance

`output/BO1A-2024-12-23-55_cat.txt` is the preserved BEREC binary-output file from December 23, 2024. The original source-state provenance is incomplete. For all new dedicated BEREC replication experiments, the project now requires `input/boundary_objects/BO1B.txt`; those experiments do not rewrite or replace the historical artifact.

However, BEREC predates the final Dec. 24 implementation. Earlier report versions around the BEREC development stage show a different message-role layout in which the boundary-object text was passed as the system message and the question prompt as the user message. The surviving materials do not establish with enough certainty which exact source-code state produced the Dec. 23 BEREC file. For that reason:

- the BEREC file is retained as an authentic legacy output;
- BEREC is excluded from the main five-PON SBS pipeline and is handled only through dedicated BEREC execution workflows;
- all new dedicated BEREC experiments use `input/boundary_objects/BO1B.txt` and keep the best-evidenced historical reconstruction separate from contemporary Dec. 24 SBS protocol replication;
- BEREC's legacy/current classification differences are reported descriptively;
- BEREC is excluded from aggregate statistics labeled as a **strict same-protocol comparison**.

## Information not recoverable from the preserved files

The following were not stored with the 2024 response text and therefore cannot be reconstructed reliably:

- the returned model snapshot actually recorded by the 2024 API response (the surviving text does not store it);
- OpenAI response ID and HTTP request ID;
- `system_fingerprint`;
- token usage and cost per request;
- server-side defaults actually applied to unspecified generation parameters;
- exact OpenAI Python package version;
- request retry history;
- local timezone associated with the timestamps in filenames.

The contemporary SBS runner records these fields whenever the API returns them so that subsequent comparisons have stronger provenance.

## Credential note

One legacy Quarto source contained an API key directly in source code. That credential is intentionally **not** copied into this repository or this provenance note. If the historical credential has not already been revoked, it should be rotated. The reconstructed project reads credentials only from `OPENAI_API_KEY` and ignores `.env` in version control.


## Current snapshot evidence

OpenAI currently documents `gpt-4-turbo-2024-04-09` as the dated GPT-4 Turbo snapshot and lists Chat Completions support. It is marked deprecated. This makes it the best-supported dated snapshot for a controlled reconstruction, but it does not retroactively prove what serving state produced a preserved 2024 response. See `BEREC_REPLICATION.md`.
