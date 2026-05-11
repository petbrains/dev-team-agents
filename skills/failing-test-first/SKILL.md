---
name: failing-test-first
description: "When fixing a bug, write a test that fails on the buggy code BEFORE writing the fix. Non-negotiable for bug pipelines — every bug fix produces a regression test. Use this whenever the task type is 'bug', regardless of project's TDD culture or how small the bug seems. For characterization tests (before refactor), see tdd-workflow's refactor section."
---

# Failing-Test-First

Every bug fix produces a regression test. The test is written *before* the fix and *fails* on the current (buggy) code. No exceptions for "small" bugs — small bugs recur, and a 5-minute test now saves a 2-hour recurrence later.

## Why this is non-negotiable

A bug fix without a test:

- Doesn't prove the fix actually works
- Doesn't prevent the same bug from coming back
- Leaves a gap in your test suite that grows with every "small" exception
- Tells future maintainers (including future you) that this code path is exempt from testing

A bug fix WITH a failing-first test:

- Proves the test catches the bug (it fails on buggy code)
- Proves the fix works (test goes green after the fix)
- Permanently guards against regression
- Documents the bug as executable specification

## When to use

- Task type is `bug` — always
- Even if the bug "obviously can't recur" — write the test
- Even if the project has no other tests — this is the seed
- Even if the fix is one character — write the test

When NOT applicable:

- Task type is `feature` — use `tdd-workflow` instead
- Task type is `refactor` — use characterization tests (see `tdd-workflow` refactor section)

## The process

### Step 1: Read the bug description

From `debug-report.md` (if Debugger ran) or `task.md`:

- What does the user observe?
- What should happen instead?
- What are the inputs that trigger it?

### Step 2: Find or create the test file

For the file containing the bug, find or create a corresponding test file. Use project conventions:

| Language | Convention |
|----------|------------|
| JS/TS | `src/foo.ts` → `tests/foo.test.ts` or `src/foo.test.ts` |
| Python | `mymodule/foo.py` → `tests/test_foo.py` |
| Go | `foo.go` → `foo_test.go` in same dir |
| Rust | `src/foo.rs` → in-file `#[cfg(test)] mod tests` |

### Step 3: Write a test that reproduces the bug

The test should:

- Call the actual function or use the actual UI path (no mocks of the buggy code)
- Use realistic inputs from the bug report
- Assert the expected (correct) outcome
- Run in isolation (no dependencies on other tests)

```typescript
// Bug: createSession with empty projectDir silently inits git in user's home dir.
// Test reproduces it:
test('createSession rejects empty projectDir', () => {
    expect(() => createSession({ projectDir: '' })).toThrow(/projectDir/);
});
```

### Step 4: Run the test, confirm it fails

This is critical. The test must fail on the current code. If it passes, one of:

- Your understanding of the bug is wrong
- The bug is already fixed
- The test doesn't actually exercise the buggy code path

Investigate before proceeding. Don't write a fix for a bug whose test passes.

### Step 5: Implement the fix

Now write the fix. Run the test again — it should pass. If it doesn't, the fix is incomplete (or wrong); iterate.

### Step 6: Run the whole test suite

Confirm no other tests broke. The fix should resolve the bug without regressing other behavior.

### Step 7: Commit

The commit message should make the regression-test nature explicit:

```
fix(session): reject empty projectDir in createSession

Empty projectDir silently triggered git init in the user's home directory.
Now validates and throws. Adds regression test for empty/null/whitespace inputs.
```

## Writing a good regression test

A regression test:

- **Has a name that describes the bug.** Not "test creation" — "createSession rejects empty projectDir".
- **Tests behavior, not implementation.** Don't assert `validateProjectDir was called` — assert the function throws.
- **Uses realistic inputs.** Use the inputs the bug report mentions, not a stylized minimal case.
- **Stays close to the bug surface.** A bug in `parseInput` should have a unit test on `parseInput`, not an integration test through three layers.
- **Lives next to similar tests** in the project's test layout.

## When the bug isn't easily testable

Some bugs are hard to test cleanly:

- **Environment-specific** (works on Mac, fails on Linux): document the environment, write a test that asserts the cross-platform behavior, mark as conditional if needed
- **Timing / race conditions**: use deterministic seams (injectable clock, controlled scheduler) — and if there are none, that's a refactor task to add them
- **External services**: use a recorded interaction (VCR pattern) or a deterministic mock — but the test must fail before the fix
- **UI / visual**: snapshot test or specific DOM assertion at the regression point

If you genuinely cannot write a test that fails for the bug, that's a signal — either the bug isn't actually reproducible (revisit `debug-report.md`), or the code structure makes the bug untestable (separate refactor task, then write the test).

Do not skip the test because it's hard. Hard means "design problem"; the next maintainer needs the regression test more than ever.

## Anti-patterns

- **Write the test after the fix.** Then the test passes trivially; you've verified nothing.
- **Mock the buggy function and assert it's called correctly.** Tests the mock, not the code. The real function still has the bug.
- **Test at a level so high the bug isn't on the path.** Integration test that exercises 5 functions, where the buggy one is buried — the test may pass coincidentally.
- **Skip because "it's a one-character fix".** Tests aren't about fix size; they're about regression insurance.
- **Use the bug as the test name** (`test 'fixes issue #1234'`). Tests should describe behavior, not link to ticket systems.

## Quick reference

1. Read bug description
2. Find or create test file
3. Write test that reproduces the bug — uses real code paths, realistic inputs
4. Run it. Confirm it FAILS for the right reason
5. Write the fix
6. Run the test. Confirm it PASSES
7. Run the whole test suite. Confirm no regressions
8. Commit (mention regression test in message)
