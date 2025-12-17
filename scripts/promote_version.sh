#!/bin/bash
set -euo pipefail
exec python3 scripts/promote_version.py "$@"
