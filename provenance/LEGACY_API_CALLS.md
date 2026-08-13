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

`BO1A.txt` is BEREC's boundary object, and `output/BO1A-2024-12-23-55_cat.txt` is a preserved BEREC binary-output file from December 23, 2024.

However, BEREC predates the final Dec. 24 implementation. Earlier report versions around the BEREC development stage show a different message-role layout in which the boundary-object text was passed as the system message and the question prompt as the user message. The surviving materials do not establish with enough certainty which exact source-code state produced the Dec. 23 BEREC file. For that reason:

- the BEREC file is retained as an authentic legacy output;
- the current pipeline runs BEREC under the final manuscript-facing Dec. 24 protocol, alongside the other five PONs;
- BEREC's legacy/current classification differences are reported descriptively;
- BEREC is excluded from aggregate statistics labeled as a **strict same-protocol comparison**.

## Information not recoverable from the preserved files

The following were not stored with the 2024 response text and therefore cannot be reconstructed reliably:

- exact resolved model snapshot behind the `gpt-4-turbo` alias at each request;
- OpenAI response ID and HTTP request ID;
- `system_fingerprint`;
- token usage and cost per request;
- server-side defaults actually applied to unspecified generation parameters;
- exact OpenAI Python package version;
- request retry history;
- local timezone associated with the timestamps in filenames.

The current-model runner records these fields whenever the contemporary API returns them so that future comparisons have stronger provenance.

## Credential note

One legacy Quarto source contained an API key directly in source code. That credential is intentionally **not** copied into this repository or this provenance note. If the historical credential has not already been revoked, it should be rotated. The reconstructed project reads credentials only from `OPENAI_API_KEY` and ignores `.env` in version control.
