#!/bin/bash
set -e

VERSION="$1"

if [ -z "$VERSION" ]; then
  echo "Rollback version required"
  exit 1
fi

echo "Rolling back DMAPE to version $VERSION"
ln -sf "$ROOT/prompts/versions/$VERSION" "$ROOT/prompts/current"
echo "Rollback completed"
