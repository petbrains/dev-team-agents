#!/usr/bin/env bash
# codex-detect.sh — decide whether the optional Codex reviewer is usable.
# On-demand helper (NOT registered in hooks.json). The Orchestrator runs it
# before a review stage; the codex-* agents may re-probe at runtime.
#
# stdout: `codex` | `internal`   (always exit 0 — detection never blocks)
# cache : .claude-team/current/.codex-availability  (tab-separated: decision<TAB>reason)
#
# Override precedence: off > on > auto (default).
#   task.md line:           **Codex review:** on | off | auto   (Orchestrator owns task.md)
#   preferences.json key:   "codex_review": "on" | "off" | "auto"
#   on   = prefer codex, but degrade to internal if the binary is missing
#   off  = never use codex
#   auto = use codex if available (default)
#
# Codex availability is a property of the *environment*, re-checked every task —
# it is cached in current/ (gitignored), never written to preferences.json.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TEAM_CURRENT="${PROJECT_DIR}/.claude-team/current"
DATA_DIR="${CLAUDE_PLUGIN_DATA:-${PROJECT_DIR}/.claude-team}"
CACHE="${TEAM_CURRENT}/.codex-availability"
PREFS="${DATA_DIR}/preferences.json"
TASK="${TEAM_CURRENT}/task.md"

emit() {
  # $1 = decision (codex|internal), $2 = reason
  mkdir -p "${TEAM_CURRENT}" 2>/dev/null
  printf '%s\t%s\n' "$1" "$2" > "${CACHE}"
  printf '%s\n' "$1"
  exit 0
}

# 1) Hard OFF (highest precedence)
if [ -f "${TASK}" ] && grep -qiE '^[[:space:]]*\*\*Codex review:\*\*[[:space:]]*off\b' "${TASK}"; then
  emit internal "off via task.md"
fi
if [ -f "${PREFS}" ] && grep -q '"codex_review"[[:space:]]*:[[:space:]]*"off"' "${PREFS}"; then
  emit internal "off via prefs"
fi

# 2) Forced ON (prefer codex, still degrade if binary missing)
FORCE_ON=0
if { [ -f "${TASK}" ] && grep -qiE '^[[:space:]]*\*\*Codex review:\*\*[[:space:]]*on\b' "${TASK}"; } \
 || { [ -f "${PREFS}" ] && grep -q '"codex_review"[[:space:]]*:[[:space:]]*"on"' "${PREFS}"; }; then
  FORCE_ON=1
fi

# 3) Availability probe — for `codex exec` the binary's presence is enough.
if command -v codex >/dev/null 2>&1 && codex --version >/dev/null 2>&1; then
  emit codex "binary available"
fi

# 4) Not available
[ "${FORCE_ON}" -eq 1 ] && emit internal "forced on but binary missing — internal"
emit internal "codex not found (default)"
