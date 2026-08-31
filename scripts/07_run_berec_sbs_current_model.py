# ////////////////////////////////////////////////////
#
# PON LLM Pilot - BEREC Current-Model SBS Runner
#
# Purpose
# - Dry-run or apply the reconstructed December 24 SBS protocol to BEREC with the configured newer model
# - Require explicit execution confirmation and keep all outputs isolated from legacy artifacts
#
# Requirements
# - Project configuration in config/config.yml
# - BEREC replication boundary object input/boundary_objects/BO1B.txt
# - OPENAI_API_KEY only when both --execute and --confirm-api-call BEREC are supplied
#
# AI Disclosure
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-python-scripts.md
#
# ////////////////////////////////////////////////////
"""Safely apply the reconstructed Dec. 24 SBS protocol to BEREC BO1B.

No API call occurs unless BOTH --execute and --confirm-api-call BEREC are supplied.
This is protocol replication with the configured newer model, not reconstruction of
BEREC's uncertain Dec. 23 request. Historical outputs are never modified.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from python.berec_replication import (
    berec_paths,
    require_execution_confirmation,
    run_dec24_sbs_current,
)
from python.llm_extract import build_system_prompt, load_config, load_questions


# 1. Configure the Runner ----

# 2. Run the Workflow ----

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--confirm-api-call", default=None)
    args = parser.parse_args()

    cfg = load_config(ROOT / "config/config.yml")
    questions = load_questions(ROOT / cfg["project"]["questions_file"])
    _, bo_path = berec_paths(cfg)
    model = str(cfg["comparison"]["current_model"])
    prompt = build_system_prompt(
        cfg["legacy_protocol"]["starter"],
        questions,
        cfg["legacy_protocol"]["techniques"]["step_by_step"]["suffix"],
    )

    print("BEREC mode: Dec. 24 SBS protocol replication with newer model")
    print(f"Boundary object: {bo_path} [REQUIRED: BO1B.txt]")
    print(f"Model: {model}")
    print("Planned API requests: 1")
    print(f"SBS prompt SHA-256: {hashlib.sha256(prompt.encode('utf-8')).hexdigest()}")
    print(f"Output root: {cfg['project']['berec_output_dir']} (new timestamped directory only)")
    print("Preserved legacy BEREC output: READ ONLY / NEVER OVERWRITTEN")

    require_execution_confirmation(args.execute, args.confirm_api_call)
    if not args.execute:
        print("Dry run only. API calls: NONE.")
        print("Execution requires: --execute --confirm-api-call BEREC")
        return

    run_dir = run_dec24_sbs_current(ROOT / "config/config.yml")
    print(f"Saved BEREC current-model SBS run to: {run_dir}")


if __name__ == "__main__":
    main()
