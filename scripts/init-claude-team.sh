#!/usr/bin/env bash
# Initializes .claude-team/ directory structure in the current project.
#
# Idempotent: safe to run multiple times. Only creates files/dirs that don't exist.
#
# Layout (per ARCHITECTURE-v2.1.md):
#   .claude-team/
#   ├── memory/
#   │   ├── project.md
#   │   ├── decisions.md
#   │   ├── patterns.md
#   │   ├── gotchas.md
#   │   ├── session-log.md
#   │   └── index.md
#   └── current/
#       └── (empty — populated per task)

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
TEAM_DIR="${PROJECT_ROOT}/.claude-team"

if [ -d "$TEAM_DIR" ]; then
    echo "init-claude-team: ${TEAM_DIR} already exists, skipping init" >&2
    exit 0
fi

mkdir -p "${TEAM_DIR}/memory"
mkdir -p "${TEAM_DIR}/current"

# Memory placeholders — Doc-keeper will populate these later
cat > "${TEAM_DIR}/memory/project.md" <<'EOF'
# Project Memory

Stack, versions, conventions, "how we do things here". Maintained by Doc-keeper agent.

This file is read by all agents. Keep it concise (under 200 lines).

## Stack
TBD

## Conventions
TBD
EOF

cat > "${TEAM_DIR}/memory/decisions.md" <<'EOF'
# Architectural Decisions

ADR-lite log of "why we chose X over Y". Maintained by Doc-keeper after Architect's significant decisions.

Format per entry:
## YYYY-MM-DD: [decision title]
**Context:**
**Decision:**
**Consequences:**
EOF

cat > "${TEAM_DIR}/memory/patterns.md" <<'EOF'
# Project Patterns

How we do specific things in this codebase: forms, error handling, logging, etc.
Maintained by Doc-keeper. Read by Architect, Developer, Reviewer.
EOF

cat > "${TEAM_DIR}/memory/gotchas.md" <<'EOF'
# Project Gotchas

Non-obvious traps and "we tried that, it failed because X". Maintained by Doc-keeper.
Read by Developer, Debugger.
EOF

cat > "${TEAM_DIR}/memory/session-log.md" <<'EOF'
# Session Log

Chronological log of what was done in recent sessions. Maintained by Doc-keeper.
Read by Analyst (when picking up next task), Debugger.
EOF

cat > "${TEAM_DIR}/memory/index.md" <<'EOF'
# Memory Index

"If task is about X, read Y" map. Maintained by Doc-keeper.
EOF

# .gitignore for current/ — task-specific files don't go in git
cat > "${TEAM_DIR}/current/.gitignore" <<'EOF'
# Task-specific files are session-local, not committed
*
!.gitignore
EOF

echo "init-claude-team: created ${TEAM_DIR}/" >&2
exit 0
