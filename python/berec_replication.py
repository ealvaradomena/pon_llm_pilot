# ////////////////////////////////////////////////////
#
# PON LLM Pilot - BEREC Replication Helpers
#
# Purpose
# - Provide safety-focused helpers for dedicated BEREC replication experiments
# - Keep BEREC API runs isolated from preserved legacy outputs
#
# Requirements
# - Project configuration in config/config.yml
# - BEREC replication boundary object input/boundary_objects/BO1B.txt
# - OPENAI_API_KEY only when an explicitly confirmed execution path loads the API client
#
# AI Disclosure
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-python-scripts.md
#
# ////////////////////////////////////////////////////
"""Safety-focused helpers for dedicated BEREC replication experiments."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from python.llm_extract import (
    Entity,
    _load_client,
    _response_headers,
    build_system_prompt,
    load_config,
    load_questions,
    safe_model_slug,
    sha256_file,
    sha256_text,
)

# 1. Define BEREC Safety Controls ----

CONFIRMATION_TOKEN = "BEREC"


def berec_paths(cfg: dict) -> tuple[Entity, Path]:
    row = next(item for item in cfg["entities"] if item["slug"] == "berec")
    bo_name = row.get("berec_replication_boundary_object")
    if bo_name != "BO1B.txt":
        raise RuntimeError(
            "BEREC replication is hard-guarded to input/boundary_objects/BO1B.txt."
        )
    entity = Entity(**row)
    bo_path = Path(cfg["project"]["boundary_object_dir"]) / bo_name
    if not bo_path.exists():
        raise FileNotFoundError(bo_path)
    return entity, bo_path


def require_execution_confirmation(execute: bool, confirmation: str | None) -> None:
    if not execute:
        return
    if confirmation != CONFIRMATION_TOKEN:
        raise RuntimeError(
            "API execution refused. To make the single planned BEREC API call, "
            "supply both --execute and --confirm-api-call BEREC."
        )


def create_isolated_run_dir(cfg: dict, mode: str, model: str) -> Path:
    root = Path(cfg["project"]["berec_output_dir"])
    # Never permit a BEREC replication root that is the historical output root.
    if root.resolve() == Path("output").resolve():
        raise RuntimeError("Unsafe BEREC output root: output/ is reserved for legacy artifacts.")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = root / f"{stamp}_{mode}_{safe_model_slug(model)}"
    run_dir.mkdir(parents=True, exist_ok=False)
    return run_dir


# 2. Run the Best-Evidenced December 23 Reconstruction ----

def run_dec23_best_evidenced(config_path: Path) -> Path:
    """One-call reconstruction using the best-evidenced early message-role layout.

    This is deliberately NOT labeled exact replication: the surviving materials do
    not prove the exact Dec. 23 prompt state. BO1B is the required BEREC source.
    """
    cfg = load_config(config_path)
    questions = load_questions(Path(cfg["project"]["questions_file"]))
    entity, bo_path = berec_paths(cfg)
    model = str(cfg["comparison"]["legacy_model"])

    # Best-evidenced early layout: BEREC text as system message, question prompt as user.
    question_prompt = build_system_prompt(
        cfg["legacy_protocol"]["starter"], questions, ""
    )
    boundary_text = bo_path.read_text(encoding="utf-8")
    run_dir = create_isolated_run_dir(cfg, "dec23_reconstructed", model)
    client = _load_client()

    request_kwargs = {
        "model": model,
        "messages": [
            {"role": "system", "content": boundary_text},
            {"role": "user", "content": question_prompt},
        ],
    }

    try:
        raw_response = client.chat.completions.with_raw_response.create(**request_kwargs)
        completion = raw_response.parse()
        content = completion.choices[0].message.content or ""
        text_path = run_dir / "BO1B_berec_dec23_reconstructed.txt"
        text_path.write_text(content, encoding="utf-8")
        usage = getattr(completion, "usage", None)
        metadata = {
            "status": "complete",
            "replication_claim": "best-evidenced Dec. 23 reconstruction; not exact replication",
            "protocol": "berec-dec23-reconstructed",
            "requested_model": model,
            "returned_model": getattr(completion, "model", None),
            "completion_id": getattr(completion, "id", None),
            "system_fingerprint": getattr(completion, "system_fingerprint", None),
            "finish_reason": completion.choices[0].finish_reason,
            "boundary_object": bo_path.name,
            "boundary_object_sha256": sha256_file(bo_path),
            "system_message_sha256": sha256_text(boundary_text),
            "user_message_sha256": sha256_text(question_prompt),
            "question_count": len(questions),
            "request_parameters_explicitly_supplied": ["model", "messages"],
            "request_parameters_intentionally_unspecified": [
                "temperature", "max_tokens", "max_completion_tokens", "top_p",
                "seed", "response_format", "tools"
            ],
            "request_timestamp_utc": datetime.now(timezone.utc).isoformat(),
            "response_headers": _response_headers(raw_response),
            "usage": usage.model_dump() if usage is not None else None,
            "raw_output_file": text_path.name,
            "raw_output_sha256": sha256_file(text_path),
        }
        (run_dir / "run_manifest.json").write_text(
            json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        return run_dir
    except Exception as exc:
        (run_dir / "run_failed.json").write_text(
            json.dumps({
                "status": "failed",
                "protocol": "berec-dec23-reconstructed",
                "requested_model": model,
                "error_type": type(exc).__name__,
                "error_message": str(exc),
                "failed_utc": datetime.now(timezone.utc).isoformat(),
            }, indent=2), encoding="utf-8"
        )
        raise


# 3. Run the December 24 SBS Protocol with the Newer Model ----

def run_dec24_sbs_current(config_path: Path) -> Path:
    """Apply the recovered Dec. 24 SBS protocol to BO1B with the newer model."""
    from python.llm_extract import run_one

    cfg = load_config(config_path)
    questions = load_questions(Path(cfg["project"]["questions_file"]))
    entity, bo_path = berec_paths(cfg)
    model = str(cfg["comparison"]["current_model"])
    # forbidden = {str(cfg["legacy_protocol"]["model_alias"]), str(cfg["comparison"]["legacy_model"])}
    # if model in forbidden:
    #     raise RuntimeError("Current BEREC SBS runner refuses legacy GPT-4 Turbo model IDs.")
    forbidden = {str(cfg["legacy_protocol"]["model_alias"]),str(cfg["comparison"]["legacy_model"]),}

    if model in forbidden or model.lower().startswith("gpt-4-turbo"):
        raise RuntimeError("Current BEREC SBS runner refuses legacy GPT-4 Turbo model IDs.")

    prompt = build_system_prompt(
        cfg["legacy_protocol"]["starter"],
        questions,
        cfg["legacy_protocol"]["techniques"]["step_by_step"]["suffix"],
    )
    run_dir = create_isolated_run_dir(cfg, "dec24_sbs_current", model)
    client = _load_client()

    try:
        text_path, metadata_path = run_one(
            client=client,
            model=model,
            bo_path=bo_path,
            questions=questions,
            system_prompt=prompt,
            entity=entity,
            protocol_name="berec-dec24-sbs-current",
            run_dir=run_dir,
            technique="Step-by-step (SBS)",
            technique_code="sbs",
        )
        manifest = {
            "status": "complete",
            "replication_claim": "protocol replication: recovered Dec. 24 SBS protocol applied to BEREC BO1B",
            "requested_model": model,
            "protocol": "berec-dec24-sbs-current",
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "boundary_object": "BO1B.txt",
            "generated": [{"raw_output": text_path.name, "metadata": metadata_path.name}],
        }
        (run_dir / "run_manifest.json").write_text(
            json.dumps(manifest, indent=2), encoding="utf-8"
        )
        return run_dir
    except Exception as exc:
        (run_dir / "run_failed.json").write_text(
            json.dumps({
                "status": "failed",
                "protocol": "berec-dec24-sbs-current",
                "requested_model": model,
                "error_type": type(exc).__name__,
                "error_message": str(exc),
                "failed_utc": datetime.now(timezone.utc).isoformat(),
            }, indent=2), encoding="utf-8"
        )
        raise
