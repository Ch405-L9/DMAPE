#!/bin/bash
set -euo pipefail

REVIEW_MODEL="dmape-qwen"
VERSIONS_DIR="prompts/versions"
REVIEWS_DIR="evals/reviews"

command -v ollama >/dev/null 2>&1 || { echo "ollama not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found"; exit 1; }

VERSION_DIR="${1:-}"

if [ -z "$VERSION_DIR" ]; then
  echo "Usage: ./scripts/review_version.sh <version_dir>"
  exit 1
fi

VERSION_PATH="$VERSIONS_DIR/$VERSION_DIR"

if [ ! -d "$VERSION_PATH" ]; then
  echo "ERROR: Version not found: $VERSION_DIR"
  exit 1
fi

SYSTEM_MD="$(cat "$VERSION_PATH/system.md")"
USER_MD="$(cat "$VERSION_PATH/user.md")"
META_JSON="$(cat "$VERSION_PATH/metadata.json")"

REVIEW_PROMPT=$(cat << EOT
You are a non-mutating review agent.

You MUST NOT rewrite content.
You MUST NOT generate new prompts.

Your task:
- Assess compliance with governance laws
- Identify violations or risks
- Score overall compliance from 0.0 to 1.0

Output JSON only.
Do not use markdown.
Do not include commentary.

Required keys:
- compliance_score
- violations (array)
- warnings (array)
- law_coverage (object)

law_coverage rules:
- One key per governance law
- Values must be true or false
- No missing keys

Input:
SYSTEM_MD:
-----
$SYSTEM_MD
-----

USER_MD:
-----
$USER_MD
-----

METADATA:
-----
$META_JSON
-----
EOT
)

RAW_REVIEW="$(echo "$REVIEW_PROMPT" | ollama run "$REVIEW_MODEL")"

CLEAN_REVIEW="$(echo "$RAW_REVIEW" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//')"

# Validate JSON
if ! echo "$CLEAN_REVIEW" | jq . >/dev/null 2>&1; then
  echo "ERROR: Review output is not valid JSON"
  echo "$RAW_REVIEW"
  exit 1
fi

# Enforce law_coverage contract
if ! echo "$CLEAN_REVIEW" | jq '.law_coverage | type == "object"' >/dev/null 2>&1; then
  echo "ERROR: Review output missing valid law_coverage object"
  echo "$CLEAN_REVIEW"
  exit 1
fi

mkdir -p "$REVIEWS_DIR/$VERSION_DIR"

jq --arg ver "$VERSION_DIR" \
   --arg model "$REVIEW_MODEL" \
   --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '. + {
      reviewed_version: $ver,
      review_model: $model,
      reviewed_at_utc: $time
   }' <<< "$CLEAN_REVIEW" \
   > "$REVIEWS_DIR/$VERSION_DIR/review.json"

echo "Review completed for $VERSION_DIR"
