#!/bin/bash
set -euo pipefail

MODEL="dmape-qwen"
BASE_DIR="prompts/base"
VERSIONS_DIR="prompts/versions"
SCHEMA="governance/dmape_output.schema.json"

command -v ollama >/dev/null 2>&1 || { echo "ollama not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }

BASE_FILE="$(ls -t "$BASE_DIR" | head -n 1)"
BASE_PATH="$BASE_DIR/$BASE_FILE"

VERSION="v$(date -u +%Y.%m.%d-%H%M)"
OUT_DIR="$VERSIONS_DIR/$VERSION"
TMP_JSON="$(mktemp)"

mkdir -p "$OUT_DIR"

PROMPT=$(cat << EOT
STRICT OUTPUT RULES:
- Output JSON only
- Do NOT use markdown
- Do NOT use backticks
- Do NOT add commentary

HARD REQUIREMENTS:
- user_md MUST be non-empty and rewritten
- system_md MUST define system rules
- metadata_json.model MUST be "dmape-qwen"

Required keys:
- system_md
- user_md
- metadata_json

metadata_json must include:
- version
- base_file
- generated_at_utc (UTC ISO-8601)
- model

Base prompt:
-----
$(cat "$BASE_PATH")
-----
EOT
)

RAW_RESPONSE="$(echo "$PROMPT" | ollama run "$MODEL")"

CLEAN_RESPONSE="$(echo "$RAW_RESPONSE" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//')"

# Validate JSON syntax
if ! echo "$CLEAN_RESPONSE" | jq . > "$TMP_JSON" 2>/dev/null; then
  echo "ERROR: Model output is not valid JSON"
  echo "$RAW_RESPONSE"
  rm -f "$TMP_JSON"
  exit 1
fi

# Validate against schema using Python
python3 - << PYCODE
import json, sys
from jsonschema import validate, Draft7Validator

with open("$SCHEMA") as s:
    schema = json.load(s)

with open("$TMP_JSON") as d:
    data = json.load(d)

errors = sorted(Draft7Validator(schema).iter_errors(data), key=lambda e: e.path)
if errors:
    print("ERROR: Schema validation failed")
    for e in errors:
        print("-", e.message)
    sys.exit(1)
PYCODE

# Write outputs
jq -r '.system_md' "$TMP_JSON" > "$OUT_DIR/system.md"
jq -r '.user_md' "$TMP_JSON" > "$OUT_DIR/user.md"
jq '.metadata_json' "$TMP_JSON" > "$OUT_DIR/metadata.json"

rm -f "$TMP_JSON"

echo "DMAPE version created at $OUT_DIR (schema validated, model locked)"
