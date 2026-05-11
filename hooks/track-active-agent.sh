#!/usr/bin/env bash
# SubagentStart hook (matcher=*). Records the currently active subagent's name
# to ${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/active-agent.txt so that
# subsequent PreToolUse hooks can determine which agent is trying to write.
#
# Race conditions: parallel developers may overwrite this file. Since worktree
# isolation gives each parallel a separate working tree, file conflicts are
# physically prevented at the source-code level — the active-agent.txt race only
# affects ownership checks on .claude-team/current/, where parallel developers
# write to per-task files (dev-changes-task-N.md) anyway.
#
# stdin: JSON with session_id, agent_type (or agent_name)
# Always exit 0 — observational, never blocks subagent dispatch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/utils/log_helpers.sh"

input_json=$(cat)
session_id=$(printf '%s' "$input_json" | extract_json_field "session_id" || echo "unknown")

# Try several field names — platform may use different ones across versions
agent_name=""
for field in "agent_type" "agent_name" "subagent_type" "subagent_name"; do
    candidate=$(printf '%s' "$input_json" | extract_json_field "$field" 2>/dev/null || echo "")
    if [ -n "$candidate" ]; then
        agent_name="$candidate"
        break
    fi
done

if [ -z "$agent_name" ]; then
    agent_name="unknown"
fi

# Strip plugin prefix if present (e.g. "dev-team-agents:developer" → "developer")
agent_name="${agent_name##*:}"

log_dir=$(ensure_session_log_dir "$session_id" 2>/dev/null || echo "/tmp")
printf '%s' "$agent_name" > "${log_dir}/active-agent.txt" 2>/dev/null || true

exit 0
