#!/bin/bash
set -euo pipefail

MODEL="dmape-qwen"
BASE_DIR="prompts/base"
VERSIONS_DIR="prompts/versions"
SCHEMA="governance/dmape_output.schema.json"
GOV_VERSION="dmape-laws-1.0"
STAGE="dmape.generate.v1"

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
- user_md MUST be rewritten and non-empty
- system_md MUST define system rules
- metadata_json.model MUST be "dmape-qwen"

Required keys:
- system_md
- user_md
- metadata_json

metadata_json must include:
- version
- base_file
- generated_at_utc
- model

Base prompt:
-----
$(cat "$BASE_PATH")
-----
EOT
)

RAW_RESPONSE="$(echo "$PROMPT" | ollama run "$MODEL")"

CLEAN_RESPONSE="$(echo "$RAW_RESPONSE" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//')"

if ! echo "$CLEAN_RESPONSE" | jq . > "$TMP_JSON" 2>/dev/null; then
  echo "ERROR: Model output is not valid JSON"
  echo "$RAW_RESPONSE"
  rm -f "$TMP_JSON"
  exit 1
fi

# Inject provenance (system-authored, not model-authored)
jq --arg stage "$STAGE" \
   --arg gov "$GOV_VERSION" \
   --arg base "$BASE_FILE" \
   '.metadata_json.provenance = {
      stage: $stage,
      laws_applied: [
        "json_only_output",
        "schema_enforced",
        "model_identity_locked",
        "non_empty_user_md",
        "no_markdown"
      ],
      governance_version: $gov,
      transformation_type: "prompt_compilation",
      source_base_prompt: $base
    }' "$TMP_JSON" > "${TMP_JSON}.prov"

mv "${TMP_JSON}.prov" "$TMP_JSON"

python3 - << PYCODE
import json, sys
from jsonschema import Draft7Validator

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

jq -r '.system_md' "$TMP_JSON" > "$OUT_DIR/system.md"
jq -r '.user_md' "$TMP_JSON" > "$OUT_DIR/user.md"
jq '.metadata_json' "$TMP_JSON" > "$OUT_DIR/metadata.json"

rm -f "$TMP_JSON"

echo "DMAPE version created at $OUT_DIR (schema validated, provenance injected)"
