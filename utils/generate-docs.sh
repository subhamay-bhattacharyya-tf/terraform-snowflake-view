#!/usr/bin/env bash
# generate-docs.sh — refresh terraform-docs auto-generated tables in README.md
#
# Runs terraform-docs against the root module and rewrites the Inputs,
# Outputs, and Resources Created tables for the terraform-snowflake-view
# module. Idempotent: a clean tree produces no diff on consecutive runs.
#
# Usage (from repo root):
#   bash utils/generate-docs.sh
#
# Exits non-zero on any failure so it can gate pre-commit and CI.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
README="${REPO_ROOT}/README.md"

cd "${REPO_ROOT}"

if ! command -v terraform-docs >/dev/null 2>&1; then
  echo "ERROR: terraform-docs is not installed. Run 'bash install-tools.sh --tools=terraform-docs'." >&2
  exit 1
fi

echo "[generate-docs] regenerating terraform-snowflake-view README sections from root module"
terraform-docs markdown table \
  --output-file "${README}" \
  --output-mode inject \
  --sort-by required \
  "${REPO_ROOT}"

if command -v python3 >/dev/null 2>&1; then
  echo "[generate-docs] re-aligning GFM tables in README.md (MD060)"
  python3 "${REPO_ROOT}/utils/align-md-tables.py" "${README}"
else
  echo "WARN: python3 not found; skipping align-md-tables.py — tables may fail MD060." >&2
fi

echo "[generate-docs] done — terraform-snowflake-view README is in sync with the root module"
