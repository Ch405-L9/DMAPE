#!/usr/bin/env python3

import json
import sys
from pathlib import Path
from datetime import datetime, timezone

REVIEWS_DIR = Path("evals/reviews")
RULES_FILE = Path("workflows/promotion_rules.json")
STATUS_DIR = Path("artifacts/status")

if len(sys.argv) != 2:
    print("Usage: promote_version.py <version>")
    sys.exit(1)

version = sys.argv[1]
review_file = REVIEWS_DIR / version / "review.json"

if not review_file.exists():
    print(f"ERROR: Review not found for {version}")
    sys.exit(1)

with RULES_FILE.open() as f:
    rules = json.load(f)

with review_file.open() as f:
    review = json.load(f)

score = float(review.get("compliance_score", 0))
violations = len(review.get("violations", []))
warnings = len(review.get("warnings", []))
law_coverage = review.get("law_coverage", {})

min_score = float(rules.get("minimum_compliance_score", 1))
max_violations = int(rules.get("max_violations_allowed", 0))
max_warnings = int(rules.get("max_warnings_allowed", 0))
required_laws = rules.get("required_laws", [])

status = "promote"

if score < min_score:
    status = "quarantine"
elif violations > max_violations:
    status = "quarantine"
elif warnings > max_warnings:
    status = "review_required"
else:
    for law in required_laws:
        if law_coverage.get(law) is not True:
            status = "quarantine"
            break

out_dir = STATUS_DIR / version
out_dir.mkdir(parents=True, exist_ok=True)

payload = {
    "version": version,
    "promotion_status": status,
    "evaluated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "inputs": {
        "compliance_score": score,
        "violations": violations,
        "warnings": warnings
    }
}

with (out_dir / "status.json").open("w") as f:
    json.dump(payload, f, indent=2)

print(f"Promotion decision for {version}: {status}")
