---
name: writing-good-commits
description: "Write conventional commit messages with atomic grouping. Apply when staging and committing work, especially in the Git agent's role at end of pipeline. Stage explicitly, never `git add .`. One commit per logical change. Imperative present-tense subject ≤ 72 chars, optional body when context matters."
---

# Writing Good Commits

A good commit is **atomic** (one logical change) with a **conventional message** (clear type, scope, subject). Atomicity lets reviewers and bisects work; the conventional message lets readers scan history without opening every commit.

## When to use

- Any time you're staging and committing — pipeline end, manual fixes, anywhere `git commit` is involved
- Especially in the Git agent's role at end of pipelines
- When a single task produced multiple logical changes (split them)

## Atomic commit

One commit = one logical change. The diff for a single commit should be coherent — if you described it in a sentence, you'd use no "and."

**Atomic:**

- `feat(auth): add JWT validation middleware`
- `test(auth): add JWT validation tests`
- `chore: bump TypeScript to 5.4`

**Not atomic:**

- `feat: add auth, fix login bug, and update dependencies` — three logical changes glued.

### How to group

A change is one commit when:

- **Production code + its tests** — together, unless tests are very large (>200 lines), then split
- **One feature in one module** — one commit
- **Bug fix + regression test** — together (the test demonstrates the fix)
- **Refactor across multiple files for one rename** — one commit

A change is multiple commits when:

- **Feature A + feature B** in same task — separate
- **Refactor preparing for feature + feature itself** — refactor first, feature second
- **Chore (dependency, config) + feature** — chore first, then feature (or vice versa, depending on dependency)
- **Bug discovered during feature work** — fix first (separate), then continue feature

When in doubt: would `git revert` make sense for this single commit? If reverting it leaves a useful smaller commit, yes — atomic. If reverting requires understanding multiple unrelated things, no — split.

## Conventional commit format

```
<type>(<scope>): <subject>

<body — optional, only if needed for clarity>
```

### Types

| Type | When |
|------|------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Restructuring without behavior change |
| `docs` | Documentation only |
| `test` | Adding or updating tests only |
| `chore` | Tooling, config, dependencies, CI |
| `style` | Formatting, whitespace (rare — usually with another type) |
| `perf` | Performance improvement |

### Scope

The module or area touched, kebab-case. Examples:

- `auth`, `api/users`, `cli`, `db`, `notifications`

Skip if change is genuinely repo-wide:

- `chore: update node version` (no scope — affects everything)

Don't fake-scope:

- `chore(misc): cleanup` — "misc" tells us nothing. Either find the real scope or omit.

### Subject

- Imperative present tense ("add" not "added")
- Lowercase first letter after `: `
- No trailing period
- ≤ 72 characters total in the first line

**Good subjects:**

- `add JWT validation middleware`
- `handle null email in profile endpoint`
- `rename validateUser to assertUser`
- `bump TypeScript to 5.4`

**Bad subjects:**

- `Added the new JWT thing` — past tense, vague ("thing")
- `Fix bug.` — past tense, period, no specifics
- `Updated some files` — useless, vague
- `feat: lots of stuff` — no scope, no specifics

## When to add a body

Add a body when:

- The "why" is not obvious from "what"
- A trade-off was made that future readers should understand
- A reference to an issue or design doc helps context
- The change is subtle (e.g., a one-line fix where the consequences ripple)

```
fix(auth): reject empty projectDir in createSession

Empty projectDir silently triggered git init in the user's home directory,
producing a corrupt session state that was hard to diagnose. Now validates
at the boundary and throws clearly. Regression test added for empty / null /
whitespace inputs.

Fixes #1234
```

Skip the body when "what" is sufficient:

```
test(auth): add tests for refresh token expiration
```

No body needed — the subject is self-explanatory.

## Staging discipline

**Never `git add .`** — bundles unrelated changes.

Stage explicitly:

```bash
# By file
git add src/auth/middleware.ts tests/auth/middleware.test.ts

# By hunk (when one file has changes for two commits)
git add -p path/to/file.ts
```

Verify staging before commit:

```bash
git diff --cached --stat        # quick summary
git diff --cached               # full review
```

If staging is wrong, `git reset HEAD <file>` and re-stage.

## What NOT to commit

- Secrets — even in `.env.example` (use placeholder values, never real)
- Generated files (build output, compiled assets) — `.gitignore` them
- Editor/IDE files unless tooling lockfiles
- Personal scratch files

Pre-commit hooks should catch most of these. If they fire, fix — don't `--no-verify` bypass.

## Forbidden git operations

In automated pipelines:

- `git push` — never (the user controls when to share)
- `git commit --amend` — never (rewriting history is the user's call)
- `git rebase` — never (destructive on shared branches)
- `git reset --hard` — never
- `git checkout -B` — never (overwrites branches)
- `--force` / `--force-with-lease` — never

If a commit's wrong, make a new commit fixing it. Don't rewrite.

## Example: a well-staged task

Task: "Add rate limiting to /api/users endpoint."

Diff shows changes in:

- `src/middleware/rateLimit.ts` (new file)
- `src/middleware/rateLimit.test.ts` (new file)
- `src/api/users.ts` (registers middleware)
- `package.json` (added `express-rate-limit` dependency)

Atomic commits:

1. `chore: add express-rate-limit dependency`
   - Files: `package.json`, `package-lock.json` (or yarn.lock)

2. `feat(api/users): add rate limiting to POST /users`
   - Files: `src/middleware/rateLimit.ts`, `src/middleware/rateLimit.test.ts`, `src/api/users.ts`

Body for the feat commit (optional):

```
feat(api/users): add rate limiting to POST /users

Limits to 10 requests per IP per minute via express-rate-limit. Tests
cover under-limit pass, at-limit pass, over-limit 429 with Retry-After.
```

## Anti-patterns

- **`git add .`** — bundles unrelated changes. Always stage explicitly.
- **`git push`** — pipeline never pushes; user controls.
- **`git commit --amend`** — rewrites history. Don't.
- **Past-tense subjects** — "Added X" instead of "add X".
- **Narrative messages** — "Fixed the thing we discussed earlier" — not searchable, not parseable.
- **One huge "fix everything" commit** — even if diff is small, split by logical unit.
- **Vague scope** — `chore(misc)`, `fix(stuff)`. Find the real scope or omit.
- **Subject + body that say the same thing** — body should add context not present in subject.
- **Skip body when context matters** — for tricky fixes or refactors, body explaining why is high-value.
- **Commit broken state** — if tests/lint fail, fix before commit. Don't `--no-verify`.

## Quick reference

Before commit:

1. `git status` — what's modified?
2. `git diff` — what specifically changed?
3. Group into atomic units (one logical change each)
4. For each unit:
   - Stage explicitly: `git add <files>` or `git add -p`
   - Verify: `git diff --cached`
   - Compose conventional message: `type(scope): imperative subject`
   - Add body if context matters
   - `git commit -m "..."` (or with `-F` for multi-line)
5. `git status` — clean? Done.
6. NEVER push, NEVER amend, NEVER rebase
