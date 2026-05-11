#!/usr/bin/env bash
# Verifies that .claude-team/current/review-feedback.md exists AND has APPROVED status.
#
# If review-rebuttal.md exists, also checks that architect-ruling.md exists AND
# the Reviewer's final review (most recent) is APPROVED.
#
# Usage: validate-review-passed.sh <project_root>
# Exit codes: 0 = approved, 1 = not approved or missing

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
REVIEW_FILE="${PROJECT_ROOT}/.claude-team/current/review-feedback.md"
REBUTTAL_FILE="${PROJECT_ROOT}/.claude-team/current/review-rebuttal.md"
RULING_FILE="${PROJECT_ROOT}/.claude-team/current/architect-ruling.md"

# Review file must exist
if [ ! -f "$REVIEW_FILE" ]; then
    echo "validate-review-passed: ${REVIEW_FILE} does not exist; Reviewer hasn't run" >&2
    exit 1
fi

# If rebuttal exists, the ruling must also exist
if [ -f "$REBUTTAL_FILE" ] && [ ! -f "$RULING_FILE" ]; then
    echo "validate-review-passed: rebuttal exists but no architect-ruling; Architect (arbiter mode) hasn't run" >&2
    exit 1
fi

# Check approval marker. The Reviewer template uses one of:
#   ✅ **APPROVED**
#   ⚠️ **CHANGES REQUESTED**
#   🛑 **BLOCKED**
# We accept the most permissive match — APPROVED case-insensitive — since emoji handling differs across systems.
if ! grep -E -q -i '\*\*APPROVED\*\*' "$REVIEW_FILE"; then
    if grep -E -q -i '\*\*CHANGES REQUESTED\*\*|\*\*BLOCKED\*\*' "$REVIEW_FILE"; then
        echo "validate-review-passed: review status is not APPROVED; Reviewer requested changes or blocked" >&2
        exit 1
    fi
    # No recognized status marker
    echo "validate-review-passed: ${REVIEW_FILE} has no recognized approval status (expected APPROVED / CHANGES REQUESTED / BLOCKED)" >&2
    exit 1
fi

exit 0
