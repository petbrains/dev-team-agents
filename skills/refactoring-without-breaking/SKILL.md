---
name: refactoring-without-breaking
description: "Restructure code without changing observable behavior. Apply when planning or executing refactor tasks. Use characterization tests as safety net BEFORE changing structure, small reversible steps, behavior-preserving check at every commit boundary. The biggest refactor failure is scope creep — make Out of Scope explicit."
---

# Refactoring Without Breaking

A refactor restructures code without changing what it does. The contract: the same inputs produce the same outputs, the same side effects, the same observable performance. The structure changes; the behavior doesn't.

## When to use

- Architect planning a refactor task (PLANNER mode for `task.type: refactor`)
- Developer executing a refactor with characterization tests in place
- Any time you're moving / renaming / restructuring without intending to change behavior

NOT when:

- Behavior IS supposed to change — that's a feature or bug fix, not a refactor
- Adding new functionality alongside existing — split into refactor commit + feature commit
- Behavior change is acceptable (rare; only with explicit user agreement and updated tests)

## The four prerequisites

Before touching production code:

1. **Characterization tests cover the behaviors you must preserve.** If they don't exist, QA writes them first (see CHARACTERIZATION mode in QA agent).
2. **The scope is explicit.** `architecture.md` `## Out of Scope` lists what's NOT touched. `## Behavior Preserved` lists what tests must keep green.
3. **The change can be done in small steps.** Big-bang rewrites are not refactors.
4. **You can revert at any commit boundary.** If a step breaks something, `git revert` returns to working state.

If any prerequisite is missing, stop and address it before refactoring.

## Characterization tests as safety net

A characterization test captures current behavior — not what the code "should" do, but what it actually does. Black-box, asserting on observable outputs:

```typescript
// Characterization: captures current behavior of legacy formatter
test('formatDate produces M/D/YYYY for 2026-05-09', () => {
    expect(formatDate('2026-05-09')).toBe('5/9/2026');
});

test('formatDate returns empty string for null input', () => {
    expect(formatDate(null)).toBe('');
    // (Quirk: someone might prefer this to throw, but that's a behavior change.
    // Refactor must preserve current behavior, including quirks.)
});
```

QA writes these against the CURRENT code, runs them, sees them PASS. Now Developer can refactor, and any test going RED signals a behavior change — which is forbidden in a refactor.

## Architect's refactor plan

In `architecture.md` for a refactor task, mandatory sections:

```markdown
## Behavior Preserved

What must NOT change:

- Public API: function `parseConfig(path: string): Config` keeps same signature, same return shape
- Error behavior: throws `ConfigError` with same `code` field on missing fields
- Performance: under 5% deviation on benchmark in `bench/parse.bench.ts`
- Side effects: logs the parsed config to `config.log` (current behavior, even though weird)

## Out of Scope

Things adjacent that are tempting but NOT in this refactor:

- Replacing `ConfigError` with a different error class (separate task)
- Removing the `config.log` logging (separate task — even though it's weird)
- Adding new config fields (feature, not refactor)
- Performance optimization beyond preservation (separate task)

## Tasks

Tasks must each end with all characterization tests green. If any task can't keep them green, the task is mis-designed.
```

## Developer's refactor execution

Each step:

1. Make ONE structural change (rename, extract function, inline, move file, etc.)
2. Run characterization tests
3. ALL pass? Commit (`refactor(scope): ...`)
4. ANY fail? Revert. The change broke a behavior. Reconsider.

Step-size discipline:

| Refactor type | Step size |
|---------------|-----------|
| Rename | One symbol at a time |
| Extract function | One extraction at a time |
| Move file | One file at a time |
| Inline | One call site at a time |
| Restructure | Smallest cleavage that keeps tests green |

Big-bang refactors (rename 50 things, restructure 10 files in one go) usually break something silently — the diff is too big for confident review. Small steps catch breakage immediately and let you revert cheaply.

## Common refactor patterns and traps

### Rename

Safe sequence:

1. Add new name as alias, keep old name (deprecation step)
2. Update callers to use new name
3. Remove old name

In small codebases or with strong rename tooling (IDE, `gofmt`-equivalent), one-step rename is OK — IF tests verify nothing broke.

**Trap:** renaming things in strings (logs, error messages, config keys) that consumers depend on. Strings often aren't refactored automatically. Search for the old name AFTER the rename to catch holdouts.

### Extract function

1. Copy code into new function
2. Replace original location with call to new function
3. Verify tests still pass
4. Generalize parameters as needed

**Trap:** the extracted function references variables from the original scope. Carefully parameterize; don't just hope closure captures right.

### Inline function

Inverse of extract — pull function body into call site.

**Trap:** if the function is called from multiple places, inlining everywhere may bloat the codebase. Inline only when there's one call site, OR when the function name was less clear than the inlined code.

### Move file / module

1. Copy to new location
2. Add re-export from old location (`export * from '../new/location'`)
3. Update direct importers
4. Remove the re-export shim

**Trap:** circular imports after moves. The new location may import what now imports it.

### Replace one library/abstraction with another

The hardest refactor. Often partial behavior changes are unavoidable (libraries have subtle semantic differences).

1. Inventory what the old library is used for (concrete API methods, behaviors)
2. Verify the new library can match each — or document where it can't
3. If gaps exist: STOP. This isn't a refactor; it's a behavior change. Refile as feature work with explicit acceptance criteria.
4. If gaps don't exist: refactor incrementally, one call site at a time.

## Concurrency in refactors

Refactor commits are easy to bisect IF they're atomic and incremental. So:

- One refactor per commit (see `writing-good-commits`)
- All tests green at each commit boundary
- Avoid "refactor + feature" in one commit (you'll never bisect cleanly)

Branch protection: never force-push, never amend. If a mistake commits, fix with a new commit (or revert and re-do).

## When tests are missing

If the area you're refactoring has no tests, you can't safely refactor. Options:

1. **Write characterization tests first** (preferred — that's what QA does in refactor pipelines)
2. **Pair with manual verification** (acceptable for very small refactors where mistakes are obvious — rename within one function)
3. **Don't refactor** (acceptable when the cost of writing tests exceeds the benefit of the refactor)

Refactoring untested code is a coin flip. Most coin flips lose.

## Anti-patterns

- **Refactor while adding a feature.** Confuses bisect, confuses review. Split into two tasks.
- **Big-bang restructure** — touch 30 files in one commit. Even if tests pass, review is impractical and revert is painful.
- **"While I'm here" cleanup** during a refactor of unrelated code. Scope creep — add to Out of Scope in plan, fix later if it matters.
- **Drop characterization tests because they "test implementation details."** They test current behavior. If you want different behavior, that's a separate task.
- **Refactor third-party code interfaces.** You don't own them; you can't enforce contracts on them. Adapt your code to their shape, don't fight it.
- **Skip the revert step when a test goes red.** "I'll fix it." Maybe — but you've now combined refactor + fix in one step. Revert, then make the refactor smaller.
- **Refactor without QA's characterization tests in place.** That's not refactoring; that's hoping.

## Quick reference

Architect (PLANNER mode for refactor):

1. List `## Behavior Preserved` — what tests must stay green
2. List `## Out of Scope` — temptations to resist
3. Tasks are small, each ends with all tests green
4. QA writes characterization tests BEFORE Developer starts

Developer (executing refactor):

1. Run characterization tests — they should all PASS on current code
2. Make ONE small structural change
3. Run tests
4. All pass? Commit (`refactor(scope): ...`). Repeat.
5. Any fail? Revert. The change broke behavior. Reconsider.
6. Stay in scope — Out of Scope items don't get fixed today.

When refactoring is impossible:

- No tests + cost of writing them is high → don't refactor
- New library has different semantics → it's a feature, not a refactor
- Step is too big to keep tests green → split, or stop
