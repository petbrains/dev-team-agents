---
name: tdd-workflow
description: "Test-Driven Development workflow: write failing test → make it pass with minimal code → refactor while keeping green. Apply when implementing new code in a greenfield project, adding a new module to a project that has tests, or when the plan explicitly calls for TDD. Use bite-sized steps (one assertion at a time) and run tests after every change."
---

# TDD Workflow

Red → Green → Refactor. One small step at a time. Always test before writing code; never write more code than needed to pass the current test.

## When to use this skill

- Greenfield project — TDD is honest mode from day one
- Existing project that has tests — match the style, use TDD for new modules
- The architecture plan's "Definition of Done" calls for tests
- You're writing a non-trivial pure function (logic-heavy, lots of edge cases)

When NOT to use TDD (or relax it):

- Trivial changes (renames, typos, constants)
- Existing project without tests — don't impose; but use `failing-test-first` for bugs
- UI / glue code where tests give little signal compared to manual checking
- Spike / exploration — write throwaway code first, then test the keep-able parts

## The cycle

### Red: write a failing test

Write a single test that fails for the right reason — the behavior you're about to implement isn't there yet.

```typescript
// Bad: tests too much at once
test('user authentication works', () => {
    expect(authenticate('user@example.com', 'password')).toEqual({
        success: true,
        token: expect.any(String),
        expiresAt: expect.any(Date)
    });
});

// Good: one behavior at a time
test('authenticate returns success: true for valid credentials', () => {
    const result = authenticate('user@example.com', 'correct-password');
    expect(result.success).toBe(true);
});
```

Run the test. Confirm it fails. Confirm the failure message is what you expect — if it fails for the wrong reason (compile error, missing import), fix that before proceeding.

### Green: minimal code to pass

Write the smallest amount of code that makes the test pass. Resist the urge to "while I'm here" — extra code without a test means extra untested code.

```typescript
// First passing implementation — minimal, ugly is OK
function authenticate(email: string, password: string): { success: boolean } {
    if (email === 'user@example.com' && password === 'correct-password') {
        return { success: true };
    }
    return { success: false };
}
```

That's hardcoded. That's fine for now. Next test will force the generalization.

### Refactor: improve without changing behavior

Once green, clean up. Extract functions. Rename variables. Remove duplication. Each refactor step keeps the test green.

If you can't refactor without breaking, that's information — your test isn't pinning down behavior tightly enough, or the design is wrong. Stop, think, write another test.

### Repeat

Next test forces the next piece of behavior. Each test/code pair should be a few minutes of work.

## Bite-sized steps

A "step" in TDD is small:

- Write one test (1–3 lines)
- Watch it fail (5 seconds)
- Write code to pass (a few lines, maybe a function)
- Watch it pass
- Maybe refactor (one extraction, one rename — small)
- Commit

**Time per cycle: 2–5 minutes.** If you're going 10+ minutes between green runs, your test is too big or you're over-implementing.

## Don't peek ahead

Don't write a test for behavior you'll need "later" — you'll forget context, the test will fail for ambiguous reasons, and you'll be tempted to write more code than needed.

One test, one passing implementation, then next.

## Test what behavior, not what code

Tests should verify outcomes:

- Return value
- Side effect (file written, db updated)
- State change observable through public API

NOT how the code achieves them:

- Which private function was called
- How many times a helper was invoked
- Internal data structure layout

If your test breaks when you refactor internals without changing public behavior, it's testing implementation detail. Tests should survive refactors.

## When project context affects TDD

| Context | TDD approach |
|---------|--------------|
| Greenfield | Honest TDD, every module |
| Existing with comprehensive tests | Match style, TDD new modules; for changes, add test for new behavior |
| Existing with partial tests | TDD new files; for changes in untested areas, add tests for what you touch |
| Existing without tests | Don't impose TDD; instead, write characterization tests covering current behavior before refactor (see `failing-test-first` for bug fixes) |
| Refactor | Tests must already exist (characterization); TDD does not apply (no behavior change) |

## Anti-patterns

- **Writing many tests upfront, then making them all pass.** Defeats the cycle — you lose tight feedback. One test, one pass, then next.
- **Skipping the Red step.** "I know this will fail." Maybe — but you won't know it failed for the right reason. Run it.
- **Skipping Refactor.** Code keeps growing; gets ugly; eventually unmanageable. Refactor every few cycles minimum.
- **Testing implementation.** Mocks of internal helpers, assertions on call counts of private methods — these break with every refactor.
- **One huge test that "covers" a feature.** Hard to read, hard to fix when it fails. Break it into per-behavior tests.
- **Writing more code than the failing test demands.** If the test wants 1 case to pass, write the 1 case. Generalize when the next test forces it.

## Quick reference

1. Red: write smallest possible failing test, run, see it fail for the right reason
2. Green: smallest possible code change to pass, run, see green
3. Refactor: improve code (and tests, if needed) while staying green
4. Commit
5. Next cycle
