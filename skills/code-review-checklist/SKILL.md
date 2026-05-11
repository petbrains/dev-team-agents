---
name: code-review-checklist
description: "Category-by-category review framework for changesets. Apply when reviewing code in Reviewer's INITIAL or FINAL mode. Pairs with testing-anti-patterns for test-specific reviews. Focus on signal not coverage — every reported issue must be confidence ≥ 80."
---

# Code Review Checklist

You're reading a changeset, not the whole codebase. Your job: find genuine defects that warrant fixing, not catalog stylistic preferences. Pair this checklist with the confidence rubric from your system prompt — only items with confidence ≥ 80 make the report.

## The categories

Three categories. Within each, apply the rubric. Drop sub-80-confidence items silently.

### 1. Correctness — does it do what it claims?

The plan said the code should do X. Does it?

- **Behavior matches spec?** Re-read `analyst.md` Acceptance criteria; check each is implemented and (ideally) tested.
- **Edge cases handled?** Null, undefined, empty, zero, negative, very large, unicode, concurrent access.
- **Error paths exercised?** What happens when downstream call fails, network drops, file missing?
- **Return values consistent?** Same function returning `null` in one branch and `undefined` in another is bug-prone.
- **Off-by-one?** Loop bounds, slice indices, range checks.
- **Inverted conditions?** `if (!isValid)` when you meant `if (isValid)`.
- **State mutations in safe order?** If state must transition A → B → C, is there a path where it goes A → C?

### 2. Security — is it attackable?

- **Input from the outside trusted?** User input, request bodies, query params, file uploads should be validated, escaped, sized.
- **SQL/NoSQL injection?** Parametrized queries, no string concatenation of user input into queries.
- **XSS?** User input in HTML output must be escaped.
- **Auth bypass?** Endpoints that should require auth — do they check? Are roles enforced?
- **Secrets in code?** API keys, tokens, passwords in source. Even in comments, even in commit messages.
- **Logging sensitive data?** Tokens, full PII, credentials in logs.
- **Path traversal?** User input in file paths must be sanitized.
- **Resource exhaustion?** Endpoints that allocate without limit (large file uploads, unbounded loops).

### 3. Code quality — maintainability and integrity

Note: many code-quality items are below the 80-confidence bar. Apply tightly.

- **Critical missing error handling?** Uncaught promise rejection, swallowed exception in critical path (not "I would have logged it").
- **Code duplication that creates a maintenance burden?** Three identical 30-line blocks. Not "we could DRY a 3-line check."
- **Missing tests on critical paths?** A new auth flow with no test. (For non-critical paths, low confidence — drop.)
- **Resource leaks?** Files not closed, listeners not removed, connections not released.
- **Concurrency bugs?** Shared mutable state without sync; async functions called without `await`.
- **Project conventions broken?** Documented in `CLAUDE.md` or `memory/patterns.md` → likely 80+. Undocumented "I would have" → drop.
- **Type safety holes?** `as any` casts hiding real type issues; `// @ts-ignore` without justification.
- **Dead code?** Unreachable branches, unused exports. Note for cleanup, usually not blocking.

## What's NOT on this checklist

These DO NOT belong in your report (you'll be tempted; resist):

- Style preferences not in documented conventions ("I prefer arrow functions")
- "I would have done this differently" without a concrete defect
- Variable name preferences (unless egregious — `data1`, `data2`, `tmp`)
- Comment density preferences ("more comments" / "fewer comments")
- Function length preferences (unless paired with concrete maintainability issue)
- Refactoring opportunities ("we could extract this") — note in "Pre-existing concerns" at low confidence
- Test naming preferences (unless project has documented convention)

## The confidence question — apply to every potential issue

Before adding ANY item to your report:

```
"On a scale of 0-100, how confident am I that:
  - this is a real issue (not false positive)
  - it will impact something in practice (not theoretical)
  - it's properly attributed to this changeset (not pre-existing)
"
```

If your honest score is < 80, drop the item. The user reading your report cares about a small number of real issues, not a thorough cataloging.

## Reading order

1. **Plan first** (`architecture.md`) — know intent before judging implementation
2. **Implementation report** (`dev-changes.md`) — Developer's claims about what was built
3. **Actual diff** (`git diff` or specified scope) — verify claims
4. **Surrounding code** (only what's needed) — context for changed lines

Don't open the whole codebase. Don't deep-dive every file the diff touches if context isn't needed for review.

## Per-file pattern

For each changed file:

- Does this match what `architecture.md` `## File Structure` said this file should do?
- Are changes contained within scope (no drive-by changes elsewhere)?
- Are the changes plausibly minimal for the described task?
- Do they follow patterns visible in 2-3 nearby files (project conventions)?

## Critical vs Important distinction

Within your reported issues (after ≥80 filter):

- **Critical**: will affect production functionality, security, or data integrity. Examples: SQL injection, infinite loop, lost data, auth bypass, broken API contract, crash on common input.
- **Important**: matters for maintainability or correctness in less-frequent scenarios. Examples: missing error handling in non-critical path, duplication that will hurt next change, type safety hole that could mask bugs later.

**The Critical bar is HIGH.** "Function name is unclear" is NOT Critical. "POST /api/users accepts duplicate emails" IS.

If everything in your report is "Critical," recalibrate. Most diffs have 0-2 Critical items at most.

## Edge: Pre-existing issues

While reviewing, you may spot bugs that aren't this changeset's fault — they existed before. Handle:

- Note in `## Pre-existing concerns (informational)` section, NOT in Critical/Important
- Confidence threshold still ≥ 80 (don't pad informational section with low-confidence speculation either)
- Do NOT block approval over pre-existing issues
- Do NOT ask Developer to fix in this PR (that's a separate task)

## Anti-patterns

- **Pad the report.** Manufactured concerns waste time. Clean diff → APPROVED with one line is correct.
- **Lower the bar for Critical** to look thorough. Critical is reserved for genuine production-impacting issues.
- **Report stylistic preferences.** They're below the confidence bar by definition (preferences aren't real defects).
- **Confuse "I would have done this differently" with "this is wrong."** Defensible alternative ≠ defect.
- **Flag pre-existing issues as new.** Mark them clearly as pre-existing or skip.
- **Skip the rubric.** Every item gets a mental confidence score. < 80 → drop.
- **Use vague language.** "Code could be cleaner" is not feedback. "Function `parseInput` at line 45 has cyclomatic complexity 12; extract validation block (lines 50–58) into `validateInput`" is.
- **Forget to celebrate good work.** "What's good" section in your output is 2-4 specific bullets. Anchors honest review and helps Developer know what to keep doing.

## Quick reference

For each potential issue:

1. Categorize: Correctness / Security / Quality
2. Score confidence 0-100 honestly
3. < 80 → drop silently (don't even mention it)
4. ≥ 80 → categorize as Critical or Important
5. Write entry: file:line, what, why-it-matters, suggested fix
6. Re-score after writing — if it now feels < 80, drop

Output is signal, not coverage.
