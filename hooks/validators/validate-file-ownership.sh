#!/usr/bin/env bash
# Validator: file ownership rules.
#
# Given an agent name and a file path, returns 0 (allowed) or 1 (denied).
#
# Usage: validate-file-ownership.sh <agent_name> <file_path>
#
# Ownership rules apply only to paths under .claude-team/. Source code and other
# files outside .claude-team/ are not regulated here (those are project-policy,
# not pipeline-coordination concerns).

set -euo pipefail

agent_name="${1:-unknown}"
file_path="${2:-}"

if [ -z "$file_path" ]; then
    echo "validate-file-ownership: empty file_path" >&2
    exit 1
fi

# Normalize: convert absolute paths to relative-from-project if possible
# (caller usually passes the path Claude Code receives, which may be absolute)
proj_root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$file_path" in
    "$proj_root"/*) file_path="${file_path#$proj_root/}" ;;
    /*) ;;  # absolute but outside project — leave as-is
    *) ;;
esac

# Only files under .claude-team/ are subject to ownership rules.
case "$file_path" in
    .claude-team/*|*.claude-team/*) ;;
    *)
        # Outside .claude-team — allow (not our concern)
        exit 0
        ;;
esac

# Strip .claude-team/ prefix for matching against ownership patterns
relative="${file_path#*.claude-team/}"

# Returns 0 if relative matches pattern, 1 otherwise.
# Pattern uses extended regex.
matches() {
    local pattern="$1"
    printf '%s' "$relative" | grep -E -q "^${pattern}\$"
}

# Ownership table.
# orchestrator may write task.md and, while running in main thread, also any
# memory file as a fallback (though doc-keeper is preferred). Be permissive for
# main thread because Orchestrator does light edits in fast mode.
case "$agent_name" in
    orchestrator)
        # Main thread — task.md and (for fast mode) various things
        matches "current/task\\.md" && exit 0
        # Allow memory updates in fast mode (Doc-keeper normally does this but Orchestrator can in fast)
        matches "memory/.+\\.md" && exit 0
        # Allow runtime files
        matches "\\.runtime/.+" && exit 0
        ;;
    analyst)
        matches "current/analyst\\.md" && exit 0
        ;;
    architect)
        # PLANNER mode writes architecture.md; ARBITER mode writes architect-ruling.md
        matches "current/architecture\\.md" && exit 0
        matches "current/architect-ruling\\.md" && exit 0
        ;;
    debugger)
        matches "current/debug-report\\.md" && exit 0
        ;;
    reviewer)
        matches "current/review-feedback\\.md" && exit 0
        ;;
    developer|developer-opus)
        # developer-opus is the Opus-tier variant with identical file-ownership rules
        matches "current/dev-changes\\.md" && exit 0
        matches "current/review-rebuttal\\.md" && exit 0
        ;;
    developer-parallel)
        # Per-task report files: dev-changes-task-1.md, dev-changes-task-2.md, etc.
        matches "current/dev-changes-task-[A-Za-z0-9_-]+\\.md" && exit 0
        ;;
    qa)
        matches "current/qa-report\\.md" && exit 0
        ;;
    devops)
        # dev-changes.md OR setup-changes.md (solo runs)
        matches "current/dev-changes\\.md" && exit 0
        matches "current/setup-changes\\.md" && exit 0
        # Also memory/project.md (DevOps updates stack info)
        matches "memory/project\\.md" && exit 0
        ;;
    git)
        # Only dev-changes.md (appending commit log section)
        matches "current/dev-changes\\.md" && exit 0
        ;;
    doc-keeper)
        # All memory files, plus dev-changes.md (when running as part of pipeline)
        matches "memory/.+\\.md" && exit 0
        matches "current/dev-changes\\.md" && exit 0
        ;;
    meta-agent)
        # meta-agent writes agents/, not .claude-team/ — should never reach here for plugin files
        # If somehow targeting .claude-team/, deny
        ;;
    unknown|"")
        # Unknown agent — be permissive (better than blocking legitimate operations on missing info)
        exit 0
        ;;
    *)
        # Unrecognized agent — same as unknown
        exit 0
        ;;
esac

# No match found — deny
echo "validate-file-ownership: agent '${agent_name}' cannot write '${file_path}' (not in its allowed list)" >&2
exit 1
