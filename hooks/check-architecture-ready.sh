#!/usr/bin/env bash
# SubagentStart hook for developer / developer-parallel agents.
#
# Verifies that .claude-team/current/architecture.md exists and is well-formed
# before allowing the Developer to start. Catches "Architect skipped or unfinished"
# bugs in the Orchestrator's routing.
#
# stdin: JSON from Claude Code with session_id, hook_event_name, agent_type
# stdout: JSON for hook response
# Exit code: 0 on allow, 2 on deny

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Run validator
if "${SCRIPT_DIR}/validators/validate-architecture-format.sh" "$PROJECT_ROOT" 2>/tmp/check-arch-err; then
    # Architecture is good — allow
    exit 0
fi

reason=$(cat /tmp/check-arch-err 2>/dev/null || echo "architecture.md is missing or malformed")

# Output deny JSON for Claude Code
# Escape reason for JSON
reason_escaped=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStart",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Developer cannot start: ${reason_escaped}. Architect must complete (PLANNER mode, writing architecture.md) before Developer is dispatched."
  }
}
EOF

exit 2
