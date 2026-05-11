# dev-team-agents

A Claude Code plugin that turns a single session into a coordinated dev team. The main thread becomes an **Orchestrator** that classifies each task, picks a pipeline, and dispatches specialists — Analyst, Architect, Developer (Sonnet or Opus tier), QA, Reviewer, Debugger, DevOps, Git, Doc-keeper. Agents communicate through a file bus under `.claude-team/`, not through inline chat — their contexts stay clean and the whole pipeline is auditable.

> **Status: v0.9.0 — feature-complete, pre-1.0.** All agents, hooks, and skills are implemented and smoke-tested. v1.0.0 lands after real-world use on a handful of projects.

## Why

Single-agent Claude Code sessions blur roles: the same context drafts requirements, writes code, reviews itself, and commits. That's fast but error-prone, especially for non-trivial work — review quality collapses when the reviewer is the same context that just wrote the code.

This plugin separates those concerns into specialist subagents and enforces the handoffs with hooks. Each agent has a narrow charter, a defined output file, and a model tier that fits its job. You can still ship trivial changes in seconds — the Orchestrator picks the lightest path that fits the task.

## Quick install

```bash
git clone https://github.com/RomanPluzhnikov/dev-team-agents.git
cd dev-team-agents
claude --plugin-dir .
```

On session start you'll see the operating manual injected and `.claude-team/` initialized in your project. To make the main thread run as Orchestrator automatically:

```jsonc
// .claude/settings.json (in your project)
{
  "model": "opus",
  "agent": "dev-team-agents:orchestrator"
}
```

Then plain `claude` boots straight into the workflow. Give it a task in normal English ("add a `/health` endpoint", "fix the auth redirect bug", "refactor the upload module"); it classifies, picks a pipeline, and dispatches.

See [`INSTALL.md`](INSTALL.md) for marketplace install, model config, token budget tuning, and troubleshooting.

## Agent roster

| Tier | Agent | Role |
|---|---|---|
| Opus | **orchestrator** | Main thread. Classifies tasks, picks mode, dispatches, handles rebuttals. |
| Opus | **analyst** | Requirements clarification + brainstorming. Writes `analyst.md`. |
| Opus | **architect** | Implementation plan + arbiter for review disputes. Writes `architecture.md` / `architect-ruling.md`. |
| Opus | **debugger** | Read-only root-cause investigation. Writes `debug-report.md`. |
| Opus | **reviewer** | Confidence-filtered code review. Writes `review-feedback.md`. |
| Opus | **developer-opus** | Implementation for hard tasks (concurrency, dense types, cross-cutting refactors, algorithmic work). |
| Opus | **meta-agent** | Optional. Generates new agent files for project-specific roles. |
| Sonnet | **developer** | Default implementation specialist. Reads the plan, writes the code, runs the tests. |
| Sonnet | **developer-parallel** | Worktree-isolated parallel dev for `[independent]` tasks. |
| Sonnet | **qa** | Tests. Failing-test-first for bugs, characterization tests for refactors. Writes `qa-report.md`. |
| Sonnet | **devops** | Environment, dependencies, CI, scaffolding. |
| Haiku | **git** | Atomic conventional commits. |
| Haiku | **doc-keeper** | Memory + docs maintenance (`.claude-team/memory/*`, `CLAUDE.md`, `CHANGELOG.md`). |

The Orchestrator picks `developer` (Sonnet) by default and bumps to `developer-opus` (Opus) only when the Architect flags a task as high-complexity or a prior Sonnet run blocked on a reasoning problem.

## Pipeline at a glance

Each task gets classified as one of: **trivial / feature / bug / refactor / setup / research**, against project type (**greenfield / docs-only / live**), with mode **full** or **fast**. The Orchestrator picks defaults — only `feature` and `bug` ask the user which mode. Example flows:

```
Live feature, full mode:
  Analyst → Architect → [HITL: confirm plan] → Developer ‖ QA → Reviewer → (rebuttal?) → Git → Doc-keeper

Live bug, full mode:
  Debugger → QA (failing test) → Developer → QA (regression) → Reviewer → Git → Doc-keeper

Trivial:
  Orchestrator writes the change directly → Git
```

Every subagent ends with one of four statuses: `DONE` / `DONE_WITH_CONCERNS` / `BLOCKED` / `NEEDS_CONTEXT`. The Orchestrator routes accordingly — context problems get more info, reasoning problems bump tier where one exists, plan problems escalate to user.

Reviewer disagreements trigger a rebuttal protocol: Developer writes `review-rebuttal.md`, Architect arbitrates with `architect-ruling.md`, Reviewer does FINAL REVIEW. Max one cycle without rebuttal — no infinite review loops.

## File bus — `.claude-team/`

```
.claude-team/
├── memory/                  # Persistent across sessions — commit to repo
│   ├── project.md           # Stack, conventions, structure
│   ├── decisions.md         # Why-we-did-it-this-way log
│   ├── patterns.md          # Idioms specific to this codebase
│   ├── gotchas.md           # Bugs that bit us, traps to avoid
│   ├── session-log.md       # Compact session summaries
│   └── index.md             # Map of the memory dir
└── current/                 # Transient per-task state — gitignored
    ├── task.md              # Classification + status (orchestrator)
    ├── analyst.md
    ├── architecture.md      # The plan (architect)
    ├── debug-report.md
    ├── dev-changes.md       # Implementation report (developer*/devops/git)
    ├── qa-report.md
    ├── review-feedback.md   # Reviewer's verdict
    ├── review-rebuttal.md   # Developer's pushback (optional)
    └── architect-ruling.md  # Arbiter's resolution (optional)
```

Each agent has a write-allow-list. Writes outside it are denied at hook level — see `hooks/validators/validate-file-ownership.sh` for the authoritative table. The `init-claude-team.sh` script creates this layout automatically on first session start and is idempotent.

## Enforcement hooks

Seven hooks across four event types make the workflow self-enforcing:

| Event | What it does |
|---|---|
| `SessionStart` | Auto-init `.claude-team/`, inject operating manual into context |
| `SubagentStart` matcher=`developer\|developer-opus\|developer-parallel` | Block Developer if `architecture.md` not ready |
| `SubagentStart` matcher=`*` | Record active agent (for ownership), check token budget |
| `PreToolUse` Bash `git commit*` | Block commit unless `review-feedback.md` shows `**APPROVED**` (handles rebuttal/ruling flow) |
| `PreToolUse` Write/Edit/MultiEdit on `.claude-team/**` | Block writes that violate the active agent's ownership |
| `PostToolUse` async | Append token-usage log for budget tracking |

Hooks run via a polyglot `run-hook.cmd` wrapper so the same scripts work on Windows (Git Bash) and Unix.

## Skills

15 skills total:

- **1 bootstrap:** `using-dev-team-agents` — the operating manual, injected into main-thread context on every SessionStart
- **14 methodology:** preloaded into the relevant agent's frontmatter (TDD workflow, failing-test-first, root-cause tracing, debugging-by-bisection, code review checklist, brainstorming, asking clarifying questions, writing plans, refactoring without breaking, condition-based waiting, and more)

Agents only carry the skills they actually need — no global skill soup.

## Bundled MCP servers

The plugin ships `.mcp.json` with four MCP servers ready for agents:

| Server | Purpose |
|---|---|
| **context7** | Up-to-date library documentation lookup |
| **sequential-thinking** | Structured multi-step reasoning |
| **playwright** | Browser automation for QA/web testing |
| **figma** | Design system / mockup access (HTTP, `https://mcp.figma.com/mcp`) |

You can disable any of these per-session via `/mcp` or by editing `.mcp.json`.

## Requirements

- **Claude Code** with plugin support (any recent version)
- **Main session model:** Opus recommended. Sonnet works but Opus-tier agents (Architect, Reviewer, Debugger, developer-opus) get capped; Haiku is not supported as the main model.
- **Bash 4+** — Git Bash on Windows, native on macOS/Linux. `run-hook.cmd` auto-detects.
- **CLI tools** used by some agents at runtime: `git`, `gh` (GitHub CLI), `rg` (ripgrep), `jq`. DevOps checks availability.

## Token budget

Per-task suggested caps (full / fast mode): trivial 50k / 50k, feature 300k / 100k, bug 200k / 80k, refactor 500k, setup 100k, research 80k. Per-session default cap is 1M, configurable via `${CLAUDE_PLUGIN_DATA}/preferences.json`:

```json
{ "max_session_tokens": 2000000 }
```

At 80% a soft warning is logged; at 100% new subagent dispatch is denied. The cap is a circuit breaker, not a typical-usage target.

## Project layout

```
dev-team-agents/
├── .claude-plugin/
│   ├── plugin.json                 # Manifest
│   └── marketplace.json            # Local-dev marketplace entry
├── .mcp.json                       # Bundled MCP servers
├── agents/                         # 13 agent definitions (.md with YAML frontmatter)
├── skills/
│   ├── using-dev-team-agents/      # Bootstrap operating manual
│   └── <14 methodology skills>/
├── hooks/
│   ├── hooks.json                  # 7 hook configurations
│   ├── run-hook.cmd                # Cross-platform polyglot wrapper
│   ├── <7 hook scripts>.sh
│   ├── utils/log_helpers.sh
│   └── validators/                 # Standalone validators (callable for testing)
├── scripts/
│   └── init-claude-team.sh         # .claude-team/ initializer
├── commands/                       # (empty in v0.9.0 — slash commands land later)
├── README.md
├── INSTALL.md                      # Detailed install + troubleshooting
├── CHANGELOG.md
└── LICENSE                         # MIT
```

## Roadmap

- [x] v0.1 — v0.5: skeleton, all 12 agents
- [x] v0.6 — v0.7: 7 enforcement hooks + file-ownership runtime tracking
- [x] v0.8: 14 methodology skills wired into agent frontmatter
- [x] v0.9: bootstrap skill, SessionStart auto-injection of operating manual, `developer-opus` tier
- [ ] **v1.0:** real-world testing on a handful of projects → fixes → production release

## Contributing

This is a personal project; PRs are welcome once v1.0 ships. For now, file issues with: Claude Code version (`claude --version`), OS/shell, reproduction steps, and contents of `.claude-team/current/*.md` at time of failure.

## License

[MIT](LICENSE) — © 2026 Roman Pluzhnikov.
