---
name: debugging-by-bisection
description: "Narrow down the source of a bug by halving the search space repeatedly. Apply when a bug is reproducible but the cause is unclear, especially for 'worked yesterday, broken today' regressions (git bisect) and for bugs in large code paths (logical bisection). Time-efficient when you have a binary signal (passing vs failing) but vague suspects."
---

# Debugging by Bisection

When you can reproduce a bug but don't know where in the code (or in time) the problem lives, bisection is the fastest narrowing tool. Each step halves the search space; log₂(N) steps locate any cause in a set of N candidates.

## When to use

- A regression: code worked, doesn't now. Use `git bisect`.
- A bug in a large code path: many functions could be at fault. Use logical bisection (comment-out half).
- Flaky test you suspect has a state dependency: bisect by skipping subsets to isolate the order-dependent test.

NOT when:

- You already know which file is at fault (just read it carefully)
- The bug isn't reproducible (bisection needs a clear signal at each step)
- It's faster to read the code (small file, narrow scope)

## git bisect — for regressions

You know:
- A "good" commit (older — bug not present)
- A "bad" commit (newer — bug present)

```bash
git bisect start
git bisect bad                    # current (HEAD) has the bug
git bisect good <known-good-sha>  # this older commit didn't

# Git checks out a midpoint commit
# Run your reproduction:
# - if bug present:
git bisect bad
# - if bug absent:
git bisect good
# Repeat until git says "first bad commit is <sha>"

# When done:
git bisect reset
```

### Pre-flight for git bisect

- **Reproduction must be deterministic.** If the bug only fires sometimes, bisect can label commits incorrectly. Stabilize the repro first.
- **Reproduction must be fast.** Each step requires running it; if repro takes 5 minutes, 10-step bisect = 50 minutes. Speed up the repro before bisecting.
- **Commits in the range must build / run.** If you find a commit that doesn't build, use `git bisect skip` (mark as unknown, git picks adjacent commit).

### Automated bisect

If your repro is scripted:

```bash
git bisect start <bad> <good>
git bisect run ./repro-script.sh    # exit 0 = good, non-zero = bad
```

Git walks the bisect automatically. Minutes vs hours of manual.

## Logical bisection — for "where in the code"

For bugs not tied to a recent change, bisect the code path itself.

### Approach 1: Comment out half

If a function or module is large and you suspect the bug is somewhere inside:

1. Comment out half the logic (e.g., the second half of the function)
2. Run the bug reproduction
3. If bug **still present** → bug is in the first half (still running). Comment out half of THAT.
4. If bug **gone** → bug is in the second half (commented out). Uncomment, comment out a different half.
5. Repeat until you've narrowed to a few lines.

Works best with deterministic side effects (DB writes, log output, return values).

### Approach 2: Bisect by feature flag

If the codebase has feature flags or conditional paths:

1. Turn off half the features
2. Repro? Still broken → bug in remaining features. Turn off half of THEM.
3. Eventually one feature isolated as the cause.

### Approach 3: Bisect by inputs

If you have a large input set (request payload, dataset, list of args) that triggers the bug:

1. Split input in half
2. Try with first half only — bug fires?
3. Try with second half only — bug fires?
4. The half that fires contains the trigger. Bisect IT.

Useful for input-data bugs, parse errors in mystery records, etc.

## Bisection on flaky tests

Test passes/fails depending on order or environment:

1. Identify the failing test
2. Run with half the test suite before it — fails?
3. If yes — the polluting test is in that half; bisect that half
4. If no — the polluting test is in the other half

`vitest run --include "<subset>"` or pytest `-k "subset"` lets you select test subsets. Bisect 30-second runs until you've isolated the offender.

## Time and step counts

With perfect halving, locating one item in N candidates takes ⌈log₂(N)⌉ steps:

| Candidates | Steps |
|------------|-------|
| 10 | 4 |
| 100 | 7 |
| 1000 | 10 |
| 10000 | 14 |

If each step is 30 seconds → 1000 candidates in 5 minutes. Manual reading of 1000 candidates: hours.

Bisection pays off when N is large and each step is cheap. For tiny N (<10) just read sequentially.

## Anti-patterns

- **Bisect without a clean repro.** Garbage in, garbage out — every step risks mislabeling.
- **Bisect when you can read.** Single file, 100 lines? Read it. Don't ceremony-engineer a bisection.
- **Skip slow steps.** "I'll trust my hunch this commit is good." That's not bisection; that's hoping. If a step is slow, speed up the repro, don't shortcut.
- **Stop at "broken half" without going deeper.** Bisect down to lines/commits, not "somewhere in this module."
- **`git bisect` on a range with broken commits.** Use `git bisect skip` when an interim commit doesn't build. Don't mark it good or bad — it's "unknown."
- **Logical bisection that breaks the function entirely.** If commenting out half breaks the function at compile-time, find a different cleavage point (e.g., return early instead of comment out).

## Quick reference

For regressions:

1. Identify known-good SHA and known-bad SHA
2. Make repro deterministic and fast
3. `git bisect start; git bisect bad; git bisect good <sha>`
4. At each step: run repro, then `git bisect good` or `git bisect bad`
5. Optionally use `git bisect run <script>` for automation
6. End with `git bisect reset`

For unknown code path:

1. Choose cleavage (function half, feature flag set, input subset)
2. Disable / comment / skip one half
3. Run repro: still fires? bug is in remaining half. Doesn't fire? bug is in disabled half.
4. Bisect that half
5. Continue until narrowed to a few lines/items
