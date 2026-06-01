# Changelog

All notable changes to `dev-team-agents` are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Planned for upcoming versions — see README "Roadmap" section.

## [1.1.0] — 2026-06-01

### Added — `/task` slash command (first command in the plugin)

- `commands/task.md` — a single entry point to start a work session without hand-writing the orchestration each time. Invoke as `/task <task list, or a URL / file path to a doc>`. The command runs in the main thread (Orchestrator) and:
  - **Resolves the input** — `WebFetch` for URLs, `Read` for local files / `@`-references, inline text used directly, mixed inputs merged. Empty input asks the user for a list or link instead of guessing; auth-walled tracker links (GitHub/Jira/Notion) fall back to asking for pasted text.
  - **Normalizes into a backlog** — distills discrete tasks into `.claude-team/current/backlog.md` (survives across pipelines) and mirrors them into `TodoWrite`.
  - **Auto-groups** — related tasks → one pipeline; independent tasks → separate pipelines run strictly sequentially (no overlapping-file pipelines at once). Only asks when a split is genuinely ambiguous.
  - **Runs each group through the standard flow** — classify (type × project) → mode select (full/fast, asking for feature/bug) → pipeline with the full file bus, 4-status protocol, rebuttal flow, per-group token budget, and all HITL gates. Defers pipeline mechanics to the operating manual / orchestrator prompt rather than restating them, to avoid drift.
  - Ends with a roll-up: shipped / skipped / blocked, files touched, flagged follow-ups.
- Removed the placeholder `commands/.gitkeep` now that the directory has real content.

### Changed

- `.claude-plugin/plugin.json` — version `1.0.0 → 1.1.0`.
- `README.md` — new "Commands" section documenting `/task` with examples; status line bumped to v1.1.0; project-layout tree now lists `commands/task.md` instead of "(empty — slash commands land later)".

### Added — Codex setup guide (doc)

- `CODEX_INTEGRATION.md` — how to connect the plugin's optional Codex agents (the two reviewers + `codex-consult`) via the Codex CLI: install/login, the `~/.codex/config.toml` model gotcha (ChatGPT-account logins need `gpt-5.5`, not `gpt-5`), and verification via `hooks/codex-detect.sh` + a `codex exec` smoke test. Documents the existing fail-closed behavior shipped in 1.0.0.

## [1.0.0] — 2026-05-31

### Added — pre-code plan-review stage

- New canonical full-feature flow: **Architect → Analyst (validate plan) → PLAN REVIEW → HITL confirm → Developer ‖ QA → CODE REVIEW**. The Analyst now has a guaranteed seat validating the plan against requirements before any code is written.
- `reviewer` gains a third mode, **`[PLAN REVIEW]`**: reads `architecture.md` + `analyst.md`, writes `review-plan-feedback.md` with markers `**PLAN APPROVED**` / `**PLAN CHANGES REQUESTED**` / `**PLAN BLOCKED**`. Every issue is tagged `owner: analyst` or `owner: architect` for routing.
- New file-bus artifact `review-plan-feedback.md` — a **separate file with separate markers** so the commit gate (which watches `**APPROVED**` in `review-feedback.md`) can never be opened by a plan verdict.
- Orchestrator: new "Plan-review routing & fix loop" (route by `owner:`, max 1–2 cycles, then HITL escalation) and a HITL gate after PLAN APPROVED. Plan review applies to feature-full (always) and refactor-full (optional); bug / setup / trivial / research / fast-mode skip it.

### Added — optional Codex reviewers (`codex exec`)

- `hooks/codex-detect.sh` — on-demand availability probe (not registered in `hooks.json`). Prints `codex` or `internal`, caches to `.claude-team/current/.codex-availability`. Override precedence `off > on > auto` via `task.md` (`**Codex review:**`) or `preferences.json` (`"codex_review"`).
- `prompts/codex-code-review.md` and `prompts/codex-plan-review.md` — adversarial review prompt templates for `codex exec` (stdin invocation, `--sandbox read-only`, JSON output contract, confidence 0–100).
- `codex-tasks/build-codex-reviewers.md` — self-contained spec to generate the two reviewer agents (`codex-code-reviewer`, `codex-doc-reviewer`) with Codex itself.
- `agents/codex-consult.md` + `prompts/codex-consult.md` — optional Codex **second opinion** for research tasks. On explicit user request ("через Codex", "ask Codex", "сравни X и Y через Codex"), runs alongside the internal Analyst → `codex-analysis.md`; the Orchestrator then synthesizes both takes (agreement vs. divergence). Second opinion, not a replacement — the Analyst always runs; request-only (plain research stays Analyst-only); fails closed to Analyst-alone when Codex is unavailable. Ownership case added to `validate-file-ownership.sh`.
- Orchestrator: "Codex reviewers (detection + routing + fallback)" — Codex reviewers write the same files in the same format as the internal Reviewer (commit gate & rebuttal flow unchanged), and **fail closed** to the internal Reviewer on any error.
- `hooks/validators/validate-file-ownership.sh` — explicit ownership cases for `codex-code-reviewer` (→ `review-feedback.md`), `codex-doc-reviewer` (→ `review-plan-feedback.md`), and `reviewer` (+ `review-plan-feedback.md`).

### Added — sequential-thinking skill

- Promoted `sequential-thinking` into `skills/` (with its `references/`) — a structured-reasoning harness around `mcp__sequential-thinking__sequentialthinking`. Wired into the `architect`, `analyst`, and `reviewer` frontmatter.

### Fixed — MCP tools unreachable from subagents

- Subagents with an explicit `tools:` allowlist could not call MCP tools that weren't listed. Added the MCP tool names to the relevant agents: `mcp__context7__resolve-library-id` + `mcp__context7__get-library-docs` for `developer` / `developer-opus` / `developer-parallel`; `mcp__sequential-thinking__sequentialthinking` for `architect` / `analyst` / `reviewer`. Added usage notes in each agent body.

### Changed

- `.claude-plugin/plugin.json`: version `0.9.0 → 1.0.0`; description now mentions the 3 optional Codex agents (2 reviewers + codex-consult), plan-review stage, and 16 skills; added `plan-review` and `codex` keywords.
- README and the `using-dev-team-agents` operating manual updated: new plan-review flow, `review-plan-feedback.md`, Codex detection/routing/fallback + on/off/auto flag, MCP allowlist note, skill count 15 → 16.

## [0.9.0] — 2026-05-09

### Added — bootstrap skill (operating manual auto-injected)

- `skills/using-dev-team-agents/SKILL.md` — operating manual for the main thread:
  - "The single most important rule": classify task BEFORE acting
  - Task type table (6 types) + project type table (3) + mode table
  - Full pipeline workflows for all 8 scenarios (greenfield, live feature full/fast, live bug full/fast, refactor, trivial, setup, research)
  - File bus ownership table (all 12 agents)
  - 4-status report protocol handling (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT)
  - Rebuttal flow with Architect arbiter, max 1 cycle without rebuttal
  - Token budget defaults per type × mode
  - HITL gate categories (mandatory / conditional / no gates)
  - Continuous execution principle — never auto-pause between phases
  - CLAUDE.md assessment protocol (live project, first task in session)
  - Subagent spawn requirements (mode header, full context, file paths explicit)
  - Anti-patterns: parallel devs on overlapping files, skip Architect, bypass file bus, recursive self-call, auto-approve rebuttals, mix modes mid-task
  - Quick reference flow at the end
  - This skill is DIFFERENT from methodology skills (Round 1-3) — it's the session-start injection, not preloaded into agent frontmatter

### Changed

- `hooks/session-start.sh` — significant rewrite:
  - Reads `skills/using-dev-team-agents/SKILL.md`, parses out frontmatter (awk `c>=2` after second `---`)
  - Injects the full skill body as `additionalContext` so the main thread has the operating manual present from session start
  - Appends compact Plugin status footer (version, init status, activation hint)
  - Fallback: if SKILL.md is missing, emits a minimal status with WARNING noting the missing operating manual
- `.claude-plugin/plugin.json` — version bump 0.8.2 → 0.9.0

### Notes

- **Functional smoke-tested**: SessionStart hook on fresh project emits valid JSON containing the full skill body (13.3K chars) + status footer. Auto-init of `.claude-team/` also fires when missing.
- Total skills: 15 of 15. All methodology skills (14) plus the bootstrap skill (this one). Methodology skills are wired into agent frontmatter; bootstrap skill is injected by SessionStart.
- The bootstrap skill duplicates some content from agent system prompts (notably from `orchestrator.md`). This duplication is intentional during this phase — the skill is for the main thread which IS the Orchestrator; consolidation can come later if we find the duplication causes drift.
- Next major version: v1.0.0 after real-world testing on actual projects.

## [0.8.2] — 2026-05-09

### Added — final skills round + wire-up

**Round 3 skills (6 new):**

- `skills/debugging-by-bisection/SKILL.md` (149 lines) — halve the search space:
  - `git bisect` workflow for regressions (manual + automated `git bisect run`)
  - Logical bisection for "where in the code" (comment-out half, feature flag, input bisection)
  - Bisection on flaky tests (suite subset bisection)
  - Time/step table (log₂ N candidates) — when bisection pays off vs when reading is faster
  - Pre-flight requirements: deterministic repro, fast repro, buildable commits

- `skills/root-cause-tracing/SKILL.md` (226 lines) — trace backward to original trigger:
  - 6-step process: observe → immediate cause → trace up → keep tracing → identify WHY → fix at source
  - Bonus: defense-in-depth at intermediate layers (not a substitute for root fix)
  - Stopping criteria: external boundary, contract violation, race condition, logic error
  - Worked examples: silent default (empty projectDir), race condition (duplicate users)
  - Adapted from `Hacker0x01/claude-power-user`

- `skills/code-review-checklist/SKILL.md` (136 lines) — Reviewer's category framework:
  - 3 categories: Correctness, Security, Code quality
  - Explicit list of what's NOT on the list (style preferences, "I would have done differently", etc.)
  - Pairs with confidence rubric (≥80 from system prompt) — drop sub-80 items silently
  - Critical vs Important distinction with high bar for Critical
  - Pre-existing concerns handling

- `skills/writing-good-commits/SKILL.md` (232 lines) — conventional + atomic:
  - Full type/scope/subject discipline (feat/fix/refactor/docs/test/chore/style/perf)
  - Atomicity heuristic: would `git revert` make sense for this commit alone?
  - Staging discipline: never `git add .`, always explicit
  - When to add a body (subtlety, trade-off, issue ref) vs skip (obvious subject)
  - Worked example: rate limiting feature → 2 atomic commits (chore + feat)
  - Forbidden operations list (no push, no amend, no rebase in automation)

- `skills/refactoring-without-breaking/SKILL.md` (200 lines) — restructure without changing behavior:
  - 4 prerequisites: characterization tests, explicit scope (Out of Scope + Behavior Preserved), small steps, revertable at every commit
  - Common refactor patterns with traps: rename, extract function, inline, move file, replace library
  - Step-size table: rename (1 symbol), extract (1 extraction), move (1 file), restructure (smallest cleavage)
  - When tests are missing: write characterization first OR pair with manual verification OR don't refactor
  - Anti-patterns: refactor while adding feature, big-bang, "while I'm here" cleanup, drop characterization tests

- `skills/condition-based-waiting/SKILL.md` (234 lines) — wait for condition, not duration:
  - Polling with `waitFor` (interval + timeout) vs hardcoded sleep
  - Exponential backoff for slow/uncertain durations
  - Event-driven preferred when available (await Task tool, AskUserQuestion)
  - Reasonable timeouts table by wait type
  - Precise "ready" definitions (file exists AND Status: DONE, not just file exists)
  - Adapted from `Hacker0x47/claude-power-user`

**Skills wired into agent frontmatter (9 of 12 agents have skills):**

| Agent | Preloaded skills |
|-------|------------------|
| orchestrator | condition-based-waiting |
| analyst | brainstorming, asking-clarifying-questions, reading-existing-codebase |
| architect | reading-existing-codebase, writing-plans, refactoring-without-breaking |
| debugger | debugging-by-bisection, root-cause-tracing, failing-test-first |
| reviewer | code-review-checklist, testing-anti-patterns |
| developer | tdd-workflow, verification-before-completion, writing-good-commits |
| developer-parallel | tdd-workflow, verification-before-completion |
| qa | tdd-workflow, failing-test-first, testing-anti-patterns, verification-before-completion |
| git | writing-good-commits |
| devops, doc-keeper, meta-agent | — (no skills assigned by design) |

### Changed

- `.claude-plugin/plugin.json` — version bump 0.8.1 → 0.8.2
- `hooks/session-start.sh` — bootstrap message lists all 14 skills grouped by round
- 9 agent frontmatters — added `skills: [...]` field

### Notes

- 14 of 15 skills now exist. Final skill (`using-dev-team-agents` bootstrap) lands in v0.9.0 — it's the session-start operating-manual injection, a different kind from these 14 methodology skills.
- Skills are wired but agents' system prompts still contain the methodology inlined (legacy from v0.2.0–v0.5.0). Future cleanup: trim redundant inline content from system prompts now that skills cover it. Deferred to avoid breaking the agents during this transition.
- Total skill content (all rounds): 2,612 lines across 14 files.

## [0.8.1] — 2026-05-09

### Added — thinking-tier skills (Round 2 of 3, 4 of 15 cumulative new)

- `skills/brainstorming/SKILL.md` (147 lines) — generate 2-3 directions before locking one:
  - For greenfield + feature-full pipelines, BEFORE clarification
  - Two-is-floor, three-is-ceiling rule (not 4+, not 1)
  - Axes-of-variation table (scope, architecture, tech, sync/async, UX shape, build/reuse)
  - Concrete worked example (stock-out notifications: polling vs webhook vs dashboard)
  - Anti-patterns: fake variants (knob-tweaking), implementation details as direction, picking for user, no trade-offs

- `skills/asking-clarifying-questions/SKILL.md` (184 lines) — efficient user dialog:
  - Two categories: "USER OWNS THIS" (must ask) vs "YOU CAN RESOLVE" (don't ask — read instead)
  - Pacing: ≤3 questions per round, rounds budget capped at 3
  - Gate function before each question: "Can I answer this myself in 30 seconds?"
  - Restating step — final validation before locking
  - Anti-patterns: barrage, asking what's in lockfile, vague questions, implementation questions

- `skills/reading-existing-codebase/SKILL.md` (161 lines) — narrow before opening:
  - Order: memory files → Glob → Grep → Read (only relevant files, with line ranges)
  - Time-box: 5 min trivial / 10-15 typical / 20-30 complex / STOP if "lost"
  - "Similar features" pattern workflow
  - Anti-patterns: open random files, read whole large files, endless cross-reference chasing, skip git blame for weird code

- `skills/writing-plans/SKILL.md` (264 lines) — Architect's PLANNER-mode output:
  - Mandatory sections: Goal (one verifiable sentence), Architecture Decision (2-3 sentences, single approach), **Out of Scope** (critical — biggest plan failure mode is scope creep), File Structure, Tasks, Definition of Done
  - Bite-sized tasks: 2-5 min Developer work each
  - `[independent]` / `[sequential, depends on: N]` markers with strict criteria for parallelism
  - Greenfield specifics (`## Project Structure` first) and refactor specifics (`## Behavior Preserved`)
  - Anti-patterns: walls of text, vague tasks, no file list, multi-perspective output, vibes-y Definition of Done

### Changed

- `.claude-plugin/plugin.json` — version bump 0.8.0 → 0.8.1
- `hooks/session-start.sh` — bootstrap message lists Round 1 + Round 2 skills

### Notes

- 8 of 15 skills now exist. Round 3 (debugging-by-bisection, root-cause-tracing, code-review-checklist, writing-good-commits, refactoring-without-breaking, condition-based-waiting) lands in v0.8.2 along with `skills:` field wire-up in agent frontmatter.
- Round 2 skills target thinking-tier agents (analyst, architect). They formalize the methodology already inlined in those agents' system prompts — preload via `skills:` field will reduce duplication once wired.
- Total skill content (rounds 1-2): 1,435 lines across 8 files.

## [0.8.0] — 2026-05-09

### Added — TDD-related skills (4 of planned 15)

This is the first of three planned skill rounds. Round 1 covers TDD and verification — the highest-value skills for code quality. Rounds 2 and 3 (thinking-tier and miscellaneous skills) will land in v0.8.1 and v0.8.2.

- `skills/tdd-workflow/SKILL.md` (135 lines) — Red → Green → Refactor cycle:
  - When TDD applies vs when it doesn't (greenfield → honest TDD, existing-with-tests → match style, existing-without-tests → don't impose)
  - Bite-sized steps: 2–5 minutes per cycle
  - "Test what behavior, not what code" — tests should survive refactors
  - Project-context-driven adaptation table (greenfield / existing-with-tests / existing-without-tests / refactor)
  - Anti-patterns: peeking ahead, batched tests-then-batched-code, skipping Refactor

- `skills/failing-test-first/SKILL.md` (145 lines) — regression test before bug fix:
  - **Non-negotiable for bug pipelines** — no exceptions for "small" bugs
  - 7-step process: read bug → find/create test file → write reproducing test → confirm it fails → fix → confirm it passes → run suite → commit
  - Guidance for hard-to-test bugs (environment-specific, timing, external services, UI)
  - Anti-patterns: test-after-fix, mock-the-buggy-function, integration test where bug is buried

- `skills/testing-anti-patterns/SKILL.md` (232 lines) — common test-quality mistakes:
  - **Iron Laws**: never test mock behavior, never add test-only production methods, never mock without understanding the dependency
  - Coverage: mock-behavior testing, test-only methods, blind mocking, order-dependent tests, fragile snapshots, too-many-layers, excessive setup
  - Gate functions to apply before writing each test
  - Adapted from `Hacker0x01/claude-power-user` skill of the same name

- `skills/verification-before-completion/SKILL.md` (167 lines) — verify before claiming DONE:
  - "The word DONE is a contract"
  - 7-step verification checklist: tests, lint, types, build, file contents, git status, manual behavior verification
  - What to do when verification fails (related-to-change vs unrelated)
  - Anti-patterns: claiming DONE from diff inspection alone, running tests "in your head", "I believe it works" hedging

### Changed

- `.claude-plugin/plugin.json` — version bump 0.7.0 → 0.8.0
- `hooks/session-start.sh` — bootstrap message now lists available skills

### Notes

- Skills are not yet preloaded into agents' system prompts — that requires adding `skills:` field to each agent's frontmatter (or relying on description-based discovery). To be wired up in v0.8.2 alongside completion of the skill set.
- Each skill is self-contained in its own directory; the SKILL.md file is the entry point. Future versions may add `references/` subdirectories for deep-dive material.
- Total skill content (round 1): 679 lines across 4 files.

## [0.7.0] — 2026-05-09

### Added — file ownership enforcement

- `hooks/track-active-agent.sh` — SubagentStart hook with matcher `*`:
  - Records currently active agent name to `${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/active-agent.txt`
  - Tries multiple stdin field names (`agent_type`, `agent_name`, `subagent_type`, `subagent_name`) to handle platform variation
  - Strips plugin prefix (e.g. `dev-team-agents:developer` → `developer`)
  - Observational only — never blocks subagent dispatch (exit 0 always)

- `hooks/check-file-ownership.sh` — PreToolUse hook with matcher `Write|Edit|MultiEdit` and `if: Write(.claude-team/**) || Edit(.claude-team/**) || MultiEdit(.claude-team/**)`:
  - Extracts `file_path` from tool_input (works for Write, Edit, MultiEdit)
  - Reads active agent name from `active-agent.txt` (defaults to `orchestrator` if absent)
  - Calls `validate-file-ownership.sh` with agent name and file path
  - Denies with explicit reason citing the ownership table

- `hooks/validators/validate-file-ownership.sh` — central ownership table:
  - Per-agent allow-list of `.claude-team/` paths (regex patterns)
  - Paths outside `.claude-team/` always allowed (project source code is not pipeline-coordinated)
  - Unknown agents: permissive default (better than blocking legitimate ops on missing state)
  - Coverage:
    - `analyst` → `current/analyst.md`
    - `architect` → `current/architecture.md`, `current/architect-ruling.md`
    - `debugger` → `current/debug-report.md`
    - `reviewer` → `current/review-feedback.md`
    - `developer` → `current/dev-changes.md`, `current/review-rebuttal.md`
    - `developer-parallel` → `current/dev-changes-task-<id>.md`
    - `qa` → `current/qa-report.md`
    - `devops` → `current/dev-changes.md`, `current/setup-changes.md`, `memory/project.md`
    - `git` → `current/dev-changes.md` (commits section)
    - `doc-keeper` → `memory/*.md`, `current/dev-changes.md`
    - `orchestrator` (main thread) → `current/task.md`, memory/* (fast mode fallback), `.runtime/*`

### Changed

- `hooks/hooks.json` — expanded from 5 to 7 hook configurations:
  - SubagentStart matcher=`*` now has both `track-active-agent.sh` and `check-token-budget.sh`
  - PreToolUse adds matcher=`Write|Edit|MultiEdit` with `.claude-team/` if-guard
- `hooks/session-start.sh` — bootstrap message reflects the two new hooks
- `.claude-plugin/plugin.json` — version bump 0.6.0 → 0.7.0
- `README.md` — Status block, Roadmap, hooks layout updated

### Notes

- **Functional smoke-tested**: 8 scenarios — developer writing dev-changes.md (allowed), developer writing architecture.md (denied with reason), developer writing source code (allowed — outside `.claude-team/`), analyst writing analyst.md (allowed), analyst writing dev-changes.md (denied), doc-keeper writing memory/project.md (allowed), developer-parallel writing dev-changes-task-3.md (allowed), active-agent tracking switches correctly. All as expected.
- Race conditions in parallel-Developer scenarios: documented in `track-active-agent.sh` comments. `isolation: worktree` provides physical file isolation; `active-agent.txt` race only affects ownership checks on shared `.claude-team/current/`, where parallel devs use per-task filenames anyway.
- Permissive on unknown agents: hooks default to allow when active-agent.txt is missing or agent name is unrecognized. Trade-off: occasional missed violation vs. occasional broken legitimate operation. Choosing the latter direction since users will see broken ops loudly while missed violations only appear in code review.

## [0.6.0] — 2026-05-09

### Added — enforcement hooks (5 of intended ~6)

- `hooks/check-architecture-ready.sh` — SubagentStart hook for `developer` and `developer-parallel` agents:
  - Runs `validators/validate-architecture-format.sh` against `.claude-team/current/architecture.md`
  - Validator checks: file exists, not empty (>200 bytes), contains required sections (`# title`, `## File Structure`, `## Tasks`, `**Goal:**`, `**Architecture Decision:**`)
  - Denies subagent dispatch if validation fails — surfaces a specific reason for the block
  - Catches "Architect skipped or unfinished" Orchestrator routing bugs

- `hooks/check-review-passed.sh` — PreToolUse hook with matcher `Bash` and `if: Bash(git commit*)`:
  - Skips check if `.claude-team/` doesn't exist (allows commits in non-dev-team-agents projects)
  - Blocks if `task.md` exists but `review-feedback.md` is missing — pipeline incomplete
  - Validates `review-feedback.md` shows APPROVED status (handles rebuttal flow: rebuttal must have a corresponding architect-ruling.md, then Reviewer's FINAL REVIEW must show APPROVED)
  - Bypasses provided for genuine non-pipeline commits (no active task)

- `hooks/check-token-budget.sh` — SubagentStart hook with matcher `*`:
  - Reads `${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/tool-calls.log` to compute approximate session token usage
  - Default budget: 1,000,000 tokens per session; overridable via `${CLAUDE_PLUGIN_DATA}/preferences.json` `max_session_tokens` field
  - Soft warning at 80% threshold (logged to `budget-warnings.log` for Orchestrator to pick up)
  - Hard deny at 100% — Orchestrator must halt and report to user

- `hooks/track-tokens.sh` — PostToolUse hook with matcher `*` and `async: true`:
  - Lightweight observational hook — never blocks tool execution
  - Appends one line per tool call to `${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/tool-calls.log`
  - Format: `<iso8601_timestamp> <tool_name> <input_chars> <approx_tokens>`
  - Defensive — if anything fails, silently exits 0

- `hooks/validators/validate-claude-team-structure.sh` — verifies `.claude-team/` has memory/ + current/ subdirs and 6 required memory files

- `hooks/validators/validate-architecture-format.sh` — verifies `architecture.md` is non-empty, has required sections, isn't suspiciously tiny

- `hooks/validators/validate-review-passed.sh` — verifies `review-feedback.md` shows APPROVED status, handles rebuttal flow logic

### Changed

- `hooks/hooks.json` — expanded from 1 hook (SessionStart) to 5 hook configurations (SessionStart + 2 SubagentStart matchers + 1 PreToolUse + 1 PostToolUse)
- `hooks/session-start.sh` — now auto-initializes `.claude-team/` via `init-claude-team.sh` if missing (was previously discipline-only via Orchestrator); bootstrap message lists active enforcement hooks
- `.claude-plugin/plugin.json` — version bump 0.5.0 → 0.6.0
- `README.md` — Status block reflects active enforcement; Roadmap reordered (file ownership moved to v0.7.0, skills to v0.8.0, bootstrap skill to v0.9.0)

### Notes

- **Functional smoke-tested**: all 5 hooks tested on a temp project — SessionStart auto-init, architecture-ready deny+allow, review-passed deny+allow, token tracker logging, budget gate allow at low usage. All correct.
- **File ownership enforcement deferred to v0.7.0** — requires runtime active-agent tracking (a separate mechanism, since PreToolUse stdin doesn't reliably include the calling agent name).
- Hooks are pragmatic rather than exhaustive — soft warnings logged for Orchestrator pickup, hard denies only for clear violations.

## [0.5.0] — 2026-05-09

### Added — agent roster complete (12 of 12)

- `agents/git.md` — atomic conventional-commit specialist (204 lines, Haiku):
  - Reads `dev-changes.md` (or parallel `dev-changes-task-N.md`), groups changes into logical atomic commits
  - Conventional commit format with full type/scope/subject discipline (feat / fix / refactor / docs / test / chore / style / perf)
  - **Stages explicitly** — never `git add .`; uses `git add <file>` or `git add -p` for hunk staging
  - **Confirms review approval** before committing — if Reviewer's status isn't APPROVED, BLOCKED
  - Bans destructive operations: no push, no amend, no rebase, no force-push
  - Reports per-commit detail (message, files, SHA) appended to `dev-changes.md`

- `agents/doc-keeper.md` — memory and documentation maintainer (247 lines, Haiku):
  - Maintains `.claude-team/memory/*` files (project, decisions, patterns, gotchas, session-log, index) and user-facing docs (README, CHANGELOG, CLAUDE.md)
  - **Selective updates**: each file has clear "when to update" triggers — not every change touches every file
  - **Append-only for memory**: never rewrites; if something's stale, flags via DONE_WITH_CONCERNS rather than silent delete
  - Distinguishes user-facing changes (CHANGELOG, README) from internal changes (memory/, internal-only architecture)
  - Size discipline: project.md under 200 lines, session-log archives at ~50 entries
  - Pattern-recording rule: only adds to patterns.md if pattern applied 2+ times (not after first occurrence — that's still ad-hoc)

- `agents/meta-agent.md` — optional utility for generating custom agent files (244 lines, Opus):
  - **NOT part of standard pipelines** — runs only when user explicitly asks for a new role
  - 9-step workflow: get docs → analyze input → pick name → choose model/tools → write system prompt → apply style guide → validate → write file → report
  - Adapted from disler/claude-code-hooks-multi-agent-observability `meta-agent` pattern
  - Color/model/tool guidance baked in (cyan for dialog, green for architecture, red for review, etc.)
  - Refuses `Task` tool grants (subagents can't spawn subagents — platform constraint)
  - YAML validation step prevents broken frontmatter (especially around unquoted colons)
  - Mandates anti-patterns section in every generated agent — consistency feature

### Changed

- `.claude-plugin/plugin.json` — version bump 0.4.0 → 0.5.0
- `hooks/session-start.sh` — bootstrap message lists all 12 agents grouped by tier; mentions remaining gaps (skills, hooks, bootstrap skill) for v0.6.0+
- `README.md` — Roadmap, status block, and directory layout updated; status block restructured to show what works at v0.5.0 vs what remains for v1.0

### Notes

- All 10 core agents + meta-agent are implemented. Pipelines run end-to-end through commit and documentation.
- Skills, enforcement hooks, and the bootstrap skill remain. Agents currently rely on their inlined system prompts for everything; this works but is harder to maintain than skills will be (v0.6.0+).
- Total agent prompt code: 3,388 lines across 12 files.

## [0.4.0] — 2026-05-09

### Added — executor-tier agents complete (4 of 4)

- `agents/developer.md` — implementation specialist (281 lines):
  - Three operational modes: INITIAL (first pass on a plan), FIX-AFTER-REVIEW (apply review feedback or write rebuttal), FIX-AFTER-RULING (apply Architect's binding ruling)
  - TDD strategy adapts to project context (greenfield → honest TDD, existing-with-tests → match style, existing-without-tests → don't impose, refactor → keep characterization tests green)
  - Self-review (verification-before-completion) before reporting DONE: actually runs tests, lint, type checks
  - **Rebuttal protocol**: writes `review-rebuttal.md` only with concrete reasoning (not preference); accepts Architect ruling as binding but can note lingering concerns in `## Notes`
  - File ownership strictly enforced: writes only `dev-changes.md`, `review-rebuttal.md`, and source code; cannot touch other agents' files
  - 4-status report protocol with strict bar — "DONE without verifying tests pass is worse than BLOCKED with reason"

- `agents/developer-parallel.md` — worktree-isolated parallel variant (181 lines):
  - Frontmatter `isolation: worktree` triggers platform-managed git worktree per instance
  - Handles ONLY initial implementation of one `[independent]` task — fix cycles after merge go to regular `developer`
  - Step-1 independence check: verifies its assigned files don't overlap with other `[independent]` tasks (catches Architect's parallelism errors)
  - Per-task report file: `dev-changes-task-<N>.md` (not plain `dev-changes.md`)
  - Doesn't manage worktree itself, doesn't coordinate with siblings, doesn't push

- `agents/qa.md` — test specialist (241 lines):
  - Four operational modes: FAILING-TEST-FIRST (bugs, before fix), CHARACTERIZATION (refactors, captures current behavior), ACCEPTANCE (features, verifies spec compliance), REGRESSION (after fix/refactor)
  - **Distinguishes its tests from Developer's TDD unit tests** — covers spec / integration / edge cases / negative tests, not redundant unit coverage
  - **Spec compliance check** in ACCEPTANCE mode: confirms Developer's "DONE" matches `analyst.md` Acceptance criteria; flags gaps as Critical findings
  - Always writes failing test BEFORE Developer fixes a bug — non-negotiable, no exceptions for "small" bugs
  - Output coverage tables: criteria → test file:line → status
  - Anti-patterns: testing mock behavior, test-only production methods, padding with low-value tautological tests

- `agents/devops.md` — environment and tooling specialist (246 lines):
  - Four operational modes: SETUP-TASK (solo), GREENFIELD-SCAFFOLD (after Architect, before Developer), UNBLOCK-DEPENDENCY (when other agents BLOCK on missing tools), INIT-CLAUDE-TEAM (creates `.claude-team/` structure)
  - Stack detection from lockfiles before any change
  - Greenfield scaffold produces "builds and tests vacuously" project — no application code, no tests, just infrastructure
  - CI guidelines: one job per concern, cache deps, pin versions, match local commands, no secrets in code
  - Runs `init-claude-team.sh` (idempotent) when needed
  - Discipline against scope creep: "if user asked for ESLint, don't also add Prettier, Husky, lint-staged"

### Changed

- `.claude-plugin/plugin.json` — version bump 0.3.0 → 0.4.0
- `hooks/session-start.sh` — bootstrap message lists all 9 implemented agents grouped by tier
- `README.md` — Roadmap, status block, and directory layout updated

### Notes

- Pipelines now run end-to-end implementation: Analyst → Architect → Developer → QA → Reviewer (with rebuttal flow if needed). They halt at git commit / doc-keeper update — those agents are the final piece (v0.5.0).
- Total agent prompt code: 2,693 lines across 9 files.

## [0.3.0] — 2026-05-09

### Added — thinking-tier agents complete (4 of 4)

- `agents/architect.md` — software architect (352 lines), two operational modes:
  - **PLANNER mode** (Orchestrator passes `[PLANNER MODE]` in prompt): reads `analyst.md` + relevant code, performs internal 2–3 approach debate, picks one, writes `architecture.md` with bite-sized tasks, file mapping, `[independent]`/`[sequential, depends on: ...]` markers, Out of Scope section, Definition of Done
  - **ARBITER mode** (Orchestrator passes `[ARBITER MODE]` in prompt): reads `architecture.md` + `dev-changes.md` + `review-feedback.md` + `review-rebuttal.md`, rules per disputed item (UPHOLD REVIEWER / UPHOLD DEVELOPER / PARTIAL), writes `architect-ruling.md`
  - Includes greenfield-specific guidance and refactor-specific guidance
  - Internal debate principle: never present multiple options to user; pick one with reasoning
  - 4-status report protocol

- `agents/debugger.md` — read-only bug investigation specialist (330 lines):
  - Six-step tracing process: observe → reproduce → immediate cause → trace backward → identify why → plan fix
  - **Read-only by discipline**: only writes `debug-report.md`, never modifies production code
  - Output template adapted from disler `scout-report-suggest`: Problem Statement, Reproduction (honest about success/failure), Search Scope, Findings with `file:line` references, Detailed Analysis with call chain trace, Suggested Resolution, Priority (Critical/High/Medium/Low with justification)
  - Time-boxed investigation (~30 min typical, ~60 min complex)
  - "Trace backward to root cause, don't stop at symptom" — emphasized throughout
  - 4-status report protocol with specific BLOCKED / DONE_WITH_CONCERNS scenarios

- `agents/reviewer.md` — code reviewer with confidence-based filtering (325 lines):
  - **Confidence rubric 0/25/50/75/100**: only issues with score ≥ 80 reported (паттерн from Anthropic feature-dev)
  - Two operational modes: INITIAL REVIEW (first pass) and FINAL REVIEW (after Architect's ruling)
  - Three review categories: project guidelines compliance, real bugs, significant quality issues
  - Output groups findings as Critical (must fix) and Important (should fix), plus "What's good" affirmation, plus "Pre-existing concerns" informational section
  - **Escalation protocol**: when Reviewer fundamentally disagrees with Architect's ruling on a Critical-category item, can escalate via DONE_WITH_CONCERNS — high bar, only for genuine ≥80-confidence disagreement on Critical, not stylistic
  - "Signal, not coverage" — refuses to pad reports with low-confidence nitpicks; clean diff → APPROVED with one line
  - 4-status report protocol

- `agents/analyst.md` — requirements analyst and user-facing dialogue agent (344 lines):
  - **Four operational modes** by `task.md` classification: GREENFIELD, LIVE FEATURE, DOCS-ONLY, RESEARCH
  - **Brainstorming phase** (greenfield + feature-full only): generate 2–3 genuinely different approaches, present trade-offs to user via AskUserQuestion, lock direction before specifics
  - **Clarification phase**: asks ≤3 questions per round (no barrage), distinguishes "user owns this" from "I can resolve via memory/code" — reads memory files first to avoid redundant questions
  - **Restating step**: validates understanding back to user before locking the doc
  - **Docs-only specialty**: parses provided documentation, surfaces contradictions and gaps, proposes resolutions for user confirmation
  - **Research mode**: produces findings document for user (not a spec for Architect); structured as Direct answer → Supporting evidence → Caveats
  - Output `analyst.md` template covers: Goal, chosen Approach (when brainstormed), Scope in/out, Acceptance criteria, Constraints, Edge cases, Open questions
  - Anti-patterns: implementation-detail questions (Architect's job), pile-up questioning, vague requirements ("should be fast"), silent contradiction resolution

### Changed

- `.claude-plugin/plugin.json` — version bump 0.2.0 → 0.3.0
- `hooks/session-start.sh` — bootstrap message updated to reflect thinking-tier completion
- `README.md` — Roadmap, status block, and directory layout updated

### Notes

- Thinking-tier (Opus) is now complete: Orchestrator + 4 specialists.
- Workflow can route through any pipeline (greenfield, live-feature full/fast, live-bug full/fast, refactor, research) up to the point where Developer/QA/Git/Doc-keeper are needed — those are still missing and pipelines will halt with "agent not found" at the executor stage. Expected for v0.3.0.
- Total agent prompt code: 1,744 lines across 5 files.

## [0.2.0] — 2026-05-09

### Added

- `agents/orchestrator.md` — main coordination agent (393 lines)
  - 7-phase operational workflow: classification → mode selection → execution → reading reports → rebuttal protocol → token budget → HITL gates
  - Task classifier covers 6 types (trivial, feature, bug, refactor, setup, research) and 3 project types (greenfield, docs-only, live)
  - CLAUDE.md assessment for live projects on first task in session
  - Mode selection (full/fast) — user choice for feature/bug, defaults for the rest
  - File-based bus coordination through `.claude-team/current/*.md`
  - 4-status report protocol handling (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT)
  - Rebuttal protocol with Architect-as-arbiter
  - Token budget tracking with per-mode limits
  - Anti-patterns section listing common mistakes to avoid

### Changed

- `hooks/session-start.sh` — bootstrap message now reflects Orchestrator availability
- `README.md` — status block, roadmap, directory layout updated

### Notes

- Orchestrator routes correctly but **specialist subagents do not exist yet** (Architect, Developer, QA, Reviewer, Debugger, DevOps, Git, Doc-keeper, Analyst). When the Orchestrator tries to spawn them via the Task tool, you'll see "agent not found" and the workflow halts. This is expected for v0.2.0.

## [0.1.0] — 2026-05-09

### Added

- Initial plugin skeleton with directory structure per `ARCHITECTURE-v2.1.md`
- `.claude-plugin/plugin.json` manifest
- `.claude-plugin/marketplace.json` for local development testing
- Empty `.mcp.json` (MCP servers will be added in later versions)
- `hooks/hooks.json` with minimal SessionStart hook
- `hooks/run-hook.cmd` cross-platform polyglot wrapper (Windows CMD + Unix bash)
- `hooks/session-start.sh` bootstrap stub that announces plugin load
- `hooks/utils/log_helpers.sh` with `ensure_session_log_dir`, `append_jsonl`, `extract_json_field`
- `scripts/init-claude-team.sh` to create `.claude-team/` structure in user projects
- `README.md`, `INSTALL.md`, `CHANGELOG.md`, `LICENSE`

### Notes

- This is a **scaffold-only release**. No agents, skills, or commands are implemented.
- Plugin can be loaded with `claude --plugin-dir .` and produces a "plugin loaded" message at session start.
- All other intended functionality (Orchestrator, file-based bus, hooks for enforcement, etc.) is documented in `ARCHITECTURE-v2.1.md` but not yet implemented.

[Unreleased]: https://github.com/TBD/dev-team-agents/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/TBD/dev-team-agents/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/TBD/dev-team-agents/compare/v0.9.0...v1.0.0
[0.9.0]: https://github.com/TBD/dev-team-agents/compare/v0.8.2...v0.9.0
[0.8.2]: https://github.com/TBD/dev-team-agents/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/TBD/dev-team-agents/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/TBD/dev-team-agents/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/TBD/dev-team-agents/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/TBD/dev-team-agents/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/TBD/dev-team-agents/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/TBD/dev-team-agents/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/TBD/dev-team-agents/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/TBD/dev-team-agents/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/TBD/dev-team-agents/releases/tag/v0.1.0
