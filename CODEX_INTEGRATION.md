# Connecting Claude Code to OpenAI Codex

This plugin can use **OpenAI Codex** as an optional second engine — a parallel
reviewer and a research second-opinion — alongside Claude's internal agents.
This document explains how the link works and how to set it up.

> **TL;DR**
> 1. Install the Codex CLI and log in.
> 2. Make sure your default model in `~/.codex/config.toml` is one your account
>    actually supports (ChatGPT-account logins need `gpt-5.5`, **not** `gpt-5`).
> 3. Verify with `hooks/codex-detect.sh` + a one-line `codex exec` smoke test.
>
> Everything is **fail-closed**: if Codex is missing or broken, the pipeline
> silently falls back to Claude's internal agents — nothing breaks.

---

## How the link works

There is **no MCP server** for Codex. The integration is a thin shell-out to the
Codex CLI's non-interactive mode:

```bash
codex exec --sandbox read-only --skip-git-repo-check --cd "${PROJECT_DIR}" - < prompt.md
```

- A filled prompt is piped in on **stdin**.
- `--sandbox read-only` — Codex may inspect the repo but never modifies it.
- Output is captured and turned into a coordination file (`.claude-team/current/*.md`).
- The model is **not** passed with `-m`; Codex uses the default from
  `~/.codex/config.toml`. (This is why the default model must be valid — see
  [Gotcha: the model](#gotcha-the-model).)

### Where it plugs in

| Surface | Agent | Output file | When |
|---|---|---|---|
| Code review | `codex-code-reviewer` | `review-feedback.md` | optional, replaces internal reviewer if available |
| Plan review | `codex-doc-reviewer` | `review-plan-feedback.md` | optional, before the code stage |
| Research second opinion | `codex-consult` | `codex-analysis.md` | research tasks **only when the user explicitly asks for Codex** |

Prompt templates live in `prompts/codex-*.md`. Detection lives in
`hooks/codex-detect.sh`.

---

## Prerequisites

1. **Codex CLI installed and on `PATH`.**
   ```bash
   npm install -g @openai/codex      # or your platform's installer
   codex --version                   # e.g. codex-cli 0.135.0
   ```
2. **Authenticated.** Either a ChatGPT account login or an OpenAI API key:
   ```bash
   codex login                       # ChatGPT account (browser flow)
   # — or —
   codex login --api-key sk-...      # OpenAI API key (separate billing)
   ```
   Auth is stored in `~/.codex/auth.json` (`auth_mode: "chatgpt"` or an API key).

---

## Gotcha: the model

The single most common failure is a **default model your account can't use**.
The plugin calls `codex exec` *without* `-m`, so it inherits the `model` in
`~/.codex/config.toml`. If that model isn't entitled for your auth mode, every
Codex call returns HTTP 400 and the plugin silently falls back to internal:

```
ERROR 400 invalid_request_error:
"The 'gpt-5' model is not supported when using Codex with a ChatGPT account."
```

**ChatGPT-account logins must use `gpt-5.5`.** Edit `~/.codex/config.toml`:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
```

(API-key logins have a different model matrix — pick any model your key can access.)

To confirm which model your interactive session uses, look at the footer of the
`codex` TUI — e.g. `gpt-5.5 high`. The non-interactive `codex exec` must be able
to use that same model.

---

## Verifying the integration locally

**1 — Detection helper** (prints `codex` or `internal`, always exits 0):

```bash
bash hooks/codex-detect.sh
# expected: codex
```

> Note: detection only checks that the **binary exists and runs** (`codex --version`).
> It does **not** verify that `codex exec` succeeds against the API. A wrong default
> model passes detection but fails at call time (and degrades to internal).

**2 — End-to-end smoke test** (exactly how the agents invoke it — no `-m`):

```bash
printf 'Reply with exactly the single word: PONG\n' \
  | codex exec --sandbox read-only --skip-git-repo-check --cd "$(pwd)" -
```

A healthy result prints `PONG`, `model: gpt-5.5` in the header, and exits `0`.
Any non-zero exit or a `400` in stderr means the integration is **not** working
even if detection said `codex`.

---

## Controlling Codex per task

Precedence: **`off` > `on` > `auto` (default).**

| Layer | How |
|---|---|
| Per-task | Line in `task.md`: `**Codex review:** on \| off \| auto` |
| Project default | `${CLAUDE_PLUGIN_DATA}/preferences.json` → `"codex_review": "on" \| "off" \| "auto"` |

- `on` — prefer Codex, but degrade to internal if the binary is missing.
- `off` — never use Codex.
- `auto` (default) — use Codex if it's available.

For the **research second opinion** there is an additional gate: it only runs
when the user explicitly names Codex ("ask Codex", "через Codex"). A plain
research question stays Analyst-only.

---

## Fail-closed guarantee

A Codex agent either writes a real verdict/analysis file **or** signals it
couldn't (writing nothing) and returns `CODEX_UNAVAILABLE` / `CODEX_ERROR`.
The Orchestrator treats a missing file as "proceed with the internal agent."
Consequences:

- Codex broken → you get Claude's internal review/analysis, no error surfaced.
- The only visible symptom of a silent failure is "Codex gave no second opinion."
  If you expected one and didn't get it, run the [smoke test](#verifying-the-integration-locally).

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `codex-detect.sh` prints `internal` | Binary not on `PATH`, or `off` override set | Install Codex / check `task.md` + `preferences.json` |
| Detection says `codex` but no second opinion appears | `codex exec` fails at runtime (usually model) | Run the smoke test; fix `model` in `config.toml` |
| `400 ... model is not supported ... ChatGPT account` | Default model not entitled | Set `model = "gpt-5.5"` |
| `401` / auth errors | Token expired or no auth | `codex login` (or `codex login --api-key ...`) |
| Empty stdout, non-zero RC | Sandbox/permission or transient API error | Re-run; check `~/.codex/log` |

---

## Notes

- `codex-consult` ships as an agent; the two reviewer agents
  (`codex-code-reviewer`, `codex-doc-reviewer`) are referenced by the prompts and
  the Orchestrator and may be generated from `codex-tasks/build-codex-reviewers.md`.
- The Codex availability cache (`.claude-team/current/.codex-availability`) is
  gitignored and re-checked every task — availability is a property of the
  environment, never committed.
