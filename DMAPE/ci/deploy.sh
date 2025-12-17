#!/bin/bash
set -e

ENV="$1"
MODE="$2"

if [ "$MODE" != "--dry-run" ]; then
  echo "LIVE deployment requires explicit --dry-run first"
  exit 1
fi

echo "DRY RUN deployment for environment: $ENV"
echo "No state changes executed"
