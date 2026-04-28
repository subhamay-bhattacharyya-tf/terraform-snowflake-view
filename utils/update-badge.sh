#!/usr/bin/env bash
# update-badge.sh — refresh the shields.io custom-endpoint gist for the
# terraform-snowflake-view README badge.
#
# The README references a shields.io endpoint backed by a secret gist
# whose payload file is named after the repo:
#   <gist-id>/raw/terraform-snowflake-view.json
#
# This script regenerates that JSON payload (label / message / color) and
# pushes it back to the gist via the GitHub CLI. Invoked by:
#   - the `terratest` CI job after a successful Snowflake views run
#   - the `semantic-release` job after a new version is published
#
# Usage (from repo root):
#   BADGE_GIST_ID=<gist-id> \
#   BADGE_LABEL="snowflake-view" \
#   BADGE_MESSAGE="passing" \
#   BADGE_COLOR="brightgreen" \
#     bash utils/update-badge.sh
#
# Required env:
#   BADGE_GIST_ID   id of the secret gist that hosts the shields endpoint
# Optional env (have sensible defaults):
#   BADGE_LABEL     label shown on the left side of the badge   (default: snowflake-view)
#   BADGE_MESSAGE   message shown on the right side             (default: passing)
#   BADGE_COLOR     shields color name or hex                   (default: brightgreen)
#   BADGE_FILENAME  filename inside the gist                    (default: terraform-snowflake-view.json)
#
# Exits non-zero on any failure so it can gate CI.

set -euo pipefail

REPO_NAME="terraform-snowflake-view"
BADGE_FILENAME="${BADGE_FILENAME:-${REPO_NAME}.json}"
BADGE_LABEL="${BADGE_LABEL:-snowflake-view}"
BADGE_MESSAGE="${BADGE_MESSAGE:-passing}"
BADGE_COLOR="${BADGE_COLOR:-brightgreen}"

if [[ -z "${BADGE_GIST_ID:-}" ]]; then
  echo "ERROR: BADGE_GIST_ID env var must be set to the shields.io endpoint gist id" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI is not installed; required to update the snowflake-view badge gist" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

payload="${tmpdir}/${BADGE_FILENAME}"
cat > "${payload}" <<JSON
{
  "schemaVersion": 1,
  "label": "${BADGE_LABEL}",
  "message": "${BADGE_MESSAGE}",
  "color": "${BADGE_COLOR}"
}
JSON

echo "[update-badge] pushing ${BADGE_FILENAME} to gist ${BADGE_GIST_ID} (label='${BADGE_LABEL}' message='${BADGE_MESSAGE}' color='${BADGE_COLOR}')"
gh gist edit "${BADGE_GIST_ID}" --add "${payload}" --filename "${BADGE_FILENAME}"

echo "[update-badge] done — terraform-snowflake-view README badge endpoint refreshed"
