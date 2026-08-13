"""Run the current model under the preserved 2024 zero-shot PON protocol."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from python.llm_extract import build_system_prompt, load_config, load_questions, resolve_model, run_pipeline


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run one model using the preserved 2024 zero-shot PON prompt."
    )
    parser.add_argument("--model", help="Exact OpenAI model ID to test")
    parser.add_argument(
        "--entity",
        action="append",
        dest="entities",
        help="Entity slug to run; repeat as needed. Default: five comparative-study PONs.",
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
    model = resolve_model(cfg, args.model)
    questions = load_questions(ROOT / cfg["project"]["questions_file"])

    valid_entities = {item["slug"] for item in cfg["entities"]}
    if args.entities:
        unknown = set(args.entities) - valid_entities
        if unknown:
            raise SystemExit(f"Unknown entity slug(s): {', '.join(sorted(unknown))}")

    selected_entities = args.entities or cfg["comparison"]["study_entities"]
    prompt = build_system_prompt(
        cfg["legacy_protocol"]["starter"],
        questions,
        cfg["legacy_protocol"]["techniques"]["zero_shot"]["suffix"],
    )

    print(f"Model: {model}")
    print("Protocol: 2024 legacy zero-shot Chat Completions prompt")
    print(f"PONs: {', '.join(selected_entities)}")
    print(f"Questions per request: {len(questions)}")
    print(f"Planned API requests: {len(selected_entities)}")
    print(f"System prompt length: {len(prompt)} characters")

    if not args.execute:
        print("Dry run only. Add --execute to make API calls.")
        return

    run_dir = run_pipeline(
        config_path=ROOT / "config/config.yml",
        model=model,
        entity_slugs=set(selected_entities),
    )
    print(f"Saved current-model run to: {run_dir}")


if __name__ == "__main__":
    main()
