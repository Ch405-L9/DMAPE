#!/usr/bin/env python3

import sys
from pathlib import Path
import difflib
import json

if len(sys.argv) != 3:
    print("Usage: semantic_diff.py <old_version> <new_version>")
    sys.exit(1)

old_v, new_v = sys.argv[1], sys.argv[2]

BASE = Path("prompts/versions")
OUT = Path("artifacts/diffs") / new_v
OUT.mkdir(parents=True, exist_ok=True)

def read(p): return (BASE / p).read_text().splitlines()

old_user = read(f"{old_v}/user.md")
new_user = read(f"{new_v}/user.md")

diff = list(difflib.unified_diff(
    old_user, new_user,
    fromfile=old_v, tofile=new_v, lineterm=""
))

summary = {
    "old_version": old_v,
    "new_version": new_v,
    "lines_added": sum(1 for l in diff if l.startswith("+") and not l.startswith("+++")),
    "lines_removed": sum(1 for l in diff if l.startswith("-") and not l.startswith("---")),
    "change_type": "semantic" if diff else "none"
}

(OUT / "diff.txt").write_text("\n".join(diff))
(OUT / "summary.json").write_text(json.dumps(summary, indent=2))

print(f"Semantic diff written for {new_v}")
