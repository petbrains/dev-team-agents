---
name: verification-before-completion
description: "Before reporting work as DONE, verify it actually works — run the tests, check the files exist, confirm the behavior. Apply at the end of every implementation or test-writing task, before writing the final dev-changes.md or qa-report.md. Don't trust 'looks correct' — run the checks."
---

# Verification Before Completion

The word DONE is a contract. "DONE" without verification is a lie that costs everyone time downstream — Reviewer chases a phantom approval, Git commits broken code, the next session inherits a broken state. Cheap to verify now; expensive to discover later.

## When to use

- End of any task before writing your final report (dev-changes.md, qa-report.md, etc.)
- Before reporting status: DONE
- After any non-trivial change to a file
- After running migrations or schema changes
- After installing dependencies
- Before saying anything is "ready"

## The principle

Don't trust:

- "Looks correct in the editor"
- "I read the code and it should work"
- "The diff is small, it must be fine"
- Your own intuition about whether the change is harmless

Do trust:

- The output of running the actual code
- The output of running the actual tests
- The output of the linter / type checker
- File contents read back from disk (vs what you intended to write)

## The verification checklist

Before reporting DONE, run through this list. Skip a step only if it doesn't apply (e.g., no tests in project → "Run tests" is N/A).

### 1. Tests pass

Run the project's actual test command. Look at the output. Are all tests passing?

```bash
npm test                # or pytest, go test, cargo test, etc.
```

If even one test fails — investigate. If the failure is unrelated to your change, document it (it was already failing, you didn't cause it). If it IS related to your change, you're not done; status is BLOCKED or DONE_WITH_CONCERNS, not DONE.

### 2. Lint and type checks pass

If the project has linting or static type checking, run them.

```bash
npm run lint
npm run typecheck
```

New errors in these tools = work not finished. Pre-existing errors are a separate matter (note in your report, don't fix unless plan calls for it).

### 3. The file actually contains what you intended

Especially after Edit / MultiEdit operations on multi-line content, READ THE FILE BACK. Edit tools sometimes produce unexpected results — content split across the wrong lines, whitespace anomalies, partial replacements.

```bash
cat path/to/changed/file.ts
# or use Read tool
```

Skim it. Does it look like what you meant to write?

### 4. The build succeeds (if applicable)

If the project has a build step (TypeScript compilation, bundler, native compiler), build:

```bash
npm run build
go build ./...
cargo build
```

Code that doesn't compile is not done.

### 5. Imports / dependencies are correct

After changes that involve new functions or moved code, verify:

- New imports actually point to existing exports
- Removed imports aren't still referenced somewhere
- Dependencies you added are in the lockfile

A `tsc` or `mypy` or equivalent catches most of this — but glance through your diff for `import` lines that look off.

### 6. The thing you set out to do actually happens

This is the highest-level check. The plan said "feature X works such that Y happens when Z." Did you verify Y happens when you do Z?

Manual verification when possible:

- Run the CLI command you added
- Hit the API endpoint
- Open the UI page
- For library code: run the example from the plan / docs

If you can't manually verify (no UI, complex setup), at minimum: the test that asserts the behavior must exist and pass.

### 7. Files you said you'd touch are touched, files you didn't say are untouched

Compare your `Files modified` list in `dev-changes.md` against `git status` or `git diff --name-only`. They should match.

If `git status` shows extra files: investigate. Maybe a stale edit; maybe a side effect; flag in your report.

If `git status` shows fewer files than you listed: investigate. Maybe you forgot to save; maybe an Edit failed silently.

## What to do when verification fails

**Test fails for reasons related to your change:**

- Don't claim DONE
- Fix it (if you know how) and re-verify
- If you can't fix: report DONE_WITH_CONCERNS or BLOCKED with specifics

**Test fails for reasons unrelated to your change:**

- Note in your report: "Pre-existing failure in `tests/foo.test.ts:42`, unrelated to this work"
- Continue — DONE is acceptable, but the unrelated failure should be visible

**Lint fails on your code:**

- Fix it. Linters are part of "passes checks."

**Lint fails on code you didn't touch:**

- Don't fix. Document in your report.

**Build fails:**

- Always investigate. Build failures are usually structural and your change.
- If absolutely unrelated (e.g., a coworker's broken commit), document and flag for Orchestrator to escalate.

**File content surprised you:**

- Re-read more carefully
- If genuinely wrong: Edit again, then re-verify
- Don't assume "it'll sort itself out"

## Anti-patterns

- **Reporting DONE based on diff inspection alone.** "The diff looks right" is not verification. Run the code.
- **Running tests in your head.** "I think this test would pass." Run it.
- **Skipping the test run because tests are slow.** A 30-second test run beats a failed code review.
- **Claiming success and adding "should work" or "I believe."** If you're not sure, you're not done.
- **Verifying only the happy path.** If your test only covers the success case but the plan called for error handling too, verification is incomplete.
- **Self-deception: "the test that fails was probably flaky."** Maybe. Run it again. If consistently fails, it's not flaky.

## Quick reference

Before writing "Status: DONE":

- [ ] Tests pass (run `npm test` or equivalent)
- [ ] Lint passes (if project has linting)
- [ ] Type check passes (if project has types)
- [ ] Build succeeds (if project has a build step)
- [ ] Files I changed contain what I intended (re-read after edits)
- [ ] Files in my report match files in `git status`
- [ ] The actual behavior the plan called for: I verified it (manual run, or via a test that asserts it)

Anything failing → DONE_WITH_CONCERNS or BLOCKED, never silent DONE.
