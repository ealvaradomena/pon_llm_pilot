# ////////////////////////////////////////////////////
#
# PON LLM Pilot - Compare BEREC Reconstruction Conditions
#
# Purpose
# - Compare the preserved BEREC output with two dedicated reconstruction conditions
# - Write local question-level, pairwise-summary, and provenance tables
#
# Requirements
# - Preserved historical BEREC output under output/
# - Completed Dec. 23 and Dec. 24 BEREC runs under output/berec_replication/
#
# AI Disclosure
# - Code documentation and formatting assisted by ChatGPT
# - Prompt used: https://github.com/ealvaradomena/my-prompts/blob/main/prompts/pretty-python-scripts.md
#
# ////////////////////////////////////////////////////
"""Compare the three BEREC classification conditions without API calls.

The preserved historical output is not treated as ground truth, and the
reconstructed GPT-4 Turbo run is not claimed to be an exact replication.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path


# 1. Register Local Inputs and Outputs ----

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output"
BEREC_ROOT = OUTPUT / "berec_replication"
DERIVED = ROOT / "derived"

HISTORICAL_FILE = OUTPUT / "BO1A-2024-12-23-55_cat.txt"

DEC23_PROTOCOL = "berec-dec23-reconstructed"
DEC24_PROTOCOL = "berec-dec24-sbs-current"


# 2. Parse BEREC Classification Files ----

def parse_binary_csv(path: Path) -> list[tuple[str, str]]:
    """Read a 15-row TRUE/FALSE CSV, allowing fences and unquoted commas."""
    lines = path.read_text(encoding="utf-8").splitlines()

    cleaned = [
        line.strip()
        for line in lines
        if line.strip() not in {"", "```", "```csv"}
    ]

    if not cleaned:
        raise RuntimeError(f"No CSV content found in {path}")

    header = cleaned[0].strip().strip('"').lower()

    if not header.startswith("question"):
        raise RuntimeError(
            f"Unexpected CSV header in {path}: {cleaned[0]!r}"
        )

    parsed: list[tuple[str, str]] = []

    for line in cleaned[1:]:
        # Historical outputs use properly quoted CSV.
        if line.startswith('"'):
            row = next(csv.reader([line]))

            if len(row) != 2:
                raise RuntimeError(
                    f"Malformed quoted row in {path}: {line!r}"
                )

            question = row[0].strip()
            answer = row[1].strip().upper()

        # Contemporary-model output may leave questions unquoted even when
        # the question text itself contains commas. The binary answer
        # is always the final comma-separated field.
        else:
            try:
                question, answer = line.rsplit(",", 1)
            except ValueError as exc:
                raise RuntimeError(
                    f"Malformed unquoted row in {path}: {line!r}"
                ) from exc

            question = question.strip()
            answer = answer.strip().upper()

        if answer not in {"TRUE", "FALSE"}:
            raise RuntimeError(
                f"Non-binary answer in {path}: "
                f"{question!r} -> {answer!r}"
            )

        parsed.append((question, answer))

    if len(parsed) != 15:
        raise RuntimeError(
            f"Expected 15 BEREC responses in {path}; found {len(parsed)}"
        )

    return parsed


# 3. Locate Completed BEREC Runs ----

def latest_complete_run(protocol: str) -> tuple[Path, dict]:
    """Return the latest complete BEREC run for a protocol."""
    candidates: list[tuple[str, Path, dict]] = []

    for manifest_path in BEREC_ROOT.glob("*/run_manifest.json"):
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

        if (
            manifest.get("status") == "complete"
            and manifest.get("protocol") == protocol
        ):
            created = str(manifest.get("created_utc", ""))
            candidates.append((created, manifest_path.parent, manifest))

    if not candidates:
        raise RuntimeError(
            f"No complete BEREC run found for protocol {protocol!r}"
        )

    candidates.sort(key=lambda item: (item[0], item[1].name))
    _, run_dir, manifest = candidates[-1]

    return run_dir, manifest


def find_single_txt(run_dir: Path) -> Path:
    """Find the single raw TXT response in a BEREC run directory."""
    files = sorted(run_dir.glob("*.txt"))

    if len(files) != 1:
        raise RuntimeError(
            f"Expected exactly one TXT output in {run_dir}; found {len(files)}"
        )

    return files[0]


# 4. Summarize Pairwise Classification Agreement ----

def bool_value(answer: str) -> bool:
    return answer == "TRUE"


def pair_summary(
    label: str,
    left: list[str],
    right: list[str],
) -> dict[str, object]:
    same = sum(a == b for a, b in zip(left, right))
    true_to_false = sum(
        a == "TRUE" and b == "FALSE"
        for a, b in zip(left, right)
    )
    false_to_true = sum(
        a == "FALSE" and b == "TRUE"
        for a, b in zip(left, right)
    )

    return {
        "comparison": label,
        "n_questions": len(left),
        "same": same,
        "different": len(left) - same,
        "agreement_rate": same / len(left),
        "true_to_false": true_to_false,
        "false_to_true": false_to_true,
    }


# 5. Build Derived BEREC Comparison Tables ----

def main() -> None:
    # Ensure the local derived-output directory exists
    DERIVED.mkdir(parents=True, exist_ok=True)

    if not HISTORICAL_FILE.exists():
        raise FileNotFoundError(HISTORICAL_FILE)

    # Locate the latest complete run for each dedicated BEREC protocol
    dec23_dir, dec23_manifest = latest_complete_run(DEC23_PROTOCOL)
    dec24_dir, dec24_manifest = latest_complete_run(DEC24_PROTOCOL)

    dec23_file = find_single_txt(dec23_dir)
    dec24_file = find_single_txt(dec24_dir)

    # Parse all three 15-question classification artifacts
    historical = parse_binary_csv(HISTORICAL_FILE)
    reconstructed = parse_binary_csv(dec23_file)
    current = parse_binary_csv(dec24_file)

    historical_questions = [q for q, _ in historical]
    reconstructed_questions = [q for q, _ in reconstructed]
    current_questions = [q for q, _ in current]

    if historical_questions != reconstructed_questions:
        raise RuntimeError(
            "Historical and reconstructed BEREC question order differs."
        )

    if historical_questions != current_questions:
        raise RuntimeError(
            "Historical and current BEREC question order differs."
        )

    historical_answers = [a for _, a in historical]
    reconstructed_answers = [a for _, a in reconstructed]
    current_answers = [a for _, a in current]

    # Write the question-level three-way comparison
    comparison_path = DERIVED / "berec_three_way_comparison.csv"

    with comparison_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "question_id",
                "question",
                "preserved_historical",
                "dec23_reconstructed_gpt4",
                "dec24_sbs_gpt54_nano",
                "historical_vs_reconstructed_same",
                "historical_vs_current_same",
                "reconstructed_vs_current_same",
            ]
        )

        for idx, question in enumerate(historical_questions, start=1):
            historical_answer = historical_answers[idx - 1]
            reconstructed_answer = reconstructed_answers[idx - 1]
            current_answer = current_answers[idx - 1]

            writer.writerow(
                [
                    idx,
                    question,
                    historical_answer,
                    reconstructed_answer,
                    current_answer,
                    historical_answer == reconstructed_answer,
                    historical_answer == current_answer,
                    reconstructed_answer == current_answer,
                ]
            )

    # Summarize pairwise agreement and flip directions
    summary_rows = [
        pair_summary(
            "Preserved historical vs Dec. 23 reconstructed GPT-4 Turbo",
            historical_answers,
            reconstructed_answers,
        ),
        pair_summary(
            "Preserved historical vs Dec. 24 SBS GPT-5.4 nano",
            historical_answers,
            current_answers,
        ),
        pair_summary(
            "Dec. 23 reconstructed GPT-4 Turbo vs Dec. 24 SBS GPT-5.4 nano",
            reconstructed_answers,
            current_answers,
        ),
    ]

    summary_path = DERIVED / "berec_three_way_summary.csv"

    with summary_path.open("w", newline="", encoding="utf-8") as handle:
        fieldnames = [
            "comparison",
            "n_questions",
            "same",
            "different",
            "agreement_rate",
            "true_to_false",
            "false_to_true",
        ]

        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(summary_rows)

    # Record the exact artifacts and provenance claims used in the comparison
    sources_path = DERIVED / "berec_sources.csv"

    with sources_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "condition",
                "artifact",
                "model",
                "protocol",
                "replication_claim",
            ]
        )
        writer.writerow(
            [
                "preserved_historical",
                HISTORICAL_FILE.relative_to(ROOT).as_posix(),
                "historical GPT-4 Turbo family; exact serving snapshot unproven",
                "preserved Dec. 23 artifact",
                "preserved historical observation",
            ]
        )
        writer.writerow(
            [
                "dec23_reconstructed_gpt4",
                dec23_file.relative_to(ROOT).as_posix(),
                dec23_manifest.get("requested_model", ""),
                dec23_manifest.get("protocol", ""),
                dec23_manifest.get("replication_claim", ""),
            ]
        )
        writer.writerow(
            [
                "dec24_sbs_gpt54_nano",
                dec24_file.relative_to(ROOT).as_posix(),
                dec24_manifest.get("requested_model", ""),
                dec24_manifest.get("protocol", ""),
                dec24_manifest.get("replication_claim", ""),
            ]
        )

    print("BEREC three-way comparison complete")
    print(f"Historical artifact: {HISTORICAL_FILE.relative_to(ROOT)}")
    print(f"Dec. 23 reconstruction: {dec23_dir.relative_to(ROOT)}")
    print(f"Dec. 24 SBS current run: {dec24_dir.relative_to(ROOT)}")
    print("Questions: 15")

    for row in summary_rows:
        print(
            f"{row['comparison']}: "
            f"{row['same']}/{row['n_questions']} "
            f"({row['agreement_rate']:.3f})"
        )

    print("Derived files:")
    print(f"  {comparison_path.relative_to(ROOT)}")
    print(f"  {summary_path.relative_to(ROOT)}")
    print(f"  {sources_path.relative_to(ROOT)}")
    # FINAL OUTPUT LINE
    print("API calls: NONE")


if __name__ == "__main__":
    main()
