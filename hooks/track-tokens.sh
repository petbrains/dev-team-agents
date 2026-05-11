#!/usr/bin/env bash
# PostToolUse hook (async). Lightweight tool-call counter and approximate
# token usage tracker per session.
#
# Writes one line per tool call to ${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/tool-calls.log
#
# Format per line: <timestamp_iso8601> <tool_name> <approx_input_chars> <approx_output_chars>
#
# stdin: JSON from Claude Code with session_id, tool_name, tool_input, tool_response
# Always exit 0 (this hook is observational only — must not block tool execution)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/utils/log_helpers.sh"

input_json=$(cat)

# Defensive parse — if anything fails, exit 0 silently (observational hook)
session_id=$(printf '%s' "$input_json" | extract_json_field "session_id" || echo "unknown")
tool_name=$(printf '%s' "$input_json" | extract_json_field "tool_name" || echo "unknown")

# Approximate sizes — count chars in tool_input / tool_response sections
input_size=$(printf '%s' "$input_json" | wc -c)
# Approximate token count: chars / 4 is a rough heuristic
approx_tokens=$((input_size / 4))

log_dir=$(ensure_session_log_dir "$session_id" 2>/dev/null || echo "/tmp")
log_file="${log_dir}/tool-calls.log"

# ISO 8601 timestamp
ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Append line
printf '%s %s %d %d\n' "$ts" "$tool_name" "$input_size" "$approx_tokens" >> "$log_file" 2>/dev/null || true

exit 0
