#!/bin/bash
set -e
echo "Running DMAPE test suite"
pytest tests || exit 1
echo "All tests passed"
