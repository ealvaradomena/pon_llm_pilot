"""Inspect both zero-shot protocols without contacting OpenAI."""

from pathlib import Path
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from python.llm_extract import (
    build_improved_system_prompt,
    build_system_prompt,
    load_config,
    load_questions,
)

cfg = load_config(ROOT / "config/config.yml")
questions = load_questions(ROOT / cfg["project"]["questions_file"])

legacy_prompt = build_system_prompt(
    cfg["legacy_protocol"]["starter"],
    questions,
    cfg["legacy_protocol"]["techniques"]["zero_shot"]["suffix"],
)

improved_prompt = build_improved_system_prompt(
    cfg["improved_protocol"]["starter"],
    questions,
)

print(f"Questions: {len(questions)}")
print(f"Entities: {len(cfg['entities'])}")
print(f"Historical model alias: {cfg['legacy_protocol']['model_alias']}")
print(f"Pinned legacy-model counterpart: {cfg['comparison']['legacy_model']}")
print(f"Current model: {cfg['comparison']['current_model']}")
print(f"Endpoint: {cfg['legacy_protocol']['endpoint']}")
print(f"2024 zero-shot prompt: {hashlib.sha256(legacy_prompt.encode('utf-8')).hexdigest()}")
print(f"Improved prompt: {hashlib.sha256(improved_prompt.encode('utf-8')).hexdigest()}")
