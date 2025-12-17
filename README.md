# DMAPE — Developer Mode Advanced Prompt Engineering

DMAPE is a governed, local-first PromptOps system for transforming base prompts into enhanced, versioned, auditable prompt artifacts.

It enforces:
- Deterministic generation
- Schema validation
- Provenance tracking
- Independent review
- Policy-based promotion

No cloud dependency required.

---

## Directory Overview

prompts/base/        Base prompts (input)
prompts/versions/    Enhanced, versioned outputs
scripts/             CLI tools
governance/          Schemas and laws
evals/reviews/       Review artifacts
artifacts/status/    Promotion decisions
artifacts/diffs/     Semantic diffs

---

## Core Workflow (CLI)

1. Add a base prompt
   prompts/base/my_prompt.md

2. Generate enhanced version
   ./scripts/local_generate_version.sh

3. Review output
   ./scripts/review_version.sh <version>

4. Promote or quarantine
   ./scripts/promote_version.sh <version>

5. Optional semantic diff
   ./scripts/semantic_diff.py <old> <new>

---

## What DMAPE Produces

For each version:
- system.md     Enhanced system rules
- user.md       Enhanced user prompt
- metadata.json Provenance and governance
- status.json   Promotion decision

---

## Promotion States

- promote
- review_required
- quarantine

Promotion decisions are policy-driven and deterministic.

---

## Design Principles

- Local-first
- No silent mutation
- Explicit contracts
- Fail-closed governance
- Tooling over opinion

---

## Status

Production-ready.
