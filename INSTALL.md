# Installation Guide

This document covers installing the `dev-team-agents` plugin into Claude Code, both for local development and (eventually) from a published marketplace.

## Prerequisites

```bash
claude --version           # Recent Claude Code with plugin support
bash --version             # Recent bash (Git Bash on Windows is fine)
```

Recommended for a richer experience (not required):

- `git` — used by the Git agent for commits, by Doc-keeper for history queries
- `ripgrep` (`rg`) — faster searches across large codebases
- `gh` (GitHub CLI) — if you want issue/PR integration in workflows
- `jq` — useful for inspecting `.claude-team/` JSON state files

## Method 1: Local development (recommended for pre-1.0)

The simplest way to try the plugin:

```bash
# 1. Clone or copy the plugin somewhere
git clone <repo-url> ~/code/dev-team-agents
cd ~/code/dev-team-agents

# 2. Start Claude Code with the plugin loaded
claude --plugin-dir .
```

When the session starts, the SessionStart hook fires and injects the operating manual (`using-dev-team-agents` skill) plus a status footer:

```
# Using dev-team-agents

This is your operating manual. Read it once at the start of every session...

[full operating manual ~13K chars]

---

## Plugin status

dev-team-agents plugin v0.9.0 loaded.
.claude-team/ status: present | created
...
```

If you don't see this, see Troubleshooting below.

## Method 2: Local marketplace install

To test the marketplace install flow without publishing:

```bash
# Add the local directory as a marketplace
/plugin marketplace add /path/to/dev-team-agents

# Install from it
/plugin install dev-team-agents
```

The included `.claude-plugin/marketplace.json` defines a single-entry marketplace pointing at the local directory.

## Method 3: Public marketplace install (post-1.0)

Once a public marketplace exists:

```
/plugin marketplace add <marketplace-url-or-git-repo>
/plugin install dev-team-agents
```

This is the intended standard install method once v1.0.0 ships.

## Configuring main-session model

The plugin works best with the main Claude Code session running on Opus. Some agents (Orchestrator, Architect, Debugger, Reviewer, Analyst, meta-agent) need Opus-tier reasoning; the executor and trivial tiers (Developer, QA, DevOps, Git, Doc-keeper) work on Sonnet/Haiku respectively per their frontmatter and don't depend on the main session model.

**Recommended:** in your project's `.claude/settings.json`:

```json
{
  "model": "opus"
}
```

## Activating the Orchestrator

The main thread becomes the Orchestrator coordinator:

```bash
claude --agent dev-team-agents:orchestrator
```

Or put this in project settings:

```json
// .claude/settings.json
{
  "agent": "dev-team-agents:orchestrator"
}
```

Then plain `claude` will start with Orchestrator active. You can then ask the Orchestrator to do tasks ("implement feature X", "fix bug Y", "refactor Z") and it will classify, route to specialists, and coordinate the pipeline.

## `.claude-team/` initialization

The plugin uses `.claude-team/` in each project to coordinate agents:

```
.claude-team/
├── memory/           # Persistent across sessions
│   ├── project.md
│   ├── decisions.md
│   ├── patterns.md
│   ├── gotchas.md
│   ├── session-log.md
│   └── index.md
└── current/          # Transient per-task state
    └── (files written by agents during a task)
```

**You don't need to create this manually** — the SessionStart hook auto-initializes it via `scripts/init-claude-team.sh`. If you want to pre-create it (e.g., during project bootstrap):

```bash
bash ~/code/dev-team-agents/scripts/init-claude-team.sh /path/to/your/project
```

The init script is idempotent — safe to run multiple times.

`.claude-team/memory/` is meant to be **committed** to your repo (it accumulates team knowledge across sessions). `.claude-team/current/` should be **gitignored** (it's transient task state). The init script handles this automatically.

## Active enforcement hooks (v0.6.0+)

The plugin installs 7 enforcement hooks that automatically activate when the plugin is loaded:

| Hook | What it does |
|------|--------------|
| `SessionStart` | Auto-init `.claude-team/`, inject operating manual |
| `SubagentStart` matcher=developer\* | Block Developer if `architecture.md` not ready |
| `SubagentStart` matcher=* | Track active agent (for ownership), check token budget |
| `PreToolUse` matcher=Bash, if=git commit | Block `git commit` unless Reviewer APPROVED |
| `PreToolUse` matcher=Write\|Edit\|MultiEdit, if=.claude-team | Block writes that violate per-agent ownership |
| `PostToolUse` matcher=* (async) | Log every tool call for token tracking |

If a hook fires a deny, you'll see a message in the session explaining what was blocked and why. Hooks can be disabled per-event in Claude Code settings if needed, but the plugin's contracts assume they're active.

## Skill activation

The plugin ships 15 skills:

- 14 methodology skills wired into agent frontmatter (each agent preloads its relevant skills automatically when it runs)
- 1 bootstrap skill (`using-dev-team-agents`) injected at SessionStart into additionalContext

You don't need to invoke skills directly — they activate when the appropriate agent runs or when SessionStart fires.

## Token budget configuration

Default per-session cap: 1,000,000 tokens (approximate). To override, create `${CLAUDE_PLUGIN_DATA}/preferences.json`:

```json
{
  "max_session_tokens": 2000000
}
```

`CLAUDE_PLUGIN_DATA` defaults to `~/.claude/data/dev-team-agents/` if the platform doesn't set it explicitly.

## Uninstalling

```
/plugin uninstall dev-team-agents
```

Or, if you used `--plugin-dir`, just stop passing that flag.

The `.claude-team/` directories in your projects are **not** removed automatically — they contain your project's accumulated memory and are meant to outlive the plugin.

## Troubleshooting

### "Plugin not found"

Check that `.claude-plugin/plugin.json` exists at the root of the directory you passed to `--plugin-dir`.

### "Hook command failed" / SessionStart errors

Verify bash is available:

```bash
bash --version
```

On Windows, install [Git for Windows](https://git-scm.com/download/win) — `run-hook.cmd` looks for bash there first, then falls back to bash on PATH.

### "No operating manual at session start"

If the SessionStart hook doesn't inject the manual:

1. Check that hooks are enabled in your Claude Code settings
2. Verify `skills/using-dev-team-agents/SKILL.md` exists in your plugin directory
3. Run `bash /path/to/plugin/hooks/session-start.sh < /dev/null` manually — if it errors, the issue is in the script; if it produces valid JSON, the issue is in Claude Code's hook handling

### "File write blocked unexpectedly"

The file-ownership hook may be denying a write that should be allowed. Check the deny reason message — it names the agent and the file. If the agent really should be able to write that file, the ownership table in `hooks/validators/validate-file-ownership.sh` needs adjustment. File an issue with the case.

### "Token budget exhausted prematurely"

The default 1M cap is conservative. If you're hitting it often, increase via `preferences.json`. The cap exists primarily as a circuit breaker against runaway loops, not as a typical-usage limit.

### Architect skipped or pipelines hang

If a pipeline appears stuck, check `.claude-team/current/*.md` files — they show exactly which agent produced what. The Orchestrator should be reading these and dispatching next steps; if it's not, look for status mismatches (e.g., last agent reported BLOCKED but flow didn't escalate).

### Other issues

Open an issue at the repository (URL TBD) with:

- Claude Code version (`claude --version`)
- OS / shell
- Output from `claude --plugin-dir . --debug` if available
- Contents of `.claude-team/current/*.md` at time of failure
- Steps to reproduce

## Development tips

- After editing any plugin file, run `/reload-plugins` in your Claude Code session
- For hooks specifically, you may need to restart the session entirely
- Use `--plugin-dir .` during development — edits take effect without copying files around
- Watch `${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/tool-calls.log` and `active-agent.txt` to debug ownership / token issues
- Run the validators directly to test ownership rules:
  ```bash
  bash hooks/validators/validate-file-ownership.sh developer .claude-team/current/architecture.md
  # exit 1 → denied; exit 0 → allowed
  ```
