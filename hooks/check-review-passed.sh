#!/usr/bin/env bash
# PreToolUse hook called when Claude wants to run `git commit ...`.
#
# Verifies that .claude-team/current/review-feedback.md exists with APPROVED status
# (handling rebuttal flow if applicable). Blocks the commit if not approved.
#
# stdin: JSON from Claude Code with session_id, tool_name, tool_input
# stdout: JSON for hook response
# Exit code: 0 on allow, 2 on deny

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Skip if .claude-team/ doesn't exist (this is a non-dev-team-agents project commit; allow)
if [ ! -d "${PROJECT_ROOT}/.claude-team" ]; then
    exit 0
fi

# Skip if there's no review-feedback.md AND no current task (no active pipeline)
if [ ! -f "${PROJECT_ROOT}/.claude-team/current/review-feedback.md" ] \
   && [ ! -f "${PROJECT_ROOT}/.claude-team/current/task.md" ]; then
    # No active task — must be a commit outside the multi-agent flow (manual fix). Allow.
    exit 0
fi

# If task.md exists but review-feedback.md doesn't yet, block — pipeline incomplete
if [ -f "${PROJECT_ROOT}/.claude-team/current/task.md" ] \
   && [ ! -f "${PROJECT_ROOT}/.claude-team/current/review-feedback.md" ]; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Cannot commit: an active task is in progress (.claude-team/current/task.md exists) but review-feedback.md is missing. Reviewer must run before Git commits work."
  }
}
EOF
    exit 2
fi

# review-feedback.md exists — validate it's APPROVED
if "${SCRIPT_DIR}/validators/validate-review-passed.sh" "$PROJECT_ROOT" 2>/tmp/check-review-err; then
    exit 0
fi

reason=$(cat /tmp/check-review-err 2>/dev/null || echo "review-feedback.md does not show APPROVED status")
reason_escaped=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n')

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Cannot commit: ${reason_escaped}. Reviewer must approve (or Architect must arbitrate via architect-ruling.md and Reviewer must approve in FINAL REVIEW) before Git commits work."
  }
}
EOF

exit 2
