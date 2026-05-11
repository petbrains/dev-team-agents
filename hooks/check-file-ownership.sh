#!/usr/bin/env bash
# PreToolUse hook (matcher=Write|Edit|MultiEdit, if=.claude-team/*).
# Verifies that the currently active agent is allowed to write the target file
# per the ownership table in validators/validate-file-ownership.sh.
#
# Reads active agent name from ${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/active-agent.txt
# (written by track-active-agent.sh on SubagentStart).
#
# If the active-agent file doesn't exist (race or first run), the hook ALLOWS —
# permissive default. Better to occasionally miss a violation than to break a
# legitimate operation on missing state.
#
# stdin: JSON with session_id, tool_name, tool_input (containing file_path)
# stdout: JSON for hook response
# Exit code: 0 on allow, 2 on deny

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/utils/log_helpers.sh"

input_json=$(cat)
session_id=$(printf '%s' "$input_json" | extract_json_field "session_id" || echo "unknown")

# Extract file_path from tool_input. Use a regex that's tolerant of various tool
# JSON shapes (Write, Edit, MultiEdit all have file_path at second nesting level).
file_path=$(printf '%s' "$input_json" \
    | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -n1 \
    | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')

# If we couldn't extract a file path, allow (don't break Edit operations on unparseable input)
if [ -z "$file_path" ]; then
    exit 0
fi

# Determine active agent
log_dir=$(ensure_session_log_dir "$session_id" 2>/dev/null || echo "/tmp/dummy")
active_file="${log_dir}/active-agent.txt"

if [ ! -f "$active_file" ]; then
    # No active agent recorded — main thread (orchestrator) or unknown. Treat as orchestrator.
    active_agent="orchestrator"
else
    active_agent=$(cat "$active_file" 2>/dev/null || echo "unknown")
fi

# Run the ownership validator
if "${SCRIPT_DIR}/validators/validate-file-ownership.sh" "$active_agent" "$file_path" 2>/tmp/ownership-err; then
    # Allowed
    exit 0
fi

reason=$(cat /tmp/ownership-err 2>/dev/null || echo "file ownership check failed")
reason_escaped=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n')

# Deny with reason
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "File ownership violation: ${reason_escaped}. See .claude-team/ ownership table in ARCHITECTURE-v2.1.md. If you need to update a file owned by another agent, delegate the change to that agent rather than writing directly."
  }
}
EOF

exit 2
