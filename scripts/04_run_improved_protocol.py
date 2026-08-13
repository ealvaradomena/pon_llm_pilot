"""Run the two study models under the concise improved zero-shot protocol."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from python.llm_extract import (
    build_improved_system_prompt,
    load_config,
    load_questions,
    estimate_chat_input_tokens,
    preflight_improved_requests,
    run_improved_batch,
    run_improved_model,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run both model generations under the improved zero-shot protocol."
    )
    parser.add_argument(
        "--model",
        help="Run one exact model ID under the improved protocol instead of both configured arms.",
    )
    parser.add_argument("--legacy-model", help="Pinned GPT-4 Turbo model ID")
    parser.add_argument("--current-model", help="Exact current model ID")
    parser.add_argument(
        "--entity",
        action="append",
        dest="entities",
        help="Entity slug to run; repeat as needed. Default: five comparative-study PONs.",
    )
    parser.add_argument(
        "--max-output-tokens",
        type=int,
        help="Override the configured output-token cap for both model arms.",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually call the API. Without this flag, print a dry-run summary only.",
    )
    return parser.parse_args()


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
    prompt = build_improved_system_prompt(
        cfg["improved_protocol"]["starter"],
        questions,
    )

    if args.model:
        if args.legacy_model or args.current_model:
            raise SystemExit(
                "--model cannot be combined with --legacy-model or --current-model"
            )

        print("Protocol: improved-v1 zero-shot Chat Completions prompt")
        print(f"Model: {args.model}")
        print(f"PONs: {', '.join(selected_entities)}")
        print(f"Questions per request: {len(questions)}")
        print(f"Planned API requests: {len(selected_entities)}")
        print(f"System prompt length: {len(prompt)} characters")
        print(f"Output-token cap: {max_output_tokens} per request")
        print("Estimated input + output cap:")

        entities_by_slug = {
            item["slug"]: item
            for item in cfg["entities"]
        }

        for entity_slug in selected_entities:
            entity = entities_by_slug[entity_slug]
            bo_path = ROOT / cfg["project"]["boundary_object_dir"] / entity["boundary_object"]
            boundary_text = bo_path.read_text(encoding="utf-8")

            input_tokens = estimate_chat_input_tokens(
                model=args.model,
                system_prompt=prompt,
                user_message=boundary_text,
            )
            projected_tokens = input_tokens + max_output_tokens

            print(
                f"  {entity['short_name']}: "
                f"{input_tokens:,} + {max_output_tokens:,} "
                f"= {projected_tokens:,} tokens"
            )

        if not args.execute:
            print("Dry run only. Add --execute to make API calls.")
            return

        run_dir = run_improved_model(
            config_path=ROOT / "config/config.yml",
            model=args.model,
            entity_slugs=set(selected_entities),
            max_output_tokens=max_output_tokens,
        )
        print(f"Saved improved-protocol run to: {run_dir}")
        return

    print("Protocol: improved-v1 zero-shot Chat Completions prompt")
    print(f"Legacy-model arm: {legacy_model}")
    print(f"Current-model arm: {current_model}")
    print(f"PONs: {', '.join(selected_entities)}")
    print(f"Questions per request: {len(questions)}")
    print(f"Planned API requests: {2 * len(selected_entities)}")
    print(f"System prompt length: {len(prompt)} characters")
    print(f"Output-token cap: {max_output_tokens} per request")

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
    print(
        "Preflight safety ceiling: "
        f"{legacy_rows[0]['safe_tpm_ceiling']:,} tokens per request"
    )

    if not args.execute:
        print("Dry run only. Add --execute to make API calls.")
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
