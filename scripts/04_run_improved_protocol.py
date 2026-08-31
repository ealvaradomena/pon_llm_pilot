# ////////////////////////////////////////////////////
#
# PON LLM Pilot - Archival Improved-Protocol Runner
#
# Purpose
# - Dry-run or execute the preserved improved-v1 protocol workflow
# - Keep current-model and archival GPT-4 Turbo reruns explicitly separated
# - Require an additional confirmation token before any historical GPT-4 Turbo API call
#
# Requirements
# - Project configuration in config/config.yml
# - Boundary objects and questions registered by the configuration
# - OPENAI_API_KEY only when --execute is supplied
#
# AI Disclosure
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-python-scripts.md
#
# ////////////////////////////////////////////////////
"""Safely run the archival improved-v1 protocol.

Safety defaults:
- dry-run unless --execute is supplied;
- the current-model arm is the default and never implicitly runs GPT-4 Turbo;
- historical GPT-4 Turbo execution is exceptional and additionally requires
  --confirm-legacy-model-call ARCHIVAL-GPT4;
- running both arms requires explicit --arm both plus the legacy confirmation;
- preserved historical outputs are frozen and are never written by this script;
- every new improved-protocol run is written to a fresh run-specific directory
  beneath output/improved/.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from python.llm_extract import (
    build_improved_system_prompt,
    estimate_chat_input_tokens,
    load_config,
    load_questions,
    preflight_improved_requests,
    run_improved_batch,
    run_improved_model,
)


# 1. Define Historical-Model Safeguards ----

LEGACY_CONFIRMATION_TOKEN = "ARCHIVAL-GPT4"


def is_historical_gpt4_turbo(model: str, cfg: dict) -> bool:
    """Recognize configured and equivalent GPT-4 Turbo historical identifiers."""
    normalized = model.strip().lower()
    configured = {
        str(cfg["legacy_protocol"]["model_alias"]).strip().lower(),
        str(cfg["comparison"]["legacy_model"]).strip().lower(),
    }
    return normalized in configured or normalized.startswith("gpt-4-turbo")


def require_legacy_confirmation(
    *,
    execute: bool,
    models: list[str],
    confirmation: str | None,
    cfg: dict,
) -> None:
    """Block historical GPT-4 Turbo API calls without the archival token."""
    if not execute:
        return

    historical = [model for model in models if is_historical_gpt4_turbo(model, cfg)]
    if historical and confirmation != LEGACY_CONFIRMATION_TOKEN:
        raise SystemExit(
            "Historical GPT-4 Turbo API execution refused. Preserved 2024 outputs are "
            "frozen. An exceptional archival rerun requires both --execute and "
            f"--confirm-legacy-model-call {LEGACY_CONFIRMATION_TOKEN}. "
            f"Requested historical model(s): {', '.join(historical)}"
        )


# 2. Parse Command-Line Arguments ----


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Dry-run or execute the archival improved-v1 protocol. The current-model "
            "arm is selected by default; historical GPT-4 Turbo calls require an "
            "additional archival confirmation token."
        )
    )
    parser.add_argument(
        "--arm",
        choices=("current", "legacy", "both"),
        default="current",
        help=(
            "Configured arm to run. Default: current. Use 'legacy' or 'both' only for "
            "exceptional archival reconstruction; those executions require the legacy token."
        ),
    )
    parser.add_argument(
        "--model",
        help=(
            "Run one exact model ID instead of a configured arm. Historical GPT-4 Turbo "
            "identifiers still require the archival confirmation token."
        ),
    )
    parser.add_argument("--legacy-model", help="Override the configured archival GPT-4 Turbo model ID")
    parser.add_argument("--current-model", help="Override the configured current model ID")
    parser.add_argument(
        "--entity",
        action="append",
        dest="entities",
        help="Entity slug to run; repeat as needed. Default: five comparative-study PONs.",
    )
    parser.add_argument(
        "--max-output-tokens",
        type=int,
        help="Override the configured output-token cap for the selected arm(s).",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually call the API. Without this flag, print a dry-run summary only.",
    )
    parser.add_argument(
        "--confirm-legacy-model-call",
        default=None,
        metavar="ARCHIVAL-GPT4",
        help=(
            "Additional safeguard required for any GPT-4 Turbo API call. The exact token is "
            f"{LEGACY_CONFIRMATION_TOKEN}."
        ),
    )
    return parser.parse_args()


# 3. Prepare Shared Dry-Run Information ----


def print_single_model_plan(
    *,
    cfg: dict,
    questions: list[str],
    prompt: str,
    model: str,
    selected_entities: list[str],
    max_output_tokens: int,
    role: str,
) -> None:
    print("Protocol: improved-v1 zero-shot Chat Completions prompt [ARCHIVAL/SECONDARY]")
    print(f"Selected arm: {role}")
    print(f"Model: {model}")
    print(f"PONs: {', '.join(selected_entities)}")
    print(f"Questions per request: {len(questions)}")
    print(f"Planned API requests: {len(selected_entities)}")
    print(f"System prompt length: {len(prompt)} characters")
    print(f"Output-token cap: {max_output_tokens} per request")
    print(f"Output root: {cfg['project']['improved_output_dir']} (new run-specific directory only)")
    print("Preserved historical root-level outputs: FROZEN / NEVER WRITTEN")
    print("Estimated input + output cap:")

    entities_by_slug = {item["slug"]: item for item in cfg["entities"]}
    for entity_slug in selected_entities:
        entity = entities_by_slug[entity_slug]
        bo_path = ROOT / cfg["project"]["boundary_object_dir"] / entity["boundary_object"]
        boundary_text = bo_path.read_text(encoding="utf-8")
        input_tokens = estimate_chat_input_tokens(
            model=model,
            system_prompt=prompt,
            user_message=boundary_text,
        )
        projected_tokens = input_tokens + max_output_tokens
        print(
            f"  {entity['short_name']}: {input_tokens:,} + {max_output_tokens:,} "
            f"= {projected_tokens:,} tokens"
        )


# 4. Run the Workflow ----


def main() -> None:
    args = parse_args()
    cfg = load_config(ROOT / "config/config.yml")
    questions = load_questions(ROOT / cfg["project"]["questions_file"])

    legacy_model = args.legacy_model or cfg["comparison"]["legacy_model"]
    current_model = args.current_model or cfg["comparison"]["current_model"]
    max_output_tokens = (
        args.max_output_tokens
        if args.max_output_tokens is not None
        else cfg["improved_protocol"]["max_output_tokens"]
    )

    if max_output_tokens <= 0:
        raise SystemExit("--max-output-tokens must be greater than zero")

    valid_entities = {item["slug"] for item in cfg["entities"]}
    if args.entities:
        unknown = set(args.entities) - valid_entities
        if unknown:
            raise SystemExit(f"Unknown entity slug(s): {', '.join(sorted(unknown))}")

    selected_entities = args.entities or cfg["comparison"]["study_entities"]
    prompt = build_improved_system_prompt(cfg["improved_protocol"]["starter"], questions)

    if args.model:
        if args.legacy_model or args.current_model or args.arm != "current":
            raise SystemExit(
                "--model cannot be combined with --legacy-model, --current-model, or a non-default --arm"
            )
        require_legacy_confirmation(
            execute=args.execute,
            models=[args.model],
            confirmation=args.confirm_legacy_model_call,
            cfg=cfg,
        )
        role = "archival historical model" if is_historical_gpt4_turbo(args.model, cfg) else "explicit single model"
        print_single_model_plan(
            cfg=cfg,
            questions=questions,
            prompt=prompt,
            model=args.model,
            selected_entities=selected_entities,
            max_output_tokens=max_output_tokens,
            role=role,
        )
        if not args.execute:
            print("Dry run only. API calls: NONE. Add --execute to make the planned call(s).")
            if is_historical_gpt4_turbo(args.model, cfg):
                print(
                    "Historical execution additionally requires: "
                    f"--confirm-legacy-model-call {LEGACY_CONFIRMATION_TOKEN}"
                )
            return

        run_dir = run_improved_model(
            config_path=ROOT / "config/config.yml",
            model=args.model,
            entity_slugs=set(selected_entities),
            max_output_tokens=max_output_tokens,
        )
        print(f"Saved improved-protocol run to: {run_dir}")
        return

    if args.arm == "current":
        selected_model = current_model
        require_legacy_confirmation(
            execute=args.execute,
            models=[selected_model],
            confirmation=args.confirm_legacy_model_call,
            cfg=cfg,
        )
        print_single_model_plan(
            cfg=cfg,
            questions=questions,
            prompt=prompt,
            model=selected_model,
            selected_entities=selected_entities,
            max_output_tokens=max_output_tokens,
            role="current",
        )
        if not args.execute:
            print("Dry run only. API calls: NONE. Add --execute to run the current-model arm only.")
            return

        run_dir = run_improved_model(
            config_path=ROOT / "config/config.yml",
            model=selected_model,
            entity_slugs=set(selected_entities),
            max_output_tokens=max_output_tokens,
        )
        print(f"Saved current-model improved-protocol run to: {run_dir}")
        return

    if args.arm == "legacy":
        require_legacy_confirmation(
            execute=args.execute,
            models=[legacy_model],
            confirmation=args.confirm_legacy_model_call,
            cfg=cfg,
        )
        print_single_model_plan(
            cfg=cfg,
            questions=questions,
            prompt=prompt,
            model=legacy_model,
            selected_entities=selected_entities,
            max_output_tokens=max_output_tokens,
            role="legacy archival",
        )
        if not args.execute:
            print("Dry run only. API calls: NONE.")
            print(
                "Historical execution requires: --arm legacy --execute "
                f"--confirm-legacy-model-call {LEGACY_CONFIRMATION_TOKEN}"
            )
            return

        run_dir = run_improved_model(
            config_path=ROOT / "config/config.yml",
            model=legacy_model,
            entity_slugs=set(selected_entities),
            max_output_tokens=max_output_tokens,
        )
        print(f"Saved archival GPT-4 Turbo improved-protocol run to: {run_dir}")
        return

    # Explicit --arm both is the only path that can couple the configured arms.
    require_legacy_confirmation(
        execute=args.execute,
        models=[legacy_model, current_model],
        confirmation=args.confirm_legacy_model_call,
        cfg=cfg,
    )

    print("Protocol: improved-v1 zero-shot Chat Completions prompt [ARCHIVAL/SECONDARY]")
    print("Selected arm: both [EXPLICIT COUPLED ARCHIVAL RUN]")
    print(f"Legacy-model arm: {legacy_model}")
    print(f"Current-model arm: {current_model}")
    print(f"PONs: {', '.join(selected_entities)}")
    print(f"Questions per request: {len(questions)}")
    print(f"Planned API requests: {2 * len(selected_entities)}")
    print(f"System prompt length: {len(prompt)} characters")
    print(f"Output-token cap: {max_output_tokens} per request")
    print(f"Output root: {cfg['project']['improved_output_dir']} (new batch directory only)")
    print("Preserved historical root-level outputs: FROZEN / NEVER WRITTEN")

    try:
        preflight = preflight_improved_requests(
            cfg=cfg,
            legacy_model=legacy_model,
            current_model=current_model,
            entity_slugs=set(selected_entities),
            max_output_tokens=max_output_tokens,
        )
    except RuntimeError as exc:
        raise SystemExit(str(exc)) from exc

    legacy_rows = [row for row in preflight if row["model_role"] == "legacy"]
    print("GPT-4 Turbo preflight (estimated input + output cap):")
    for row in legacy_rows:
        print(
            f"  {row['entity_slug'].upper()}: "
            f"{row['input_tokens_estimated']:,} + {row['max_output_tokens']:,} "
            f"= {row['projected_tokens']:,} tokens"
        )
    print(f"Preflight safety ceiling: {legacy_rows[0]['safe_tpm_ceiling']:,} tokens per request")

    if not args.execute:
        print("Dry run only. API calls: NONE.")
        print(
            "Coupled execution requires: --arm both --execute "
            f"--confirm-legacy-model-call {LEGACY_CONFIRMATION_TOKEN}"
        )
        return

    batch_dir = run_improved_batch(
        config_path=ROOT / "config/config.yml",
        legacy_model=legacy_model,
        current_model=current_model,
        entity_slugs=set(selected_entities),
        max_output_tokens=max_output_tokens,
    )
    print(f"Saved improved-protocol batch to: {batch_dir}")


if __name__ == "__main__":
    main()
