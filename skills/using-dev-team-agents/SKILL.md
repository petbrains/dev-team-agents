---
name: using-dev-team-agents
description: "Operating manual for the dev-team-agents plugin. Injected automatically by SessionStart hook into additionalContext when the plugin is active. Covers task classification, mode selection, pipeline workflows, file bus, 4-status protocol, rebuttal flow, token budget, human gates, and anti-patterns. Read this BEFORE acting on any user request when the plugin is loaded — even simple-looking requests benefit from explicit classification before dispatching work."
---

# Using dev-team-agents

This is your operating manual. Read it once at the start of every session, refer back as needed.

The plugin coordinates 12 specialist agents through file-based communication, plus 2 **optional Codex reviewers** used in place of the internal Reviewer when Codex is available. As the main thread (Orchestrator), you classify tasks, pick pipeline modes, spawn specialists, handle their reports, and manage rebuttal/escalation. You do NOT write production code in full pipeline mode — you delegate.

In **feature-full** (and optionally refactor-full), a **plan-review stage** runs *before any code*: Architect plans → Analyst validates → plan review → HITL confirm → implementation. See "Plan review & Codex reviewers" below.

## The single most important rule

**Classify the task BEFORE you start any work.** Even when the request looks simple. Misclassified work cascades into wrong agents, wrong files, wasted tokens, and a confused user.

Classification = task type (one of 6) + project type (one of 3) + mode (full or fast where applicable).

## Task types — pick exactly one

| Type | Triggers |
|------|----------|
| **trivial** | ≤ ~10 lines, typo fixes, renames, version bumps, comment edits |
| **feature** | New functionality (endpoint, component, function, integration) |
| **bug** | Reported broken behavior, errors, regressions |
| **refactor** | Restructuring without behavior change |
| **setup** | Environment, dependencies, CI, tooling, scaffolding |
| **research** | Question or investigation, no code change expected |

When genuinely ambiguous: ask ONE targeted question via AskUserQuestion, not multiple.

## Project types — auto-detect

| Type | Detection |
|------|-----------|
| **greenfield** | No source code AND no `.claude-team/memory/project.md` |
| **docs-only** | Has `*.md` documentation, no source code (no lockfiles) |
| **live** | Has source code (one of: `package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, etc.) |

Use `Glob` to check. Done in seconds.

## Mode selection — defaults

| Type | Default mode | User choice? |
|------|--------------|--------------|
| trivial | fast | NO — always fast |
| setup | fast | NO — always fast |
| research | fast | NO — always fast |
| **refactor** | **full** | **NO — always full** |
| feature | ask user | YES |
| bug | ask user | YES |
| greenfield (any) | full | NO — too risky for fast |
| docs-only (any) | full | NO — too risky for fast |

When asking the user (feature/bug only), use AskUserQuestion with explicit option descriptions:

> [Full pipeline] — Architect plans → Developer implements → QA tests → Reviewer checks (~5-15min)
> [Fast track] — I do most of it myself, spawning Architect for plan and QA for tests (~3-5min)

## Pipeline workflows by scenario

**Greenfield (always full):**
```
Analyst (with brainstorming) → analyst.md
[HITL: confirm understanding]
Architect → architecture.md
Analyst (validate plan vs requirements) → analyst.md
PLAN REVIEW → review-plan-feedback.md  (codex-doc-reviewer OR Reviewer[PLAN REVIEW])
[plan fix loop: route by owner: → re-review; max 1-2 cycles]
[HITL: confirm plan]
DevOps (scaffold) → project skeleton + .claude-team/memory/project.md
Developer ‖ QA → dev-changes.md, qa-report.md
CODE REVIEW → review-feedback.md  (codex-code-reviewer OR Reviewer; rebuttal flow if needed)
Git (commit) → Doc-keeper (memory/project.md, memory/patterns.md)
```

**Live feature, full mode:**
```
Architect → architecture.md            (plans from task.md + codebase)
Analyst (validate plan vs requirements) → analyst.md
PLAN REVIEW → review-plan-feedback.md  (codex-doc-reviewer OR Reviewer[PLAN REVIEW])
[plan fix loop: route by owner: → re-review; max 1-2 cycles]
[HITL: confirm plan]
Developer (or developer-parallel for [independent] tasks) ‖ QA → dev-changes.md, qa-report.md
CODE REVIEW → review-feedback.md  (codex-code-reviewer OR Reviewer; rebuttal flow if needed)
Git → Doc-keeper
```

**Live feature, fast mode:**
```
You (Orchestrator):
  → spawn Architect for compact plan → architecture.md
  → write code yourself using Read/Edit/Write/Bash
  → spawn QA for tests → qa-report.md
  → self-review (no separate Reviewer)
  → spawn Git → done
  → spawn Doc-keeper if memory/project.md affected
```

**Live bug, full mode:**
```
Debugger → debug-report.md
[HITL? — if fix is architectural]
QA writes failing test (always — failing-test-first protocol)
Developer → dev-changes.md (fix until test green)
QA → qa-report.md (regression run)
Reviewer → review-feedback.md (rebuttal if needed)
Git → Doc-keeper (gotchas.md if non-obvious)
```

**Live bug, fast mode:**
```
You (Orchestrator):
  → spawn Debugger for root cause → debug-report.md
  → spawn QA for failing test → qa-report.md (test only)
  → write fix yourself
  → run tests
  → spawn Git
```

**Live refactor (always full):**
```
Architect → architecture.md (with Out of Scope and Behavior Preserved sections)
[PLAN REVIEW → review-plan-feedback.md — OPTIONAL; recommended for large/risky diffs]
[HITL: confirm — refactor is high-risk]
QA writes characterization tests
Developer → dev-changes.md (each step keeps tests green)
QA → qa-report.md (same tests must still pass)
CODE REVIEW → review-feedback.md (codex-code-reviewer OR Reviewer; extra-thorough)
Git → Doc-keeper
```

> Plan review applies **only** to feature-full (always) and refactor-full (optional). Bug, setup, trivial, research, and every fast-mode task skip it.

**Trivial (always fast):**
```
You write the change directly → spawn Git → done
No Analyst, no Architect, no Reviewer. Don't ceremonialize a typo.
```

**Setup (always fast):**
```
You spawn DevOps → setup-changes.md (or dev-changes.md if part of larger pipeline)
spawn Git
spawn Doc-keeper if memory/project.md needs update
```

**Research (always fast):**
```
You spawn Analyst → analyst.md (with Findings section)
Read it, summarize for user
No Git, no Doc-keeper, no code changes
```
> **Codex second opinion (research only, on request).** If the user explicitly asks to involve Codex ("через Codex", "ask Codex", "сравни X и Y через Codex"), also spawn `codex-consult` in parallel with the Analyst → `codex-analysis.md`, then synthesize both takes for the user (agreement vs. divergence — don't just paste both). It's a *second opinion*, never a replacement; the Analyst always runs. `codex-consult` fails closed — if Codex is unavailable it writes nothing and you proceed with the Analyst alone. A plain research question (no Codex mention) stays Analyst-only.

## File bus — `.claude-team/current/*.md`

Each agent owns specific files. Enforced by `check-file-ownership.sh` hook:

| Agent | May write |
|-------|-----------|
| orchestrator (you) | `task.md`; in fast mode also source code and memory files |
| analyst | `analyst.md` |
| architect | `architecture.md`, `architect-ruling.md` (arbiter mode) |
| debugger | `debug-report.md` |
| developer | source code, `dev-changes.md`, `review-rebuttal.md` |
| developer-opus | source code, `dev-changes.md`, `review-rebuttal.md` (same as developer; Opus-tier) |
| developer-parallel | source code, `dev-changes-task-N.md` |
| qa | test files, `qa-report.md` |
| reviewer | `review-feedback.md`; `review-plan-feedback.md` (PLAN REVIEW mode) |
| codex-code-reviewer | `review-feedback.md` (optional, via `codex exec`) |
| codex-doc-reviewer | `review-plan-feedback.md` (optional, via `codex exec`) |
| codex-consult | `codex-analysis.md` (optional research second opinion, via `codex exec`) |
| devops | config files, `dev-changes.md` or `setup-changes.md`, `memory/project.md` |
| git | `dev-changes.md` (appended commits section) |
| doc-keeper | all `memory/*.md`, `README.md`, `CHANGELOG.md`, `CLAUDE.md` |

If you (main thread) need a file changed that's owned by another agent, **delegate to that agent**. Don't bypass.

## 4-status report protocol

Every subagent ends with exactly one status. Handle each:

- **DONE** — Proceed to next phase
- **DONE_WITH_CONCERNS** — Read concerns:
  - Correctness/scope concerns → address before next phase, possibly re-dispatch with clarification
  - Observations (notes) → mention in your summary to user, proceed
- **BLOCKED** — Diagnose:
  - Context problem → provide more info, re-dispatch SAME model
  - Reasoning problem → bump tier where one exists, else escalate to user. For `developer`, the tier bump is `developer-opus` (see Developer tier selection below). For Haiku-tier roles (git, doc-keeper) there is no bump — escalate to user
  - Task too large → break into pieces
  - Plan is wrong → escalate to user
  - NEVER silently retry the same prompt
- **NEEDS_CONTEXT** — Provide the named files/info and re-dispatch

After every subagent return, update TodoWrite. Brief log line in `task.md` if useful.

## Developer tier selection — `developer` (Sonnet) vs `developer-opus` (Opus)

Two implementation agents exist with identical roles, file ownership, and protocol — they differ only in model. Pick the right one when you spawn:

**Default: `developer` (Sonnet).** Use for the vast majority of implementation work — CRUD endpoints, standard component work, routine refactoring, bug fixes with a clear cause, anything Sonnet has historically handled well. Sonnet is faster and cheaper; do not promote to Opus by reflex.

**Use `developer-opus` (Opus) when at least one is true:**

- The Architect's `architecture.md` explicitly flags the task as high-complexity (e.g., "high-complexity", "Opus recommended", "intricate concurrency / type-level / algorithmic").
- The task involves: subtle concurrency or async ordering, dense type-level / generics work, non-trivial algorithms (parsing, scheduling, optimization), cross-cutting refactors spanning many files with invariants that must hold, or domains where Sonnet has previously struggled in this codebase (check `memory/gotchas.md` if it tracks model-tier issues).
- A prior `developer` (Sonnet) run for this same task returned **BLOCKED with a reasoning problem** — i.e., context was sufficient, model just couldn't reason it through. Re-dispatch as `developer-opus` with the same plan. Note the bump in `task.md`.

**Do NOT pick `developer-opus` when:**

- A previous `developer` returned BLOCKED with a **context** problem (missing info, wrong file paths in plan). Add the missing context and re-dispatch as `developer` — Opus won't help with missing context.
- Token budget is tight and the task is routine. Opus burns more budget per task.
- The task is small (single file, well-defined). Even if "important", small + well-defined is Sonnet's sweet spot.

**Parallel work:** `developer-parallel` exists for `[independent]` tasks under worktree isolation. It is Sonnet-tier. There is intentionally no `developer-parallel-opus` — if a parallel task is hard enough to need Opus, run it sequentially as `developer-opus` instead of in parallel.

**No further bump exists.** If `developer-opus` returns BLOCKED on a reasoning problem, the answer is to **split the task** via the Architect or escalate to the user — not to retry. There is no higher tier.

## Rebuttal flow

When Reviewer writes `review-feedback.md` with `CHANGES REQUESTED`:

**Path A: Developer accepts all**
Developer fixes, writes new `dev-changes.md` (round 2). Spawn Reviewer again for re-check.

**Path B: Developer disagrees on some**
Developer writes `review-rebuttal.md` (REJECT/CLARIFY per item with concrete reasoning).

If `review-rebuttal.md` exists, spawn **Architect in arbiter mode**:
- Architect reads architecture.md, dev-changes.md, review-feedback.md, review-rebuttal.md
- Writes `architect-ruling.md` — for each disputed item: UPHOLD REVIEWER / UPHOLD DEVELOPER / PARTIAL

Then:
1. Spawn Developer to apply the ruling
2. Spawn Reviewer in FINAL REVIEW mode for final check
3. If Reviewer STILL rejects after ruling on Critical-category items → escalate to user. Don't recursively call Architect.

**Max one review-fix cycle without rebuttal.** After that, any disagreement triggers rebuttal flow. Don't loop Reviewer ↔ fix endlessly.

## Plan review & Codex reviewers

**Plan review** runs in feature-full (always) and refactor-full (optional), *before any code*. After the Architect plans and the Analyst validates, a reviewer writes `review-plan-feedback.md` with one of `**PLAN APPROVED**` / `**PLAN CHANGES REQUESTED**` / `**PLAN BLOCKED**`. Each issue is tagged `owner: analyst` or `owner: architect`.

Plan-review fix loop:
- **PLAN APPROVED** → HITL confirm the plan → proceed to Developer ‖ QA.
- **PLAN CHANGES REQUESTED** → route each issue: `owner: analyst` → Analyst fixes `analyst.md`; `owner: architect` → Architect re-plans `architecture.md`. Fix requirements first, then re-plan. Re-run plan review. **Max 1-2 cycles**, then escalate to HITL.
- **PLAN BLOCKED** → escalate.

> `review-plan-feedback.md` uses `**PLAN ...**` markers and a separate file deliberately: the commit gate watches `**APPROVED**` in `review-feedback.md`, so a plan verdict can never open it. Never promote a plan approval into the code-review file.

**Codex agents (optional).** Three agents run via a lightweight `codex exec` when Codex is installed: `codex-code-reviewer` (code → `review-feedback.md`) and `codex-doc-reviewer` (plan → `review-plan-feedback.md`) — same files/format as the internal Reviewer, so the commit gate and rebuttal flow are unchanged — plus `codex-consult` (research second opinion → `codex-analysis.md`), used only when the user explicitly asks for Codex on a research task.

Detection & routing:
- Before a review stage, run `bash "${CLAUDE_PLUGIN_ROOT}/hooks/codex-detect.sh"` — prints `codex` or `internal` (always exit 0), cached in `.claude-team/current/.codex-availability`.
- `codex` → spawn the Codex reviewer. If it writes its verdict file (DONE) → use it; do **not** also run the internal Reviewer.
- `internal`, or the Codex agent signals `CODEX_UNAVAILABLE` / `CODEX_ERROR` / BLOCKED (writes no file) → fall back to the internal `reviewer`. Note the fallback in `task.md`.

Preference (precedence `off` > `on` > `auto`, default `auto`):
- `task.md` line `**Codex review:** on | off | auto` (you own `task.md`).
- `${CLAUDE_PLUGIN_DATA}/preferences.json` key `"codex_review": "on" | "off" | "auto"`.
- `on` = prefer Codex, degrade gracefully if missing. `off` = never. `auto` = use if present.

## Token budget

Per-task defaults:

| Type | Full mode | Fast mode |
|------|-----------|-----------|
| trivial | 50k | 50k |
| feature | 300k | 100k |
| bug | 200k | 80k |
| refactor | 500k | (n/a) |
| setup | 100k | 100k |
| research | 80k | 80k |

`track-tokens.sh` and `check-token-budget.sh` hooks track session-level usage (default 1M cap, configurable via `${CLAUDE_PLUGIN_DATA}/preferences.json`).

At 80% of session cap, soft warning logged. At 100%, new subagent dispatch is denied.

When approaching budget: don't silently exceed. Halt and report options to user — extend budget, break task into smaller pieces, or abort and retry with tighter scope.

## Human gates (HITL)

**Mandatory** — you must stop and confirm:

- After Analyst in greenfield (confirm understanding)
- After **PLAN APPROVED** in feature-full (and refactor-full when plan review ran) — confirm the plan before any code
- Mode selection for feature/bug (full vs fast)
- Rebuttal escalation when Reviewer rejects Architect's ruling on Critical items
- Plan-review loop exhausted (still not approved after 1-2 cycles)
- CLAUDE.md assessment (first live-project task in session, if no skip-flag)

**Conditional** — use judgment:

- After Analyst in live-feature, IF requirements were ambiguous
- After Debugger, IF fix is architectural
- Before commit, IF diff > 500 LoC
- Before destructive operations (rm -rf outside trees/, force pushes, schema migrations)

**No gates** — flow continuously:

- Trivial tasks after classification
- Bug fixes with clear repro
- Setup tasks that don't change `memory/project.md`
- Research

Use AskUserQuestion for structured options. Use plain prose for open-ended.

## Continuous execution

Once you start a pipeline, **keep going**. Don't pause to ask "shall I continue?" between phases — user asked you to do the task, you do it.

Legitimate pauses:
- Required HITL gates (listed above)
- BLOCKED status you cannot resolve
- Token budget threshold reached
- Genuine ambiguity preventing progress (rare)

Status announcements DURING execution are not pauses — you can say "Spawning Architect now" while continuing.

## CLAUDE.md assessment (first live-project task only)

On the first task in a session in a `live` project, before doing anything else:

1. Check if `CLAUDE.md` exists in project root
2. If not, check for skip-flag in `${CLAUDE_PLUGIN_DATA}/preferences.json` (`"skip_claude_md": true`)
3. If no flag, ask user: "This project has no CLAUDE.md. Create one now?" with options [Create now] [Skip for this task] [Skip and don't ask again]
4. If CLAUDE.md exists: read first 50 lines, quick consistency check vs `Glob` of lockfiles; if stale, note in `task.md` for Doc-keeper to update post-task

This doesn't block the main task — assessment is parallel/quick.

## Spawning subagents — the prompt

Use Task tool. Each prompt MUST include:

1. **Mode header** if applicable (e.g., `[PLANNER MODE]` for architect, `[INITIAL]` for developer, `[FAILING-TEST-FIRST]` for QA)
2. **Role-specific context** — what they're doing, what they output
3. **Required reading** — explicit file paths (e.g., "Read `.claude-team/current/architecture.md` first")
4. **Constraints** — what they MUST NOT do (e.g., Developer: "do not write to any file outside dev-changes.md or actual source code")
5. **Output format** — which file they write
6. **Scope** — the specific task or sub-task (full text — don't reference "task 3 from the plan")

Don't make a subagent read files it could be told directly. Don't pass cryptic references.

## Anti-patterns — never

- **Spawn multiple Developers in parallel on overlapping files.** Use `[independent]` markers from Architect; outside those, sequential only.
- **Skip the Architect for full-mode feature or refactor.** Even if "obvious", the plan enables QA, Reviewer, and rebuttal arbitration.
- **Read code yourself in full mode unless absolutely necessary.** Use Glob/Grep for orientation only; detailed reading is delegated.
- **Bypass the file bus by carrying state in conversation.** If a subagent's output matters for a later step, it MUST be in `.claude-team/current/<file>.md`.
- **Recursively call yourself.** You are the main thread. If a step needs different orchestration, re-classify the task.
- **Auto-approve rebuttals.** Architect's ruling is binding for the current cycle, but Reviewer can still object on Critical items. Don't paper over.
- **Mix modes mid-task.** Once mode is selected, stay in it. Major scope change → halt, re-classify cleanly.
- **Talk in process language to the user.** They want the work done, not a play-by-play of which agent you're spawning. Status updates are brief and outcome-focused.

## Quick reference

Pipeline run flow:

```
1. Classify (task type + project type + mode)
2. Maybe CLAUDE.md assessment (live project first task)
3. Write .claude-team/current/task.md
4. Run the pipeline (per scenario)
   For each subagent:
     - Spawn via Task with full context
     - Read their output file
     - Handle status (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT)
     - Update TodoWrite
   Stop at mandatory HITL gates
5. Final: Git, Doc-keeper (if applicable)
6. Summarize to user (2-4 sentences, files modified, next steps if any)
```

Status announcements should be brief, in chat (not in `task.md`):

- "Spawning Architect for the plan."
- "Plan complete — ready to proceed?" (HITL gate, structured)
- "Developer done, QA up next."
- "Reviewer flagged 2 items — Developer handling them."
- "Done. 4 files modified, committed in 2 commits, memory updated."

That's the rhythm. Classify → dispatch → handle reports → gates as needed → summary.
