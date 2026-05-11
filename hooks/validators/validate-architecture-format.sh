#!/usr/bin/env bash
# Verifies that .claude-team/current/architecture.md exists and has the
# minimum required structure (sections that Developer needs to do their job).
#
# Usage: validate-architecture-format.sh <project_root>
# Exit codes: 0 = valid, 1 = missing or malformed

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
ARCH_FILE="${PROJECT_ROOT}/.claude-team/current/architecture.md"

# File exists and not empty
if [ ! -f "$ARCH_FILE" ]; then
    echo "validate-architecture-format: ${ARCH_FILE} does not exist" >&2
    exit 1
fi

if [ ! -s "$ARCH_FILE" ]; then
    echo "validate-architecture-format: ${ARCH_FILE} is empty" >&2
    exit 1
fi

# Required sections (case-insensitive header match — accepts variations)
required_sections=(
    "^# "                          # title heading
    "^## File Structure"           # what files to create/modify
    "^## Tasks"                    # the actual work
    "^\\*\\*Goal:\\*\\*"            # one-line goal
    "^\\*\\*Architecture Decision:\\*\\*"  # chosen approach
)

for pattern in "${required_sections[@]}"; do
    if ! grep -E -q "$pattern" "$ARCH_FILE"; then
        echo "validate-architecture-format: missing required section matching '${pattern}'" >&2
        exit 1
    fi
done

# Sanity check: file isn't suspiciously tiny (a real plan is at least a few hundred bytes)
size=$(wc -c < "$ARCH_FILE")
if [ "$size" -lt 200 ]; then
    echo "validate-architecture-format: file too small (${size} bytes); likely incomplete" >&2
    exit 1
fi

exit 0
