# ////////////////////////////////////////////////////
#
# PON LLM Pilot - Current-Model SBS Runner
#
# Purpose
# - Dry-run or execute the reconstructed December 2024 SBS protocol with a newer model
# - Refuse legacy GPT-4 Turbo identifiers and keep BEREC outside the principal workflow
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
"""Run a newer model under the reconstructed 2024 SBS PON protocol.

Safety defaults:
- dry-run unless --execute is supplied;
- the five preserved 2024 GPT-4 Turbo outputs are never regenerated;
- legacy GPT-4 Turbo IDs are refused by both this wrapper and the shared runner;
- new files are written only to a new timestamped directory under output/current/.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from python.llm_extract import (
    build_system_prompt,
    load_config,
    load_questions,
    resolve_model,
    run_pipeline,
)


# 1. Parse Command-Line Arguments ----

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run one newer model using the reconstructed 2024 step-by-step (SBS) PON prompt."
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


# 2. Run the Workflow ----

def main() -> None:
    args = parse_args()
    cfg = load_config(ROOT / "config/config.yml")
    model = resolve_model(cfg, args.model)
    questions = load_questions(ROOT / cfg["project"]["questions_file"])

    forbidden_models = {
        str(cfg["legacy_protocol"]["model_alias"]),
        str(cfg["comparison"]["legacy_model"]),
    }
    if model in forbidden_models or model.lower().startswith("gpt-4-turbo"):
        raise SystemExit(
            "Refusing to run a legacy GPT-4 Turbo model in the current-model workflow. "
            "Use the preserved 2024 outputs as the historical benchmark."
        )

    valid_entities = {item["slug"] for item in cfg["entities"]}
    if args.entities:
        unknown = set(args.entities) - valid_entities
        if unknown:
            raise SystemExit(f"Unknown entity slug(s): {', '.join(sorted(unknown))}")

    selected_entities = args.entities or cfg["comparison"]["study_entities"]
    if "berec" in selected_entities:
        raise SystemExit(
            "BEREC is intentionally excluded from this runner. Use the dedicated BEREC scripts."
        )

    prompt = build_system_prompt(
        cfg["legacy_protocol"]["starter"],
        questions,
        cfg["legacy_protocol"]["techniques"]["step_by_step"]["suffix"],
    )
    prompt_hash = hashlib.sha256(prompt.encode("utf-8")).hexdigest()

    print(f"Model: {model}")
    print("Protocol: reconstructed Dec. 24, 2024 step-by-step (SBS) Chat Completions prompt")
    print(f"Technique code: {cfg['legacy_protocol']['techniques']['step_by_step']['code']}")
    print(f"PONs: {', '.join(selected_entities)}")
    print(f"Questions per request: {len(questions)}")
    print(f"Planned API requests: {len(selected_entities)}")
    print(f"System prompt SHA-256: {prompt_hash}")
    print(f"Output root: {cfg['project']['current_output_dir']} (new timestamped directory only)")
    print("Legacy root-level 2024 outputs: READ ONLY / NEVER OVERWRITTEN")

    if not args.execute:
        print("Dry run only. Add --execute to make API calls.")
        return

    run_dir = run_pipeline(
        config_path=ROOT / "config/config.yml",
        model=model,
        entity_slugs=set(selected_entities),
    )
    print(f"Saved current-model SBS run to: {run_dir}")


if __name__ == "__main__":
    main()
