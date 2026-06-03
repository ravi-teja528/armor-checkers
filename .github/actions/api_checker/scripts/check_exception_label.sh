#!/usr/bin/env bash
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause

# Validates that the PR has the armor-exception-approved label.
# Approver identity check is commented out for testing — label presence alone grants exception.
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
#   exception_approver  — GitHub login of the approver (only when approved, future use)

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
# APPROVERS_FILE="${APPROVERS_FILE:-}"   # TODO: re-enable when approvers list is ready
EXCEPTION_LABEL="armor-exception-approved"

log "=== ARMOR Exception Check ==="
log "PR        : #${PR_NUMBER}"
log "Repo      : ${REPO}"
log "Label     : ${EXCEPTION_LABEL}"

[[ -n "$PR_NUMBER" ]] || die "PR_NUMBER is required"
[[ -n "$REPO" ]]      || die "GITHUB_REPOSITORY is required"
command -v gh >/dev/null 2>&1 || die "gh CLI not found"

# ── Load approvers list from caller's repo ─────────────────────────────────────
# TODO: uncomment when approvers list is ready
# if [[ ! -f "$APPROVERS_FILE" ]]; then
#   deny "Approvers file not found at '${APPROVERS_FILE}' — no exception possible."
#   exit 0
# fi
#
# mapfile -t APPROVERS < <(grep -v '^\s*#' "$APPROVERS_FILE" | grep -v '^\s*$' | awk '{print $1}' || true)
#
# if [[ "${#APPROVERS[@]}" -eq 0 ]]; then
#   deny "Approvers file '${APPROVERS_FILE}' is empty — no one is authorized to approve exceptions."
#   exit 0
# fi
#
# log "Loaded ${#APPROVERS[@]} approver(s) from ${APPROVERS_FILE}."

# ── Step 1: Is the exception label present on the PR? ──────────────────────────
log "Checking for label '${EXCEPTION_LABEL}' on PR #${PR_NUMBER}..."

label_present=$(
  gh api "repos/${REPO}/issues/${PR_NUMBER}/labels" \
    --jq "[.[] | select(.name == \"${EXCEPTION_LABEL}\")] | length > 0" \
    2>/dev/null || echo "false"
)

log "Label present: ${label_present}"

if [[ "$label_present" != "true" ]]; then
  deny "Label '${EXCEPTION_LABEL}' not found on PR #${PR_NUMBER} — exception not granted."
  exit 0
fi

log "Label '${EXCEPTION_LABEL}' found — exception granted."
_out "exception_approved" "true"

# ── Step 2: Who applied the label? (commented out — re-enable with approvers check) ──
# TODO: uncomment when approvers list is ready
# log "Checking who applied label '${EXCEPTION_LABEL}'..."
#
# applier=$(
#   gh api "repos/${REPO}/issues/${PR_NUMBER}/timeline" \
#     --header "Accept: application/vnd.github+json" \
#     --paginate \
#     --jq "[.[] | select(.event == \"labeled\" and .label.name == \"${EXCEPTION_LABEL}\")] | last | .actor.login" \
#     2>/dev/null || echo ""
# )
#
# if [[ -z "$applier" || "$applier" == "null" ]]; then
#   deny "Could not determine who applied '${EXCEPTION_LABEL}' — denying exception."
#   exit 0
# fi
#
# log "Label was applied by: ${applier}"

# ── Step 3: Is the applier in the approvers file? (commented out — re-enable with approvers check) ──
# TODO: uncomment when approvers list is ready
# log "Checking if '${applier}' is listed in ${APPROVERS_FILE}..."
#
# approved=false
# for user in "${APPROVERS[@]}"; do
#   if [[ "$user" == "$applier" ]]; then
#     approved=true
#     break
#   fi
# done
#
# if [[ "$approved" == "true" ]]; then
#   log "APPROVED — ${applier} is listed in the approvers file."
#   _out "exception_approved" "true"
#   _out "exception_approver" "${applier}"
# else
#   deny "DENIED — '${applier}' is not listed in the approvers file."
# fi

log "=== ARMOR Exception Check Complete ==="

