#!/usr/bin/env bash
# Utility helpers shared across hook scripts.
#
# Sourced by other hooks via:
#   . "${SCRIPT_DIR}/utils/log_helpers.sh"

# Ensures per-session log directory exists and prints its path.
#
# Layout: ${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/
# Falls back to ~/.claude/data/dev-team-agents/sessions/<session_id>/ if
# CLAUDE_PLUGIN_DATA is not set.
ensure_session_log_dir() {
    local session_id="${1:-unknown}"
    local data_root="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/data/dev-team-agents}"
    local log_dir="${data_root}/sessions/${session_id}"
    mkdir -p "$log_dir"
    printf '%s' "$log_dir"
}

# Append a JSON line to a JSONL log file (newline-delimited JSON).
# Use for high-frequency events like tool calls.
append_jsonl() {
    local file="$1"
    local json_line="$2"
    printf '%s\n' "$json_line" >> "$file"
}

# Read JSON from stdin, extract a single field (basic, no jq dependency).
# Usage: extract_json_field "session_id" < /dev/stdin
extract_json_field() {
    local field_name="$1"
    grep -oE "\"${field_name}\"\s*:\s*\"[^\"]*\"" | head -n1 | sed -E "s/\"${field_name}\"\s*:\s*\"([^\"]*)\"/\1/"
}
