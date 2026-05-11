---
name: writing-plans
description: "Write implementation plans (architecture.md) with bite-sized tasks, explicit file mapping, [independent] markers for parallelism, mandatory Out of Scope section, and concrete Definition of Done. Apply when Architect is in PLANNER mode. Single chosen approach, never multi-perspective output to user."
---

# Writing Plans

Plans are operational documents. Developer reads them, QA reads them, Reviewer compares against them. A good plan makes the work mechanical — Developer doesn't re-investigate, doesn't guess. A bad plan creates ambiguity that propagates through every downstream agent.

## When to use

- Architect in PLANNER mode — writes `.claude-team/current/architecture.md`
- Any time you write a multi-task plan for implementation

NOT when:

- Architect is in ARBITER mode (different output — `architect-ruling.md`)
- Trivial task (no plan needed; just do it)
- Research task (no implementation plan needed; produces findings, not blueprint)

## The principles

1. **Single approach, no menu.** Pick one. Defend it briefly. Move.
2. **Bite-sized tasks.** Each task: 2-5 minutes of Developer work. Each step within a task: smaller still.
3. **Explicit file mapping.** Every file touched, named, with its scope.
4. **Mandatory Out of Scope.** The biggest plan failure mode is scope creep. Prevent it explicitly.
5. **Concrete Definition of Done.** Verifiable checks, not vibes.
6. **`[independent]` markers for parallelism.** Honest about what can run concurrently.

## Anatomy of a good plan

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One concrete sentence — what success looks like]

**Architecture Decision:** [2-3 sentences — chosen approach + one-sentence why]

**Tech Stack:** [Key libraries / versions if relevant]

**Out of Scope:** [What we're NOT doing — explicit, non-empty]

---

## Patterns Found

[2-5 file:line references to existing code establishing the pattern this follows]
[Skip if greenfield]

---

## File Structure

[Every file the Developer will touch:]
- **Create:** `src/foo/bar.ts` — single sentence on its responsibility
- **Modify:** `src/server.ts:45-60` — single sentence on what changes
- **Test:** `tests/foo/bar.test.ts` — what behaviors covered

---

## Tasks

### Task 1: [Component name]

**Files:**
- Create: ...
- Test: ...

**Steps:**
- [ ] Write failing test for [specific assertion]
- [ ] Run test, verify failure with [expected error]
- [ ] Implement minimal code to pass
- [ ] Run test, verify pass
- [ ] Refactor if needed (stay green)
- [ ] Commit: `feat(scope): add X`

### [independent] Task 2: [Different component]

[Files don't overlap with Task 1; can run in parallel]

### [sequential, depends on: Task 1] Task 3: [Dependent component]

[Order matters — Task 3 needs Task 1's output]

---

## Risks & Open Questions

[Empty if none — don't fabricate]

---

## Definition of Done

- [ ] All tasks above completed
- [ ] All listed tests pass
- [ ] No new lint or type errors
- [ ] [Specific acceptance criterion from analyst.md, if any]
```

## Goal and Architecture Decision

**Goal sentence** must be concrete enough that a stranger could verify completion:

- Bad: "Improve performance"
- Good: "Reduce p95 search latency from 800ms to <200ms for queries returning <100 results"

**Architecture Decision** captures the chosen approach with brief rationale. Use 2-3 sentences max:

- Bad: "We'll do X. There are also options Y and Z but X seems good." (Multi-perspective — user doesn't need to choose.)
- Good: "We index search-relevant fields in a separate Postgres view, refreshed via trigger on writes. This trades a small write-amplification cost for sub-200ms reads, matching the access pattern (1 write per ~1000 reads)."

## Out of Scope is critical

The largest plan failure isn't a wrong design — it's **scope creep during implementation**. Developer reads the plan, sees an adjacent thing that "would be nice to fix while I'm here," does it, breaks something unrelated. Hours lost.

Out of Scope prevents this. Examples:

```markdown
**Out of Scope:**
- Caching layer (separate task next quarter; current latency is acceptable)
- Search across deleted records (current behavior preserved)
- Admin UI for search config (no UI changes in this feature)
- Migration of legacy data (covered by separate ticket #1234)
```

Be explicit. "Nothing extra" or "TBD" are not Out of Scope statements — they fail to bound the work.

Empty Out of Scope is acceptable ONLY when truly nothing adjacent could tempt the Developer. Rare.

## Bite-sized tasks

A task is 2-5 minutes of Developer work. A task containing 20 steps that each take 30 seconds = 10 minutes, fine. A task with 3 steps where each takes 15 minutes = 45 minutes, too big.

Why bite-sized? Each step is a checkpoint. Developer can commit at any step boundary. Reviewer can review at any step boundary. If something breaks, the bisection is fast.

Sub-steps within a task should be concrete:

- Bad: "Implement the validator"
- Good:
  - Write failing test for "rejects empty input"
  - Implement minimal validator
  - Write failing test for "rejects malformed email"
  - Extend validator
  - Write failing test for "accepts valid email"
  - Verify all three pass

Match TDD cycle granularity (see `tdd-workflow` skill).

## `[independent]` markers

Only mark `[independent]` when ALL of these hold:

- Task touches files NO other task touches
- Task does not depend on types/exports/schemas from another task
- Developer can implement and test it without seeing other tasks

False parallelism causes merge conflicts. False sequentialism just makes things slower. **Bias toward sequential** — the cost is asymmetric.

For genuinely parallel tasks:

```markdown
### [independent] Task 2: Email notification module
**Files:**
- Create: src/notifications/email.ts
- Test: tests/notifications/email.test.ts
```

The platform's `developer-parallel` agent with `isolation: worktree` will catch parallelism errors at the file level — but you should still annotate correctly, both for documentation and to enable orchestration.

For dependent tasks:

```markdown
### [sequential, depends on: Task 1] Task 3: Wire notifications to user signup
**Files:**
- Modify: src/auth/signup.ts — call notification module after success
```

The dependency reference (`depends on: Task 1`) tells Orchestrator the ordering.

## Definition of Done

Verifiable. Not vibes.

Bad:

```markdown
- [ ] Feature works
- [ ] Tests are comprehensive
- [ ] Code is clean
```

These can't be checked. "Works" — works how? "Comprehensive" — how do I know? "Clean" — by whose standard?

Good:

```markdown
- [ ] All tasks above completed
- [ ] `npm test` passes (all tests green)
- [ ] `npm run lint` and `npm run typecheck` pass with no new errors
- [ ] Manual: POST /api/users with valid body returns 201 and creates DB row
- [ ] Manual: POST /api/users with duplicate email returns 409
```

Each item is a check someone can perform mechanically.

## Greenfield-specific

For greenfield projects, add `## Project Structure` BEFORE `## Tasks`:

```markdown
## Project Structure

- `src/` — source code
- `src/cli.ts` — entry point
- `src/notes/` — notes module
- `tests/` — unit tests, mirror `src/` layout
- `build/` — TypeScript output (gitignored)
- Build: `npm run build`
- Test: `npm test`
- Lint: `npm run lint`
```

First task is usually `Task 1: Scaffold` — DevOps picks this up.

## Refactor-specific

For refactor tasks, `## Out of Scope` is doubly critical AND add `## Behavior Preserved`:

```markdown
## Behavior Preserved

Observable behaviors that must NOT change:

- All current API endpoints return the same shape for the same input
- Error messages stay identical (consumers may parse them)
- Performance: p99 within 5% of current
- Concurrency: same behavior under N concurrent requests
```

QA writes characterization tests against this list before Developer starts.

## Anti-patterns

- **Wall of text under each task.** Use checklist sub-steps, not paragraphs.
- **Vague tasks.** "Implement the feature" isn't a task. "Add `validateEmail` function to `src/users/validation.ts` that returns boolean for RFC5322 conformance" is.
- **No file list.** Plan must say which files exist after the task. "Wherever it makes sense" is not a plan.
- **No Out of Scope.** Even with explicit boundaries, scope creeps. Without them, it explodes.
- **Multi-perspective output.** "We could do X or Y" — user/Developer doesn't want to choose; the Architect already chose.
- **`[independent]` on weakly-independent tasks.** When in doubt, sequential.
- **Vibes-y Definition of Done.** "Feature works well" — can't check. List concrete verifiable items.
- **No risks acknowledged.** If there's a real risk (migration safety, performance unknown, dependency on external service), document it in `## Risks & Open Questions`. Hiding risk doesn't make it go away.
- **Ceremonial completion.** Tiny task with 500-line plan = busywork. Plan size matches task size.

## Quick reference

1. Goal: one verifiable sentence
2. Architecture Decision: 2-3 sentences, one approach
3. Out of Scope: explicit, non-empty
4. File Structure: every file named with its scope
5. Tasks: bite-sized, with `[independent]` / `[sequential]` markers
6. Steps within tasks: 2-5 min each, TDD-friendly
7. Risks: only real ones
8. Definition of Done: verifiable checks
