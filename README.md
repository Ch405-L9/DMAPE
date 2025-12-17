# DMAPE — Developer Mode Advanced Prompt Engineering

DMAPE is a local, governed prompt compiler.

It transforms base prompts into structured, versioned prompt artifacts using
strict enforcement, schema validation, and system-authored provenance.

## Core Principles

- Prompts are untrusted inputs
- Models are generators, not authorities
- Laws are enforced structurally, not rhetorically
- All outputs are deterministic and auditable
- No implicit execution
- No hidden automation

## Lifecycle

1. Author or update a base prompt in `prompts/base/`
2. Run the compiler explicitly:
   ./scripts/local_generate_version.sh
3. Output is generated in `prompts/versions/`
4. Each artifact includes:
   - system.md
   - user.md
   - metadata.json with provenance

## Governance

- Output must be valid JSON
- Schema enforcement is mandatory
- Model identity is locked
- Provenance is injected by the system
- Generated artifacts are not committed by default

## Execution Model

DMAPE does not auto-run on file write or git push.
Execution is explicit by design.

Automation layers (git hooks, CI, PR generation) are optional extensions
and intentionally excluded from the foundation.

## Status

Foundation complete.
Ready for higher-order stages:
- Review agents
- Promotion pipelines
- Semantic diffing
