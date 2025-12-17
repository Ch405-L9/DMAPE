#!/bin/bash
set -e

mkdir -p .github/workflows
mkdir -p scripts

cat << 'YML' > .github/workflows/dmape_auto_version.yml
name: DMAPE Auto Version

on:
  push:
    paths:
      - "prompts/base/**"

permissions:
  contents: write
  pull-requests: write
  models: read

jobs:
  generate-version:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Generate versioned prompt files
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          python scripts/create_version_from_base.py

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v6
        with:
          branch: dmape/auto-version
          delete-branch: true
          title: "DMAPE auto: create new prompt version from base"
          body: |
            This PR was generated automatically by DMAPE.
            - Base prompt changes detected under prompts/base/
            - New version created under prompts/versions/
            - Base prompt was not modified
          commit-message: "DMAPE auto: add new versioned prompt files"
YML

cat << 'PY' > scripts/create_version_from_base.py
import json
import os
import re
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE_DIR = ROOT / "prompts" / "base"
VERSIONS_DIR = ROOT / "prompts" / "versions"

MODELS_ENDPOINT = "https://models.github.ai/inference/chat/completions"
MODEL_ID = "openai/gpt-4o-mini"

def die(msg: str) -> None:
    raise SystemExit(msg)

def read_latest_base_prompt() -> tuple[str, str]:
    if not BASE_DIR.exists():
        die("prompts/base not found")

    md_files = sorted([p for p in BASE_DIR.rglob("*") if p.is_file()], key=lambda p: p.stat().st_mtime, reverse=True)
    if not md_files:
        die("No files found in prompts/base. Add a prompt file first.")

    p = md_files[0]
    return str(p.relative_to(ROOT)), p.read_text(encoding="utf-8", errors="replace")

def next_patch_version() -> str:
    VERSIONS_DIR.mkdir(parents=True, exist_ok=True)
    existing = [p.name for p in VERSIONS_DIR.iterdir() if p.is_dir() and re.fullmatch(r"v\d+\.\d+\.\d+", p.name)]
    if not existing:
        return "v0.1.0"

    def key(v: str):
        a, b, c = map(int, v[1:].split("."))
        return (a, b, c)

    latest = sorted(existing, key=key)[-1]
    a, b, c = map(int, latest[1:].split("."))
    return f"v{a}.{b}.{c+1}"

def call_github_models(token: str, system_msg: str, user_msg: str) -> str:
    payload = {
        "model": MODEL_ID,
        "messages": [
            {"role": "system", "content": system_msg},
            {"role": "user", "content": user_msg}
        ],
        "temperature": 0.2
    }
    req = urllib.request.Request(
        MODELS_ENDPOINT,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"]

def main() -> None:
    token = os.environ.get("GITHUB_TOKEN", "")
    if not token:
        die("GITHUB_TOKEN not set. In GitHub Actions this should be provided automatically.")

    base_path, base_text = read_latest_base_prompt()
    version = next_patch_version()
    out_dir = VERSIONS_DIR / version
    out_dir.mkdir(parents=True, exist_ok=True)

    system_msg = (
        "You are DMAPE automation. You must follow these hard rules:\n"
        "1. Do not modify base prompts.\n"
        "2. Output must be valid JSON only, no prose.\n"
        "3. JSON keys must be: system_md, user_md, metadata_json.\n"
        "4. metadata_json must be a JSON object, not a string.\n"
        "5. system_md and user_md must be plain text.\n"
    )

    user_msg = (
        "Create a versioned prompt release scaffold for DMAPE.\n"
        f"Base prompt file: {base_path}\n"
        "Task:\n"
        "- Produce system_md: governance, rules, gates, DRY RUN default.\n"
        "- Produce user_md: enhanced prompt content derived from the base prompt.\n"
        "- Produce metadata_json: includes version, created_at_utc, base_file, model, notes.\n"
        "Output format:\n"
        "{\n"
        '  "system_md": "...",\n'
        '  "user_md": "...",\n'
        '  "metadata_json": { ... }\n'
        "}\n"
        "Base prompt content begins:\n"
        "-----\n"
        f"{base_text}\n"
        "-----\n"
    )

    raw = call_github_models(token, system_msg, user_msg)

    try:
        obj = json.loads(raw)
    except Exception:
        die("Model output was not valid JSON. Re-run commit, or change MODEL_ID to a more capable model.")

    system_md = obj.get("system_md", "")
    user_md = obj.get("user_md", "")
    metadata = obj.get("metadata_json", {})

    if not isinstance(metadata, dict):
        die("metadata_json was not a JSON object")

    metadata.setdefault("version", version)
    metadata.setdefault("created_at_utc", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    metadata.setdefault("base_file", base_path)
    metadata.setdefault("model", MODEL_ID)
    metadata.setdefault("notes", "Generated by DMAPE GitHub Models automation")

    (out_dir / "system.md").write_text(system_md.strip() + "\n", encoding="utf-8")
    (out_dir / "user.md").write_text(user_md.strip() + "\n", encoding="utf-8")
    (out_dir / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")

    print(f"Created {out_dir}")

if __name__ == "__main__":
    main()
PY

echo "Done. Commit these files, then push. Any change to prompts/base will open a PR with a new version folder."
