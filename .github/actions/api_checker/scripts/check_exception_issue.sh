#!/usr/bin/env bash
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause

# Validates that the PR has a linked exception issue that is closed
# and has the "armor-exception-approved" label.
#
# Exit codes:
#   0 — always (pass/fail communicated via GITHUB_OUTPUT)
#
# Required environment:
#   PR_NUMBER           — PR number
#   GITHUB_REPOSITORY   — owner/repo
#   GH_TOKEN            — GitHub token (github.token is sufficient for public repos)
#
# Outputs (written to GITHUB_OUTPUT):
#   exception_approved  — true | false

set -euo pipefail

log()  { printf "[INFO]  %s\n" "$*" >&2; }
warn() { printf "[WARN]  %s\n" "$*" >&2; }
die()  { printf "[ERR]   %s\n" "$*" >&2; exit 1; }

_out() {
  local key="$1" val="$2"
  [[ -n "${GITHUB_OUTPUT:-}" ]] && printf '%s=%s\n' "$key" "$val" >> "$GITHUB_OUTPUT"
}

deny() {
  warn "$1"
  _out "exception_approved" "false"
}

PR_NUMBER="${PR_NUMBER:-}"
REPO="${GITHUB_REPOSITORY:-}"
EXCEPTION_LABEL="armor-exception-approved"

log "=== ARMOR Exception Check ==="
log "PR        : #${PR_NUMBER}"
log "Repo      : ${REPO}"
log "Label     : ${EXCEPTION_LABEL}"

[[ -n "$PR_NUMBER" ]] || die "PR_NUMBER is required"
[[ -n "$REPO" ]]      || die "GITHUB_REPOSITORY is required"
command -v gh >/dev/null 2>&1 || die "gh CLI not found"

# ── Step 1: Parse PR body for "armor-exception: #<N>" ─────────────────────────
log "Fetching PR #${PR_NUMBER} body..."

pr_body=$(
  gh api "repos/${REPO}/pulls/${PR_NUMBER}" \
    --jq '.body // ""' \
    2>/dev/null || echo ""
)

log "Scanning PR body for exception reference..."

issue_number=$(
  printf '%s' "$pr_body" | grep -ioP 'armor-exception:\s*#\K[0-9]+' || echo ""
)

if [[ -z "$issue_number" ]]; then
  deny "No 'armor-exception: #<N>' reference found in PR body — no exception."
  exit 0
fi

log "Found exception issue reference: #${issue_number}"

# ── Step 2: Fetch the issue ────────────────────────────────────────────────────
log "Fetching issue #${issue_number}..."

issue_json=$(
  gh api "repos/${REPO}/issues/${issue_number}" 2>/dev/null || echo ""
)

if [[ -z "$issue_json" ]]; then
  deny "Could not fetch issue #${issue_number} — denying exception."
  exit 0
fi

# ── Step 3: Is the issue closed? ──────────────────────────────────────────────
issue_state=$(printf '%s' "$issue_json" | jq -r '.state')
log "Issue #${issue_number} state: ${issue_state}"

if [[ "$issue_state" != "closed" ]]; then
  deny "Issue #${issue_number} is not closed (state: ${issue_state}) — exception not granted."
  exit 0
fi

# ── Step 4: Does the issue have the exception label? ──────────────────────────
log "Checking for label '${EXCEPTION_LABEL}' on issue #${issue_number}..."

label_present=$(
  printf '%s' "$issue_json" | \
    jq --arg label "$EXCEPTION_LABEL" \
       '[.labels[].name] | map(select(. == $label)) | length > 0'
)

log "Label '${EXCEPTION_LABEL}' present: ${label_present}"

if [[ "$label_present" != "true" ]]; then
  deny "Issue #${issue_number} does not have '${EXCEPTION_LABEL}' label — exception not granted."
  exit 0
fi

log "Issue #${issue_number} is closed and has '${EXCEPTION_LABEL}' label — exception granted."
_out "exception_approved" "true"

log "=== ARMOR Exception Check Complete ==="
