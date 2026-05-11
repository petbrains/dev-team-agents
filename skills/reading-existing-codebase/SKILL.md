---
name: reading-existing-codebase
description: "Orient efficiently in unfamiliar code: read memory files first, then use Glob/Grep to narrow before Read. Time-box codebase reading to 5-15 minutes typical. Apply when starting work in a live project, especially Analyst's first read or Architect's pattern-finding step. Skip when fully greenfield (nothing to read)."
---

# Reading Existing Codebase

A codebase has thousands of files. You have limited context. Reading efficiently is the difference between landing in 10 minutes and getting lost for an hour.

## When to use

- Analyst in LIVE FEATURE mode — orient before clarifying with the user
- Architect in PLANNER mode — find similar features, understand patterns before planning
- Developer when assigned a task in unfamiliar area — read what's nearby before writing
- Debugger investigating a bug — trace through the call chain

NOT when:

- Greenfield project (nothing to read)
- You're already familiar with the relevant area (don't re-read)
- Task is trivial (typo fix doesn't need a tour)

## The principle: narrow before opening

A `Read` on a 1000-line file uses context expensively. A `Glob` + `Grep` pair often gets you to the right 30 lines in seconds — and tells you whether the area is worth deep reading.

Default order:

1. **Memory files** — fastest signal-to-context
2. **Glob** — what files exist
3. **Grep** — what files contain the term I care about
4. **Read** — only files you've established are relevant, with `view_range` for big files

## Step 1: Memory files first

Read these in order, only as much as is relevant:

| File | What you learn |
|------|----------------|
| `.claude-team/memory/project.md` | Stack, versions, conventions, dev commands — most useful upfront |
| `.claude-team/memory/patterns.md` | How specific things are done in this codebase |
| `.claude-team/memory/decisions.md` | Why architectural choices were made — useful for "why is this weird?" |
| `.claude-team/memory/gotchas.md` | Known traps — read before changing nearby code |
| `.claude-team/memory/session-log.md` | What was recently worked on — useful for context after time away |
| `CLAUDE.md` (project root) | Platform-level overview |

5 minutes here saves 30 minutes wandering. If memory files are empty (first task in project), you have less context — adjust by reading more code, asking the user more clarifying questions.

## Step 2: Glob to map territory

Before reading anything, know the shape of the codebase:

```bash
# Top-level directory layout (one Glob)
**/*.{ts,tsx,js,py,go,rs} | head -50

# Test layout
**/tests/**/*.{ts,py,go} | head -20
**/__tests__/**/* | head -20
**/*test*.{ts,py,go} | head -20

# Config / build artifacts
**/package.json **/tsconfig.json **/go.mod **/pyproject.toml **/Cargo.toml
```

Now you have a mental map: where source lives, where tests live, what build tooling exists.

## Step 3: Grep for the area you care about

For your task, identify keywords. Examples:

- Implementing a "rate limit" feature → grep for `rateLimit`, `rate_limit`, `RateLimit`, `throttle`
- Bug in user authentication → grep for `auth`, `login`, `session`, `validateUser`
- Adding email sending → grep for `email`, `smtp`, `Mailer`, `sendmail`

Grep tells you:

- Whether the concept exists already (don't reinvent)
- Where it lives (which directories)
- How widely it's used (one file vs many)

```bash
# Examples
grep -r "validateUser" --include="*.ts" -l    # files containing the function
grep -rn "rateLimit" --include="*.ts"          # with line numbers
```

If grep returns nothing — the concept doesn't exist; you're adding it from scratch.

If grep returns 50 files — you have a widely-used concept; sample 2-3 representative files rather than reading all.

## Step 4: Read strategically

For each file you decide to read:

- **Read in chunks** — 50-100 lines around the area you care about, not the whole file
- **Use `view_range`** for big files
- **Follow imports** when tracing through behavior — the next file is in the `import` statements
- **`git blame` and `git log`** when you need to understand WHY (commit messages often beat code comments)

```bash
git blame path/to/file.ts | head -20         # who/when each line
git log -p path/to/file.ts | head -50        # recent evolution
git log --oneline path/to/file.ts            # commit summaries
```

When tracing a function call:

```
1. Read function definition (where defined)
2. Grep for callers ('callerOfThis(' )
3. Read 2-3 representative callers
4. Stop — don't read all callers, you'll lose focus
```

## Time-boxing

| Scope | Time budget |
|-------|-------------|
| Trivial / small bug fix area | 5 min |
| Typical feature area | 10-15 min |
| Complex refactor area | 20-30 min (still capped) |
| "I'm lost" | STOP — escalate or simplify scope |

If you've spent your budget and don't yet know what you need: that's information. Either the task is bigger than thought, or the codebase is genuinely opaque (gotcha for memory). Don't keep grinding — report what you have, narrow scope.

## Finding "similar features" pattern

A common task: "I'm adding a new API endpoint; what do existing endpoints look like?"

Workflow:

1. Glob for endpoint definitions: `**/*router*`, `**/*controller*`, `**/*api*`
2. Grep for routing decorators: `@Route`, `app.get`, `app.post`, `router.get`
3. Read 2-3 representative endpoints (not all)
4. Note patterns: error handling, validation, auth, response shape
5. New endpoint follows the patterns

You're not memorizing the codebase; you're finding the local convention so your work fits.

## Anti-patterns

- **Open random files** to "get familiar." Doesn't work; you'll forget. Read with intent.
- **Read whole large files.** Use `view_range`. 1000-line file does not need to be opened in full.
- **Skip the memory files.** They're the cheapest context per token. Always start there.
- **Read source before grepping** — you'll waste reads on irrelevant files. Grep narrows.
- **Endless cross-reference chasing.** When you start reading 5 files just to understand function X, stop and ask: "what do I actually need to know about X for my task?"
- **Re-read what you already read** earlier in the session. Trust your notes (TodoWrite, scratchpad).
- **Stop at the first match.** When grep returns 5 files, sometimes the most representative isn't the first. Skim a couple.
- **Skip `git blame` / `git log`** for code that looks weird. Often the commit message tells you exactly why it's like that.

## Quick reference

For unfamiliar territory:

1. Memory files (`project.md`, `patterns.md`, `gotchas.md` first)
2. Glob to map the territory (file layout, test location, configs)
3. Grep for your domain's keywords — narrow which files matter
4. Read 2-5 files with line ranges, not whole files
5. Use `git blame` / `git log` for "why is this like this"
6. Time-box: 5 min trivial / 10-15 typical / 20-30 complex / STOP if "lost"
