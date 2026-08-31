# ////////////////////////////////////////////////////
#
# PON LLM Pilot - Historical Extraction Compatibility Entry Point
#
# Purpose
# - Prevent accidental regeneration of preserved 2024 model outputs
# - Direct contemporary SBS execution to the dedicated current-model runner
#
# Requirements
# - Run from the repository root
#
# AI Disclosure
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-python-scripts.md
#
# ////////////////////////////////////////////////////
"""Compatibility entry point.

Historical 2024 outputs are preserved and must not be regenerated.
Use scripts/03_run_current_model.py to run a contemporary model under the
reconstructed 2024 SBS protocol.
"""

# FINAL OUTPUT LINE
raise SystemExit(
    "Historical outputs are preserved and are not rerun by this repository. "
    "Use: python scripts/03_run_current_model.py --model EXACT_MODEL_ID [--execute]"
)
