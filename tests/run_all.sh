#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS="${SCRIPT_DIR}/bats/bin/bats"

if [[ ! -x "$BATS" ]]; then
  echo "Error: bats not found at $BATS" >&2
  exit 1
fi

# Find all .bats files
BATS_FILES=("${SCRIPT_DIR}"/*.bats)

# If no test files exist, exit successfully (not an error)
if [[ ! -e "${BATS_FILES[0]}" ]]; then
  echo "No test files found in ${SCRIPT_DIR}. Skipping."
  exit 0
fi

# Run all tests
"$BATS" "${BATS_FILES[@]}"
