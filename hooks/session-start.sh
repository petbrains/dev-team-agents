#!/usr/bin/env bash
# SessionStart hook for dev-team-agents plugin.
#
# Three responsibilities:
# 1. Auto-init .claude-team/ in the project if it's missing (calls scripts/init-claude-team.sh)
# 2. Inject the using-dev-team-agents/SKILL.md operating manual into additionalContext
# 3. Append a brief plugin status footer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Source utility helpers
if [ -f "${SCRIPT_DIR}/utils/log_helpers.sh" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/utils/log_helpers.sh"
fi

# Auto-init .claude-team/ if missing or malformed
init_status="present"
if ! "${SCRIPT_DIR}/validators/validate-claude-team-structure.sh" "$PROJECT_ROOT" 2>/dev/null; then
    if [ -x "${PLUGIN_ROOT}/scripts/init-claude-team.sh" ]; then
        if "${PLUGIN_ROOT}/scripts/init-claude-team.sh" "$PROJECT_ROOT" >&2 2>&1; then
            init_status="created"
        else
            init_status="init-failed"
        fi
    else
        init_status="init-script-missing"
    fi
fi

# Detect plugin version from plugin.json
PLUGIN_VERSION="unknown"
if [ -f "${PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
    PLUGIN_VERSION="$(grep -E '^\s*"version"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" | head -n1 | sed -E 's/.*"version"\s*:\s*"([^"]+)".*/\1/')"
fi

# Read using-dev-team-agents/SKILL.md body (skip frontmatter)
SKILL_FILE="${PLUGIN_ROOT}/skills/using-dev-team-agents/SKILL.md"
SKILL_BODY=""
if [ -f "$SKILL_FILE" ]; then
    # Skip lines up through the SECOND `---` line (end of frontmatter), then take everything after
    SKILL_BODY=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$SKILL_FILE")
fi

# Compose the bootstrap message: skill body + status footer
if [ -n "$SKILL_BODY" ]; then
    BOOTSTRAP_MESSAGE="$SKILL_BODY

---

## Plugin status

dev-team-agents plugin v${PLUGIN_VERSION} loaded.
.claude-team/ status: ${init_status}

To activate Orchestrator: \`claude --agent dev-team-agents:orchestrator\`
Or in project settings: \`{ \"agent\": \"dev-team-agents:orchestrator\" }\`"
else
    # Fallback if SKILL.md missing — minimal status only
    BOOTSTRAP_MESSAGE="dev-team-agents plugin v${PLUGIN_VERSION} loaded.
.claude-team/ status: ${init_status}

WARNING: skills/using-dev-team-agents/SKILL.md not found — full operating manual unavailable.

To activate Orchestrator: claude --agent dev-team-agents:orchestrator"
fi

# Escape for JSON embedding
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

ESCAPED="$(escape_for_json "$BOOTSTRAP_MESSAGE")"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$ESCAPED"

exit 0
