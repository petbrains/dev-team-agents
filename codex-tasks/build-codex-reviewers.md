# Task for Codex: build the two optional Codex reviewer agents

You are extending the **dev-team-agents** Claude Code plugin. The Orchestrator, the
internal Reviewer, the plan-review stage, the detection hook (`hooks/codex-detect.sh`),
and the prompt templates (`prompts/codex-code-review.md`, `prompts/codex-plan-review.md`)
already exist. Your job is to create **two agent definition files** that wire Codex in as
an optional reviewer, with clean fallback to the internal Reviewer.

## Deliverables

Create exactly two files:

1. `agents/codex-code-reviewer.md` — reviews **code**, writes `review-feedback.md`.
2. `agents/codex-doc-reviewer.md` — reviews the **plan**, writes `review-plan-feedback.md`.

Do **not** modify any other file. The Orchestrator already knows how to route to these
agents and how to fall back; the validator (`hooks/validators/validate-file-ownership.sh`)
already allows them to write their respective files.

---

## Plugin conventions you MUST follow

### Agent frontmatter

Every agent file starts with YAML frontmatter, then a Markdown body. Match this shape
(see `agents/reviewer.md` for the canonical example):

```yaml
---
name: codex-code-reviewer
description: "One-paragraph description of role, when invoked, what it reads and writes."
tools: Read, Write, Bash, Glob, Grep
model: sonnet
color: magenta
---
```

- `tools:` — **`Read, Write, Bash, Glob, Grep`** only. No `Edit` (reviewers don't patch code), no `Task`.
- `model: sonnet` — the heavy reasoning happens inside Codex, not in this agent.
- `color:` — pick a distinct color. Already used: purple (orchestrator), cyan (analyst), green (architect), blue (developers), red (reviewer). Suggest `magenta` for code, `yellow` for doc.
- `name:` must exactly equal the filename stem and the name the Orchestrator/validator use: `codex-code-reviewer`, `codex-doc-reviewer`.

### Markers (a hook parses these — formatting is load-bearing)

- Approval markers must be **bold** exactly: `**APPROVED**`, `**CHANGES REQUESTED**`, `**BLOCKED**` (code) and `**PLAN APPROVED**`, `**PLAN CHANGES REQUESTED**`, `**PLAN BLOCKED**` (plan).
- **Never** let two approval markers co-occur in one file — the validator treats that as a failure.
- The commit gate (`hooks/validators/validate-review-passed.sh`) greps for `**APPROVED**` inside `review-feedback.md`. So: only a genuine code approval may contain that exact bold token, and only in `review-feedback.md`. The plan file must use the `**PLAN ...**` markers and never the bare `**APPROVED**`.

### File bus

All coordination files live in `.claude-team/current/`. Scratch files you create
(`.codex-*`) also go under `current/` and are gitignored. You read inputs from there and
write your single verdict file there.

---

## Shared behavior (both agents)

### Step 1 — confirm Codex is usable

Run the detection helper and re-probe at runtime:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/codex-detect.sh"   # prints `codex` or `internal`
command -v codex >/dev/null 2>&1 && codex --version >/dev/null 2>&1
```

If detection says `internal`, or `codex` is not actually runnable, or any invocation below
errors / returns empty / returns invalid JSON:

- **Do NOT write the verdict file.** (Absence of the file is the Orchestrator's signal to fall back.)
- Return a final message of `BLOCKED` containing the exact token `CODEX_UNAVAILABLE` (binary/detection problem) or `CODEX_ERROR` (ran but failed/invalid output).
- This is **fail-closed**: a partial or guessed verdict is worse than no verdict.

### Step 2 — invoke `codex exec` (prompt via stdin)

The prompt comes through **stdin** (avoids Windows command-line length/quoting limits). Use:

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TEAM_CURRENT="${PROJECT_DIR}/.claude-team/current"

codex exec --sandbox read-only --skip-git-repo-check --cd "${PROJECT_DIR}" - \
  < "${TEAM_CURRENT}/<input-file>.md" \
  > "${TEAM_CURRENT}/<raw-output>.txt" 2>"${TEAM_CURRENT}/<stderr>.txt"
```

- `--sandbox read-only` — the reviewer never edits code.
- `--skip-git-repo-check` — don't fail on repo checks.
- `--cd "${PROJECT_DIR}"` — run in the project root.
- RC ≠ 0, empty stdout, or a non-JSON body ⇒ treat as `CODEX_ERROR` per Step 1.

### Step 3 — parse JSON, filter, map to the verdict file

Codex returns a single JSON object (the prompt templates enforce this). Parse it, keep only
findings with `confidence` ≥ **80**, then write the verdict file in the exact internal
template (below) so the commit gate, rebuttal, and arbiter flows work unchanged.

---

## Agent 1 — `codex-code-reviewer`

**Reads:** `architecture.md` (for the plan summary), `dev-changes.md`, the diff (via Bash);
optionally `memory/patterns.md`, `memory/decisions.md`, `CLAUDE.md`.
**Writes:** `.claude-team/current/review-feedback.md`.
**Prompt template:** `prompts/codex-code-review.md`. **Input file:** `.codex-review-input.md`.

### Collect the diff (mirror Codex's git collection)

```bash
# dirty working tree → review uncommitted work
git diff --cached --binary --no-ext-diff --submodule=diff
git diff        --binary --no-ext-diff --submodule=diff
git status --short --untracked-files=all    # include untracked text files ≤ 24 KB; skip binaries
# clean tree → review the branch vs the default branch
BASE=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo main)
MB=$(git merge-base HEAD "$BASE")
git diff --binary --no-ext-diff --submodule=diff "$MB..HEAD"
```

If the assembled diff exceeds ~**256 KB**, switch to summary mode: send `git diff --stat`
plus the file list as `{{REVIEW_INPUT}}`, and note that Codex may inspect files itself in its
read-only sandbox.

### Build the input file

Fill `prompts/codex-code-review.md` placeholders and write to `.codex-review-input.md`:
- `{{TARGET_LABEL}}` — "working-tree diff" or "branch <MB>..HEAD".
- `{{PLAN_SUMMARY}}` — condensed intent from `architecture.md`.
- `{{REVIEW_INPUT}}` — the diff (or summary).

### Map JSON → `review-feedback.md`

Write this exact structure (matches the internal Reviewer's template):

```markdown
# Review Feedback

**Reviewed by:** Codex (codex exec)
**Mode:** INITIAL
**Date:** <iso>

## Approval status

<one of: **APPROVED** | **CHANGES REQUESTED** | **BLOCKED**>

## Critical issues

<numbered list of severity=critical, confidence≥80, or "None">

## Important issues

<numbered list of severity=important, confidence≥80, or "None">

## Minor notes

<optional, brief>

## Summary

<the JSON summary>

## Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
```

Mapping rules:
- `verdict = "approve"` AND no finding ≥ 80 ⇒ `**APPROVED**`, `## Status: DONE`.
- Any finding ≥ 80 (critical/important) ⇒ `**CHANGES REQUESTED**`, `## Status: DONE`.
- `verdict = "blocked"` / cannot review ⇒ do **not** write the file; signal `CODEX_UNAVAILABLE`/`CODEX_ERROR` (Step 1) so the Orchestrator falls back to the internal Reviewer.
- Exactly one approval marker in the file. Never co-occur.

---

## Agent 2 — `codex-doc-reviewer`

**Reads:** `architecture.md` (the plan) and `analyst.md` (requirements, when present).
**Writes:** `.claude-team/current/review-plan-feedback.md`.
**Prompt template:** `prompts/codex-plan-review.md`. **Input file:** `.codex-plan-input.md`.

### Build the input file

Fill `prompts/codex-plan-review.md` placeholders and write to `.codex-plan-input.md`:
- `{{REQUIREMENTS}}` — contents of `analyst.md`, or "none provided".
- `{{PLAN}}` — contents of `architecture.md`.

### Map JSON → `review-plan-feedback.md`

```markdown
# Plan Review Feedback

**Reviewed by:** Codex (codex exec)
**Mode:** PLAN REVIEW
**Date:** <iso>

## Approval status

<one of: **PLAN APPROVED** | **PLAN CHANGES REQUESTED** | **PLAN BLOCKED**>

## Critical issues

<numbered list, confidence≥80, each tagged `owner: analyst` or `owner: architect`, or "None">

## Important issues

<numbered list, confidence≥80, each tagged `owner: analyst` or `owner: architect`, or "None">

## Minor notes

<optional, brief>

## Summary

<the JSON summary>

## Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
```

Mapping rules:
- `verdict = "approve"` AND no finding ≥ 80 ⇒ `**PLAN APPROVED**`, `## Status: DONE`.
- Any finding ≥ 80 ⇒ `**PLAN CHANGES REQUESTED**`, `## Status: DONE`. Carry each finding's `owner` through as an `owner: analyst|architect` tag — the Orchestrator routes the fix by it.
- `verdict = "blocked"` / cannot review ⇒ prefer signalling `CODEX_UNAVAILABLE`/`CODEX_ERROR` and not writing the file; if you must write, `**PLAN BLOCKED**` + `## Status: BLOCKED`.
- Use the `**PLAN ...**` markers — **never** the bare `**APPROVED**`. That bare token in this file would risk the commit gate.
- Exactly one approval marker. Never co-occur.

---

## Acceptance checklist

- [ ] `agents/codex-code-reviewer.md` and `agents/codex-doc-reviewer.md` exist with valid frontmatter (`name`, `description`, `tools: Read, Write, Bash, Glob, Grep`, `model: sonnet`, `color`).
- [ ] Each agent probes availability first and **fails closed** (no file written) on `internal`/error/invalid-JSON, signalling `CODEX_UNAVAILABLE`/`CODEX_ERROR`.
- [ ] `codex exec` is invoked with `--sandbox read-only --skip-git-repo-check --cd`, prompt via stdin.
- [ ] code-reviewer collects the diff (cached + working + untracked, or branch-vs-default), respects the 256 KB summary fallback, and writes `review-feedback.md` in the exact template with one of `**APPROVED**`/`**CHANGES REQUESTED**`/`**BLOCKED**`.
- [ ] doc-reviewer writes `review-plan-feedback.md` with one of `**PLAN APPROVED**`/`**PLAN CHANGES REQUESTED**`/`**PLAN BLOCKED**` and `owner:` tags.
- [ ] No file ever contains two approval markers.
- [ ] Confidence filter ≥ 80 applied before listing findings.
