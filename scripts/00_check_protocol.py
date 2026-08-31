# ////////////////////////////////////////////////////
#
# PON LLM Pilot - Protocol Inspection
#
# Purpose
# - Inspect the reconstructed December 2024 SBS protocol
# - Report question counts, model identifiers, and the SBS prompt hash without contacting OpenAI
#
# Requirements
# - Project configuration in config/config.yml
# - Question file registered by the configuration
#
# AI Disclosure
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-python-scripts.md
#
# ////////////////////////////////////////////////////
"""Inspect the reconstructed 2024 SBS protocol without contacting OpenAI."""

from pathlib import Path
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from python.llm_extract import build_system_prompt, load_config, load_questions

cfg = load_config(ROOT / "config/config.yml")
questions = load_questions(ROOT / cfg["project"]["questions_file"])

sbs = cfg["legacy_protocol"]["techniques"]["step_by_step"]
sbs_prompt = build_system_prompt(
    cfg["legacy_protocol"]["starter"],
    questions,
    sbs["suffix"],
)

excluded = int(cfg["comparison"]["manuscript_excluded_question_id"])
manuscript_count = len(questions) - 1

print("API calls: NONE")
print(f"Computational questions: {len(questions)}")
print(f"Manuscript/Table A5 questions: {manuscript_count}")
print(f"Manuscript-excluded computational question ID: {excluded}")
print(f"Comparative PONs: {len(cfg['comparison']['study_entities'])}")
print(f"Historical requested model alias: {cfg['legacy_protocol']['model_alias']}")
print(f"Best-supported dated GPT-4 Turbo snapshot: {cfg['comparison']['legacy_model']}")
print(f"Newer comparison model: {cfg['comparison']['current_model']}")
print(f"Endpoint: {cfg['legacy_protocol']['endpoint']}")
print(f"Technique: step-by-step (SBS), code={sbs['code']}")
print(f"SBS suffix repr: {sbs['suffix']!r}")
print(f"SBS system prompt SHA-256: {hashlib.sha256(sbs_prompt.encode('utf-8')).hexdigest()}")
print("Legacy outputs are frozen; this script performs local inspection only.")
