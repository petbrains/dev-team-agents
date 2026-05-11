#!/usr/bin/env bash
# SubagentStart hook (matcher=*). Checks accumulated token usage for the session.
# Blocks new subagent dispatch if budget exceeded.
#
# Reads ${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/tool-calls.log written by track-tokens.sh
# Reads ${CLAUDE_PLUGIN_DATA}/preferences.json for max_session_tokens (default 1_000_000)
#
# stdin: JSON with session_id, hook_event_name
# stdout: JSON for hook response (deny if over budget)
# Exit code: 0 on allow, 2 on deny

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/utils/log_helpers.sh"

input_json=$(cat)
session_id=$(printf '%s' "$input_json" | extract_json_field "session_id" || echo "unknown")

log_dir=$(ensure_session_log_dir "$session_id" 2>/dev/null || echo "/tmp/dummy")
log_file="${log_dir}/tool-calls.log"

# If no log yet, no usage — allow
if [ ! -f "$log_file" ]; then
    exit 0
fi

# Sum approx_tokens column (4th field)
total_tokens=$(awk '{sum += $4} END {print sum+0}' "$log_file" 2>/dev/null || echo 0)

# Default budget — 1M tokens per session (generous for MVP; can be tuned)
# Reads override from preferences.json if present (very simple grep, no jq)
prefs_file="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/data/dev-team-agents}/preferences.json"
max_tokens=1000000
if [ -f "$prefs_file" ]; then
    override=$(grep -oE '"max_session_tokens"\s*:\s*[0-9]+' "$prefs_file" 2>/dev/null | grep -oE '[0-9]+' | head -n1)
    if [ -n "$override" ]; then
        max_tokens="$override"
    fi
fi

# Threshold: warn at 80%, deny at 100%
threshold=$((max_tokens * 80 / 100))

if [ "$total_tokens" -ge "$max_tokens" ]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStart",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Token budget exhausted: approximately ${total_tokens} tokens used in this session, max is ${max_tokens}. Halt and report to user; consider breaking task into smaller scope or starting a new session."
  }
}
EOF
    exit 2
fi

# Soft warning at 80% — log, don't deny. Orchestrator can pick up the warning from the file.
if [ "$total_tokens" -ge "$threshold" ]; then
    warn_file="${log_dir}/budget-warnings.log"
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    printf '%s threshold=%d total=%d\n' "$ts" "$threshold" "$total_tokens" >> "$warn_file" 2>/dev/null || true
fi

exit 0
