# ////////////////////////////////////////////////////
#
#
# PON LLM Pilot - Model Comparison Compatibility Entry Point
#
# Purpose:
# - Preserve the historical comparison-script entry point
# - Delegate the primary SBS comparison to scripts/05_compare_scenarios.R
#
# Requirements:
# - Run from the repository root
#
# AI Disclosure:
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-r-scripts.md
#
# ////////////////////////////////////////////////////
# Preserve the historical entry point while delegating all work downstream
# The primary comparison includes frozen GPT-4 Turbo and all configured contemporary SBS models
source("scripts/05_compare_scenarios.R")
# FINAL OUTPUT LINE
