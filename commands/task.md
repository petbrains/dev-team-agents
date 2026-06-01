---
description: Start a dev-team work session from a task list or a doc link — auto-classifies, groups, and runs each item through the right pipeline.
argument-hint: <task list, or a URL / file path to a doc>
allowed-tools: Task, Read, Write, Edit, Bash, Glob, Grep, TodoWrite, AskUserQuestion, NotebookRead, WebFetch, WebSearch
---

You are the **Orchestrator** (main thread) of the dev-team-agents plugin. The user invoked `/task` to kick off a work session without spelling out each step. Your operating manual is the `using-dev-team-agents` skill (auto-injected at session start) and the orchestrator system prompt — this command does NOT restate the pipeline mechanics; it defines how to **intake the request and sequence the work**, then you run each item exactly as the manual prescribes.

## Input

The work is everything the user passed as arguments:

<input>
$ARGUMENTS
</input>

If `<input>` is empty or whitespace, do not guess — ask the user (one short prompt) to paste the task list or a link/path to the doc, then stop and wait.

## Step 1 — Resolve the input into raw requirements

Detect the form of the input and obtain the actual text:

- **URL** (`http://` / `https://`) → use `WebFetch` to read it. If it's a tracker/issue link (GitHub issue, Jira, Linear, Notion, Google Doc) and the fetch fails or returns auth-walled content, tell the user it couldn't be read and ask them to paste the relevant text.
- **Local file path or `@`-reference** (e.g. `docs/spec.md`, `./TODO.md`) → `Read` it.
- **Inline text** (a list, prose, a single sentence) → use it directly.
- **Mixed** (e.g. "do X, see also <link>") → read the link AND keep the inline instructions; merge both.

Do not start any pipeline before you have the concrete requirement text in hand.

## Step 2 — Normalize into a backlog

Distill the resolved text into a **discrete, ordered list of tasks**. Collapse duplicates, split compound items ("add endpoint and write docs" → two tasks if they're genuinely separable), and drop pure noise. Keep the user's intent and any acceptance criteria they stated.

Write the backlog to `.claude-team/current/backlog.md` (create the dir/file) so it survives across pipelines:

```markdown
# Backlog

**Source:** [inline | <url> | <file path>]
**Captured:** <date>

| # | Task | Group | Status |
|---|------|-------|--------|
| 1 | ... | A | pending |
| 2 | ... | A | pending |
| 3 | ... | B | pending |
```

Mirror the same list into `TodoWrite` so progress is visible.

## Step 3 — Auto-group (multi-task handling = AUTO)

Decide grouping yourself; only ask the user when genuinely ambiguous:

- **Related tasks** (same feature, shared files, one depends on another) → **one pipeline**. Combine them into a single classified task whose scope covers the group. This is usually right for a cohesive feature spec.
- **Independent tasks** (different features/areas, no shared state) → **separate pipelines, run strictly sequentially** — finish one fully (through Git) before starting the next. Never run two pipelines with overlapping files at once.
- **Ordering:** respect stated dependencies; otherwise keep the user's order.

If the split is genuinely unclear (e.g. you can't tell whether two items touch the same code), ask **one** `AskUserQuestion` showing your proposed grouping and let the user confirm or regroup. Don't barrage.

State your grouping decision in one or two sentences before you begin (not a pause — just announce and proceed).

## Step 4 — Run each group through the standard flow

For each group, in order, follow the operating manual exactly:

1. **Classify** (task type × project type) and **select mode** (full/fast) per the defaults table — for `feature`/`bug` ask the user full-vs-fast as usual.
2. Write/refresh `.claude-team/current/task.md` for that group.
3. Execute the pipeline for that (type × mode): spawn specialists via `Task`, communicate through the file bus, honor the 4-status protocol, rebuttal flow, token budget, and **all HITL gates** (greenfield understanding, plan confirm, mode selection, escalations).
4. On completion, mark the row(s) in `backlog.md` and the matching `TodoWrite` items **done**, give a one-line result, then move to the next group.

Apply **continuous execution**: don't ask "shall I continue?" between groups — only stop at legitimate HITL gates, a BLOCKED you can't resolve, a budget cap, or genuine blocking ambiguity. Token budgets are **per group/task**, not shared across the whole backlog.

If a group ends BLOCKED or the user aborts it, record that in `backlog.md`, then continue with the remaining independent groups (skip ones that depended on the blocked work, and say so).

## Step 5 — Final summary

When the backlog is exhausted, give a compact roll-up: which tasks shipped, which were skipped/blocked and why, key files touched, and any follow-ups the agents flagged (e.g. a CLAUDE.md update Doc-keeper noted). Ensure `TodoWrite` is fully reconciled.
