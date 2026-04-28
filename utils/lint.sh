#!/usr/bin/env bash
# lint.sh — run tflint + trivy across the terraform-snowflake-view module
#
# Wraps the two static analyzers used by both local development and CI:
#   - tflint  : catches Snowflake provider misuse, unused variables,
#               deprecated syntax in *.tf files at the repo root and under
#               examples/.
#   - trivy   : scans for misconfigurations (e.g. views that should be
#               secure but aren't, missing comments on production resources).
#
# Usage (from repo root):
#   bash utils/lint.sh
#
# Exits non-zero on any finding so it can gate pre-commit and CI.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

fail=0

if ! command -v tflint >/dev/null 2>&1; then
  echo "ERROR: tflint is not installed. Run 'bash install-tools.sh --tools=tflint'." >&2
  exit 1
fi

echo "[lint] tflint --recursive (terraform-snowflake-view)"
if ! tflint --recursive; then
  echo "[lint] tflint reported findings on the snowflake-view module" >&2
  fail=1
fi

if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy is not installed. Run 'bash install-tools.sh --tools=trivy'." >&2
  exit 1
fi

echo "[lint] trivy config (terraform-snowflake-view)"
if ! trivy config --exit-code 1 --severity HIGH,CRITICAL .; then
  echo "[lint] trivy reported findings on the snowflake-view module" >&2
  fail=1
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "[lint] FAILED — see findings above" >&2
  exit 1
fi

echo "[lint] OK — terraform-snowflake-view passed tflint and trivy"
