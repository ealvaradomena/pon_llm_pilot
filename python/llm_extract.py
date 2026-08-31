# ////////////////////////////////////////////////////
#
# PON LLM Pilot - LLM Extraction Helpers
#
# Purpose
# - Build reconstructed extraction prompts and execute model runs
# - Preserve historical outputs while saving new responses and metadata to isolated run directories
#
# Requirements
# - Project configuration in config/config.yml
# - Boundary-object and question files registered by the configuration
# - OPENAI_API_KEY only for functions that explicitly execute API requests
#
# AI Disclosure
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-python-scripts.md
#
# ////////////////////////////////////////////////////
"""Run PON extraction protocols with reproducible OpenAI model IDs.

The primary contemporary workflow reproduces the manuscript-facing December 2024
step-by-step (SBS) prompt while preserving all historical outputs unchanged. The
older improved-protocol helpers remain available for archival reproducibility but
are not part of the primary comparison. Raw model text is always saved unchanged.
"""

from __future__ import annotations

import csv
import hashlib
import json
import os
import re
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import yaml
import tiktoken


# 1. Represent Project Entities ----

@dataclass(frozen=True)
class Entity:
    name: str
    short_name: str
    slug: str
    boundary_object: str
    berec_replication_boundary_object: str | None = None


# 2. Load Configuration and Questions ----

def load_config(path: str | Path = "config/config.yml") -> dict:
    with Path(path).open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def load_questions(path: str | Path) -> list[str]:
    with Path(path).open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    questions = [row["question"].strip() for row in rows]
    if not questions:
        raise ValueError("No questions found")
    return questions


# 3. Build Protocol Prompts ----

def build_system_prompt(starter: str, questions: Iterable[str], suffix: str = "") -> str:
    """Reproduce the exact string concatenation used in the 2024 code."""
    return starter + suffix + "The questions are: " + " ".join(questions)


def build_improved_system_prompt(starter: str, questions: Iterable[str]) -> str:
    """Build the concise improved prompt with explicit question IDs."""
    numbered = "\n".join(
        f"{index},{question}"
        for index, question in enumerate(questions, start=1)
    )
    return f"{starter}\n\nQuestions:\n{numbered}"


# 4. Prepare Reproducibility and API Utilities ----

def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_model_slug(model: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", model).strip("-") or "model"


def _response_headers(raw_response) -> dict[str, str | None]:
    headers = getattr(raw_response, "headers", {}) or {}
    wanted = [
        "x-request-id",
        "openai-processing-ms",
        "openai-version",
        "date",
    ]
    return {key: headers.get(key) for key in wanted if headers.get(key) is not None}


def _load_client() -> Any:
    from dotenv import load_dotenv
    from openai import OpenAI

    load_dotenv()
    if not os.getenv("OPENAI_API_KEY"):
        raise RuntimeError("OPENAI_API_KEY is not set. See README.md for setup instructions.")
    return OpenAI()


def _output_limit_parameter(model: str) -> str:
    """Use the output-limit field supported by the selected model family."""
    if model.startswith("gpt-5"):
        return "max_completion_tokens"
    return "max_tokens"


def _encoding_for_model(model: str):
    """Return the closest tokenizer available for a pinned model ID."""
    try:
        return tiktoken.encoding_for_model(model)
    except KeyError:
        fallback = "o200k_base" if model.startswith("gpt-5") else "cl100k_base"
        return tiktoken.get_encoding(fallback)


def estimate_chat_input_tokens(
    model: str,
    system_prompt: str,
    user_message: str,
) -> int:
    """Estimate input tokens for this project's two-message Chat Completions call.

    Chat framing can vary by serving implementation, so this is intentionally an
    estimate. The preflight applies a separate safety margin before API execution.
    """
    encoding = _encoding_for_model(model)
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message},
    ]

    # Approximate current Chat Completions framing: three tokens per message plus
    # a three-token assistant primer, in addition to encoded role/content text.
    token_count = 3
    for message in messages:
        token_count += 3
        token_count += len(encoding.encode(message["role"]))
        token_count += len(encoding.encode(message["content"]))

    return token_count


def preflight_improved_requests(
    cfg: dict,
    legacy_model: str,
    current_model: str,
    entity_slugs: set[str] | None,
    max_output_tokens: int,
) -> list[dict[str, Any]]:
    """Estimate request sizes and block GPT-4 calls too near the observed TPM cap."""
    questions = load_questions(cfg["project"]["questions_file"])
    prompt = build_improved_system_prompt(
        cfg["improved_protocol"]["starter"],
        questions,
    )
    legacy_tpm_limit = int(cfg["improved_protocol"]["legacy_tpm_limit"])
    headroom = int(cfg["improved_protocol"]["preflight_headroom_tokens"])
    safe_ceiling = legacy_tpm_limit - headroom

    rows: list[dict[str, Any]] = []
    for role, model in [("legacy", legacy_model), ("current", current_model)]:
        for entity in _selected_entities(cfg, entity_slugs):
            bo_path = Path(cfg["project"]["boundary_object_dir"]) / entity.boundary_object
            if not bo_path.exists():
                raise FileNotFoundError(bo_path)

            boundary_text = bo_path.read_text(encoding="utf-8")
            input_tokens = estimate_chat_input_tokens(
                model=model,
                system_prompt=prompt,
                user_message=boundary_text,
            )
            projected_tokens = input_tokens + max_output_tokens
            rows.append(
                {
                    "model_role": role,
                    "model": model,
                    "entity_slug": entity.slug,
                    "input_tokens_estimated": input_tokens,
                    "max_output_tokens": max_output_tokens,
                    "projected_tokens": projected_tokens,
                    "safe_tpm_ceiling": safe_ceiling if role == "legacy" else None,
                }
            )

    unsafe = [
        row
        for row in rows
        if row["model_role"] == "legacy"
        and row["projected_tokens"] >= safe_ceiling
    ]
    if unsafe:
        details = "; ".join(
            f"{row['entity_slug']}: ~{row['projected_tokens']:,} tokens"
            for row in unsafe
        )
        raise RuntimeError(
            "Preflight blocked GPT-4 Turbo request(s) too close to the configured "
            f"{legacy_tpm_limit:,}-TPM limit after reserving {headroom:,} tokens "
            f"of headroom: {details}. Shorten prompt overhead or adjust the "
            "account-specific preflight settings only after verifying the API limit."
        )

    return rows


# 5. Execute One SBS Request ----

def run_one(
    client: Any,
    model: str,
    bo_path: Path,
    questions: list[str],
    system_prompt: str,
    entity: Entity,
    protocol_name: str,
    run_dir: Path,
    max_output_tokens: int | None = None,
    technique: str = "Zero-shot",
    technique_code: str = "z",
) -> tuple[Path, Path]:
    """Execute one request and save raw text plus request metadata."""
    boundary_text = bo_path.read_text(encoding="utf-8")

    # Build the request explicitly so provenance records the operational cap.
    request_kwargs: dict[str, Any] = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": boundary_text},
        ],
    }
    output_limit_parameter = None

    if max_output_tokens is not None:
        output_limit_parameter = _output_limit_parameter(model)
        request_kwargs[output_limit_parameter] = max_output_tokens

    raw_response = client.chat.completions.with_raw_response.create(**request_kwargs)
    completion = raw_response.parse()

    content = completion.choices[0].message.content or ""
    requested_at = datetime.now(timezone.utc)

    stem = f"{bo_path.stem}_{entity.slug}_{technique_code}"
    text_path = run_dir / f"{stem}.txt"
    metadata_path = run_dir / f"{stem}.json"

    # Raw response text is the research artifact; never normalize it here.
    text_path.write_text(content, encoding="utf-8")

    usage = getattr(completion, "usage", None)
    metadata = {
        "protocol": protocol_name,
        "endpoint": "chat.completions",
        "requested_model": model,
        "returned_model": getattr(completion, "model", None),
        "completion_id": getattr(completion, "id", None),
        "completion_created": getattr(completion, "created", None),
        "system_fingerprint": getattr(completion, "system_fingerprint", None),
        "finish_reason": completion.choices[0].finish_reason,
        "entity": entity.name,
        "entity_slug": entity.slug,
        "boundary_object": bo_path.name,
        "boundary_object_sha256": sha256_file(bo_path),
        "technique": technique,
        "technique_code": technique_code,
        "question_count": len(questions),
        "system_prompt_sha256": sha256_text(system_prompt),
        "system_prompt": system_prompt,
        "user_message_sha256": sha256_text(boundary_text),
        "request_parameters_explicitly_supplied": list(request_kwargs),
        "output_token_limit": {
            "parameter": output_limit_parameter,
            "value": max_output_tokens,
        } if max_output_tokens is not None else None,
        "request_parameters_intentionally_unspecified": [
            parameter
            for parameter in [
                "temperature",
                "max_tokens",
                "max_completion_tokens",
                "top_p",
                "seed",
                "response_format",
                "tools",
            ]
            if parameter not in request_kwargs
        ],
        "request_timestamp_utc": requested_at.isoformat(),
        "response_headers": _response_headers(raw_response),
        "usage": usage.model_dump() if usage is not None else None,
        "raw_output_file": text_path.name,
        "raw_output_sha256": sha256_file(text_path),
    }
    metadata_path.write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    return text_path, metadata_path


# 6. Resolve and Run the Primary SBS Pipeline ----

def resolve_model(cfg: dict, cli_model: str | None) -> str:
    model = cli_model or cfg.get("comparison", {}).get("current_model")
    if not model:
        raise ValueError(
            "No comparison model is configured. Pass --model EXACT_MODEL_ID or set "
            "comparison.current_model in config/config.yml."
        )
    return str(model)


def _selected_entities(cfg: dict, entity_slugs: set[str] | None) -> list[Entity]:
    entities = [Entity(**item) for item in cfg["entities"]]
    if entity_slugs:
        entities = [entity for entity in entities if entity.slug in entity_slugs]
    return entities


def _json_safe(value: Any) -> Any:
    """Normalize YAML-native date/datetime values before JSON serialization."""
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    return value


def _comparison_model_provenance(cfg: dict, model: str) -> dict:
    """Return JSON-safe configured provenance metadata for one comparison model."""
    for item in cfg.get("comparison", {}).get("comparison_models", []):
        if str(item.get("model_id")) == model:
            return _json_safe({
                key: value
                for key, value in item.items()
                if key not in {"label", "model_id"}
            })
    return {}


def _returned_model_ids(run_dir: Path, generated: list[dict[str, str]]) -> list[str]:
    """Collect unique API-returned model identifiers from completed sidecars."""
    returned: set[str] = set()
    for row in generated:
        metadata_path = run_dir / row["metadata"]
        if not metadata_path.exists():
            continue
        try:
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        model_id = metadata.get("returned_model")
        if model_id:
            returned.add(str(model_id))
    return sorted(returned)


def run_pipeline(
    config_path: str | Path = "config/config.yml",
    model: str | None = None,
    entity_slugs: set[str] | None = None,
) -> Path:
    """Run the manuscript-facing 2024 SBS prompt with one selected contemporary model."""
    cfg = load_config(config_path)
    selected_model = resolve_model(cfg, model)
    model_provenance = _comparison_model_provenance(cfg, selected_model)
    questions = load_questions(cfg["project"]["questions_file"])
    legacy_forbidden = {
        str(cfg["legacy_protocol"]["model_alias"]),
        str(cfg["comparison"]["legacy_model"]),
    }
    if selected_model in legacy_forbidden or selected_model.lower().startswith("gpt-4-turbo"):
        raise RuntimeError(
            "The primary current-model runner refuses legacy GPT-4 Turbo IDs. "
            "Historical 2024 outputs are frozen and must not be regenerated."
        )

    selected_entities = _selected_entities(cfg, entity_slugs)
    if any(entity.slug == "berec" for entity in selected_entities):
        raise RuntimeError(
            "BEREC is excluded from the primary five-PON SBS runner. "
            "Use the dedicated BEREC execution scripts."
        )

    run_stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_id = f"{run_stamp}_{safe_model_slug(selected_model)}"
    run_dir = Path(cfg["project"]["current_output_dir"]) / run_id
    run_dir.mkdir(parents=True, exist_ok=False)
    started_utc = datetime.now(timezone.utc).isoformat()

    prompt = build_system_prompt(
        cfg["legacy_protocol"]["starter"],
        questions,
        cfg["legacy_protocol"]["techniques"]["step_by_step"]["suffix"],
    )

    generated: list[dict[str, str]] = []
    processing_pon: str | None = None

    try:
        client = _load_client()
        for entity in selected_entities:
            processing_pon = entity.slug
            bo_path = Path(cfg["project"]["boundary_object_dir"]) / entity.boundary_object
            if not bo_path.exists():
                raise FileNotFoundError(bo_path)

            text_path, metadata_path = run_one(
                client=client,
                model=selected_model,
                bo_path=bo_path,
                questions=questions,
                system_prompt=prompt,
                entity=entity,
                protocol_name="2024-sbs",
                run_dir=run_dir,
                technique="Step-by-step (SBS)",
                technique_code="sbs",
            )
            generated.append(
                {
                    "entity_slug": entity.slug,
                    "raw_output": text_path.name,
                    "metadata": metadata_path.name,
                }
            )
            processing_pon = None

    except Exception as exc:
        output_files = sorted(
            path.name
            for path in run_dir.iterdir()
            if path.is_file() and path.name not in {"run_manifest.json", "run_failed.json"}
        )
        failure_manifest = {
            "status": "failed",
            "protocol": "2024-sbs",
            "protocol_version": "reconstructed-dec24-2024-sbs",
            "requested_model": selected_model,
            "model_provenance": model_provenance,
            "run_id": run_id,
            "started_utc": started_utc,
            "failed_utc": datetime.now(timezone.utc).isoformat(),
            "config_file": str(config_path),
            "question_count": len(questions),
            "input_pons": [entity.slug for entity in selected_entities],
            "completed_pons": [row["entity_slug"] for row in generated],
            "returned_model_ids": _returned_model_ids(run_dir, generated),
            "processing_pon": processing_pon,
            "generated": generated,
            "output_files": output_files,
            "error_type": type(exc).__name__,
            "error_message": str(exc),
        }
        (run_dir / "run_failed.json").write_text(
            json.dumps(failure_manifest, indent=2),
            encoding="utf-8",
        )
        raise

    output_files = [
        filename
        for row in generated
        for filename in (row["raw_output"], row["metadata"])
    ]
    manifest = {
        "status": "complete",
        "protocol": "2024-sbs",
        "protocol_version": "reconstructed-dec24-2024-sbs",
        "requested_model": selected_model,
        "model_provenance": model_provenance,
        "run_id": run_id,
        "started_utc": started_utc,
        "completed_utc": datetime.now(timezone.utc).isoformat(),
        "created_utc": started_utc,
        "config_file": str(config_path),
        "question_count": len(questions),
        "input_pons": [entity.slug for entity in selected_entities],
        "completed_pons": [row["entity_slug"] for row in generated],
        "returned_model_ids": _returned_model_ids(run_dir, generated),
        "generated": generated,
        "output_files": output_files,
    }
    (run_dir / "run_manifest.json").write_text(
        json.dumps(manifest, indent=2),
        encoding="utf-8",
    )
    return run_dir



def finalize_existing_run(
    run_dir: str | Path,
    config_path: str | Path = "config/config.yml",
) -> Path:
    """Finalize a completed current-model run locally without making API calls.

    This recovery path is intentionally limited to a run directory that already
    contains one raw-output/metadata pair for every configured study entity.
    It exists so a manifest-writing failure cannot force duplicate API requests.
    """
    cfg = load_config(config_path)
    run_dir = Path(run_dir)
    configured_root = Path(cfg["project"]["current_output_dir"]).resolve()
    resolved_run_dir = run_dir.resolve()
    if configured_root not in resolved_run_dir.parents:
        raise RuntimeError(
            f"Refusing to finalize a directory outside {configured_root}: {resolved_run_dir}"
        )
    if not run_dir.is_dir():
        raise FileNotFoundError(run_dir)
    if (run_dir / "run_manifest.json").exists():
        raise RuntimeError(f"Run already has run_manifest.json: {run_dir}")

    metadata_paths = sorted(
        path for path in run_dir.glob("*.json")
        if path.name not in {"run_manifest.json", "run_failed.json"}
    )
    metadata_rows = [
        json.loads(path.read_text(encoding="utf-8"))
        for path in metadata_paths
    ]
    expected_entities = list(cfg["comparison"]["study_entities"])
    if len(metadata_rows) != len(expected_entities):
        raise RuntimeError(
            f"Expected {len(expected_entities)} metadata sidecars; found {len(metadata_rows)}. "
            "Do not finalize an incomplete run."
        )

    entity_slugs = [str(row.get("entity_slug")) for row in metadata_rows]
    if set(entity_slugs) != set(expected_entities) or len(entity_slugs) != len(set(entity_slugs)):
        raise RuntimeError(
            "Metadata sidecars do not contain exactly one row for each configured study PON."
        )

    requested_models = {str(row.get("requested_model")) for row in metadata_rows}
    if len(requested_models) != 1:
        raise RuntimeError(f"Expected one requested model; found: {sorted(requested_models)}")
    selected_model = next(iter(requested_models))
    if selected_model.lower().startswith("gpt-4-turbo"):
        raise RuntimeError(
            "Refusing to finalize a legacy GPT-4 Turbo run in the current-model workflow."
        )

    expected_question_count = len(load_questions(cfg["project"]["questions_file"]))
    for row in metadata_rows:
        if int(row.get("question_count", -1)) != expected_question_count:
            raise RuntimeError(
                "Unexpected question count in "
                f"{row.get('entity_slug')}: {row.get('question_count')}"
            )
        raw_name = row.get("raw_output_file")
        if not raw_name or not (run_dir / str(raw_name)).is_file():
            raise RuntimeError(f"Missing raw output for {row.get('entity_slug')}: {raw_name}")
        if sha256_file(run_dir / str(raw_name)) != row.get("raw_output_sha256"):
            raise RuntimeError(f"Raw-output hash mismatch for {row.get('entity_slug')}")

    prompt_hashes = {str(row.get("system_prompt_sha256")) for row in metadata_rows}
    if len(prompt_hashes) != 1:
        raise RuntimeError("Metadata sidecars do not share one system-prompt hash.")

    generated = [
        {
            "entity_slug": str(row["entity_slug"]),
            "raw_output": str(row["raw_output_file"]),
            "metadata": path.name,
        }
        for path, row in zip(metadata_paths, metadata_rows)
    ]
    generated.sort(key=lambda row: expected_entities.index(row["entity_slug"]))

    timestamps = sorted(
        str(row["request_timestamp_utc"])
        for row in metadata_rows
        if row.get("request_timestamp_utc")
    )
    finalized_utc = datetime.now(timezone.utc).isoformat()
    started_utc = timestamps[0] if timestamps else None
    completed_utc = timestamps[-1] if timestamps else None
    output_files = [
        filename
        for row in generated
        for filename in (row["raw_output"], row["metadata"])
    ]
    manifest = {
        "status": "complete",
        "protocol": "2024-sbs",
        "protocol_version": "reconstructed-dec24-2024-sbs",
        "requested_model": selected_model,
        "model_provenance": _comparison_model_provenance(cfg, selected_model),
        "run_id": run_dir.name,
        "started_utc": started_utc,
        "completed_utc": completed_utc,
        "created_utc": started_utc,
        "finalized_utc": finalized_utc,
        "manifest_recovered_locally": True,
        "recovery_reason": (
            "API requests and per-PON artifacts completed, but initial manifest serialization "
            "failed because a YAML date value was not JSON serializable. Manifest finalized "
            "locally after validating all five metadata/raw-output pairs; no API calls were made."
        ),
        "config_file": str(config_path),
        "question_count": expected_question_count,
        "input_pons": expected_entities,
        "completed_pons": [row["entity_slug"] for row in generated],
        "returned_model_ids": _returned_model_ids(run_dir, generated),
        "generated": generated,
        "output_files": output_files,
    }
    (run_dir / "run_manifest.json").write_text(
        json.dumps(manifest, indent=2),
        encoding="utf-8",
    )
    print("API calls: NONE")
    print(f"Validated existing artifacts: {len(generated)} PONs")
    print(f"Requested model: {selected_model}")
    print(f"Returned model IDs: {', '.join(manifest['returned_model_ids']) or '(none recorded)'}")
    print(f"Finalized manifest: {run_dir / 'run_manifest.json'}")
    return run_dir


# 7. Preserve the Archival Improved-Protocol Workflow ----

def _assert_isolated_improved_output_root(cfg: dict) -> Path:
    """Require improved-protocol reruns to stay below a dedicated subdirectory."""
    root = Path(cfg["project"]["improved_output_dir"])
    legacy_root = Path("output")
    if root.resolve() == legacy_root.resolve():
        raise RuntimeError(
            "Unsafe improved-protocol output root: output/ contains frozen historical artifacts. "
            "Use a dedicated subdirectory such as output/improved/."
        )
    return root

def run_improved_model(
    config_path: str | Path = "config/config.yml",
    model: str | None = None,
    entity_slugs: set[str] | None = None,
    max_output_tokens: int | None = None,
) -> Path:
    """Run one selected model under the improved zero-shot protocol."""
    cfg = load_config(config_path)
    questions = load_questions(cfg["project"]["questions_file"])
    client = _load_client()

    selected_model = resolve_model(cfg, model)
    max_output_tokens = (
        max_output_tokens
        if max_output_tokens is not None
        else cfg["improved_protocol"].get("max_output_tokens")
    )

    prompt = build_improved_system_prompt(
        cfg["improved_protocol"]["starter"],
        questions,
    )

    improved_root = _assert_isolated_improved_output_root(cfg)
    run_stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = improved_root / f"{run_stamp}_{safe_model_slug(selected_model)}"
    run_dir.mkdir(parents=True, exist_ok=False)

    generated: list[dict[str, str]] = []

    try:
        for entity in _selected_entities(cfg, entity_slugs):
            bo_path = Path(cfg["project"]["boundary_object_dir"]) / entity.boundary_object
            if not bo_path.exists():
                raise FileNotFoundError(bo_path)

            text_path, metadata_path = run_one(
                client=client,
                model=selected_model,
                bo_path=bo_path,
                questions=questions,
                system_prompt=prompt,
                entity=entity,
                protocol_name=cfg["improved_protocol"]["name"],
                run_dir=run_dir,
                max_output_tokens=max_output_tokens,
            )

            generated.append(
                {
                    "entity_slug": entity.slug,
                    "raw_output": text_path.name,
                    "metadata": metadata_path.name,
                }
            )

    except Exception as exc:
        # Preserve the partial-run audit trail without marking it complete.
        failure_manifest = {
            "status": "failed",
            "protocol": cfg["improved_protocol"]["name"],
            "requested_model": selected_model,
            "failed_utc": datetime.now(timezone.utc).isoformat(),
            "error_type": type(exc).__name__,
            "error_message": str(exc),
            "max_output_tokens": max_output_tokens,
            "generated_before_failure": generated,
        }
        (run_dir / "run_failed.json").write_text(
            json.dumps(failure_manifest, indent=2),
            encoding="utf-8",
        )
        raise

    manifest = {
        "status": "complete",
        "protocol": cfg["improved_protocol"]["name"],
        "requested_model": selected_model,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "question_count": len(questions),
        "max_output_tokens": max_output_tokens,
        "generated": generated,
    }
    (run_dir / "run_manifest.json").write_text(
        json.dumps(manifest, indent=2),
        encoding="utf-8",
    )

    return run_dir

def run_improved_batch(
    config_path: str | Path = "config/config.yml",
    legacy_model: str | None = None,
    current_model: str | None = None,
    entity_slugs: set[str] | None = None,
    max_output_tokens: int | None = None,
) -> Path:
    """Run both model generations under the same improved zero-shot prompt."""
    cfg = load_config(config_path)
    questions = load_questions(cfg["project"]["questions_file"])

    legacy_model = legacy_model or cfg["comparison"]["legacy_model"]
    current_model = current_model or cfg["comparison"]["current_model"]
    max_output_tokens = (
        max_output_tokens
        if max_output_tokens is not None
        else cfg["improved_protocol"].get("max_output_tokens")
    )
    models = [("legacy", legacy_model), ("current", current_model)]

    # Refuse locally before creating artifacts or spending an API request if the
    # legacy-model arm is still too close to the observed TPM ceiling.
    preflight_rows = preflight_improved_requests(
        cfg=cfg,
        legacy_model=legacy_model,
        current_model=current_model,
        entity_slugs=entity_slugs,
        max_output_tokens=max_output_tokens,
    )
    client = _load_client()

    prompt = build_improved_system_prompt(
        cfg["improved_protocol"]["starter"],
        questions,
    )

    improved_root = _assert_isolated_improved_output_root(cfg)
    batch_stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    batch_dir = improved_root / batch_stamp
    batch_dir.mkdir(parents=True, exist_ok=False)

    model_runs: list[dict[str, str]] = []
    generated_total: list[dict[str, str]] = []

    try:
        for role, model in models:
            run_dir = batch_dir / safe_model_slug(model)
            run_dir.mkdir(parents=True, exist_ok=False)
            generated: list[dict[str, str]] = []

            for entity in _selected_entities(cfg, entity_slugs):
                bo_path = Path(cfg["project"]["boundary_object_dir"]) / entity.boundary_object
                if not bo_path.exists():
                    raise FileNotFoundError(bo_path)

                text_path, metadata_path = run_one(
                    client=client,
                    model=model,
                    bo_path=bo_path,
                    questions=questions,
                    system_prompt=prompt,
                    entity=entity,
                    protocol_name=cfg["improved_protocol"]["name"],
                    run_dir=run_dir,
                    max_output_tokens=max_output_tokens,
                )
                generated_row = {
                    "entity_slug": entity.slug,
                    "raw_output": text_path.name,
                    "metadata": metadata_path.name,
                }
                generated.append(generated_row)
                generated_total.append(
                    {
                        "model_role": role,
                        "requested_model": model,
                        **generated_row,
                    }
                )

            manifest = {
                "status": "complete",
                "protocol": cfg["improved_protocol"]["name"],
                "model_role": role,
                "requested_model": model,
                "created_utc": datetime.now(timezone.utc).isoformat(),
                "question_count": len(questions),
                "max_output_tokens": max_output_tokens,
                "generated": generated,
            }
            (run_dir / "run_manifest.json").write_text(
                json.dumps(manifest, indent=2),
                encoding="utf-8",
            )
            model_runs.append(
                {
                    "role": role,
                    "requested_model": model,
                    "run_dir": str(run_dir),
                }
            )

    except Exception as exc:
        # Preserve a compact failure record while withholding the completion manifest.
        failure_manifest = {
            "status": "failed",
            "protocol": cfg["improved_protocol"]["name"],
            "failed_utc": datetime.now(timezone.utc).isoformat(),
            "error_type": type(exc).__name__,
            "error_message": str(exc),
            "max_output_tokens": max_output_tokens,
            "generated_before_failure": generated_total,
        }
        (batch_dir / "batch_failed.json").write_text(
            json.dumps(failure_manifest, indent=2),
            encoding="utf-8",
        )
        raise

    batch_manifest = {
        "status": "complete",
        "protocol": cfg["improved_protocol"]["name"],
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "models": model_runs,
        "question_count": len(questions),
        "max_output_tokens": max_output_tokens,
        "preflight": {
            "legacy_tpm_limit": int(cfg["improved_protocol"]["legacy_tpm_limit"]),
            "headroom_tokens": int(
                cfg["improved_protocol"]["preflight_headroom_tokens"]
            ),
            "estimates": preflight_rows,
        },
    }
    (batch_dir / "batch_manifest.json").write_text(
        json.dumps(batch_manifest, indent=2),
        encoding="utf-8",
    )
    return batch_dir
