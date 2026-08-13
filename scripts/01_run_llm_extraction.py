"""Compatibility entry point.

Historical 2024 outputs are preserved and must not be regenerated. 
Use scripts/03_run_current_model.py to run a different model under the old protocol.
"""

raise SystemExit(
    "Historical outputs are preserved and are not rerun by this repository. "
    "Use: python scripts/03_run_current_model.py --model EXACT_MODEL_ID [--execute]"
)
