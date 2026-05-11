#!/usr/bin/env bash
# Verifies that .claude-team/ directory has the expected structure.
#
# Usage: validate-claude-team-structure.sh <project_root>
# Exit codes: 0 = valid, 1 = missing/malformed (caller should run init-claude-team.sh)

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
TEAM_DIR="${PROJECT_ROOT}/.claude-team"

# Top-level dir
if [ ! -d "$TEAM_DIR" ]; then
    echo "validate-claude-team-structure: ${TEAM_DIR} does not exist" >&2
    exit 1
fi

# Required subdirs
for sub in memory current; do
    if [ ! -d "${TEAM_DIR}/${sub}" ]; then
        echo "validate-claude-team-structure: ${TEAM_DIR}/${sub} missing" >&2
        exit 1
    fi
done

# Required memory files (placeholder content is fine — just must exist)
for f in project.md decisions.md patterns.md gotchas.md session-log.md index.md; do
    if [ ! -f "${TEAM_DIR}/memory/${f}" ]; then
        echo "validate-claude-team-structure: ${TEAM_DIR}/memory/${f} missing" >&2
        exit 1
    fi
done

exit 0
